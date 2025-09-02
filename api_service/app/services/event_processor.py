# api_service/app/services/event_processor.py

import json
from typing import Set
from datetime import datetime
from loguru import logger
from app.data.database import db_helpers
from app.services import ai_service
from app.services.websocket_manager import websocket_manager

# A simple in-memory lock to prevent race conditions
PROCESSING_EVENTS: Set[str] = set()


def _serialize_datetime_fields(data: dict) -> dict:
    """Convert datetime objects to ISO format strings for JSON serialization."""
    serialized = {}
    for key, value in data.items():
        if isinstance(value, datetime):
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    return serialized


async def _get_aggregated_pr_state(repo_id: str, pr_number: int):
    """
    Fetches the complete, aggregated state of a single PR including all related data.
    """
    try:
        # Get PR data
        pr_data = await db_helpers.select_one(
            "pull_requests",
            where={"repo_id": repo_id, "pr_number": pr_number}
        )
        
        if not pr_data:
            logger.warning(f"PR #{pr_number} not found in repository {repo_id}")
            return None
        
        # Get repository data
        repo_data = await db_helpers.select_one(
            "repositories",
            where={"id": repo_id}
        )
        
        # Get pipeline data
        pipeline_data = await db_helpers.select_one(
            "pipeline_runs",
            where={"repo_id": repo_id, "pr_number": pr_number}
        )
        
        # Get latest AI insight
        insights = await db_helpers.select(
            "insights",
            where={"repo_id": repo_id, "pr_number": pr_number},
            order_by="created_at",
            desc=True,
            limit=1
        )
        latest_insight = insights[0] if insights else None
        
        # Construct aggregated state
        aggregated_state = {
            "event_type": "pr_update",
            "repository": _serialize_datetime_fields(repo_data) if repo_data else None,
            "pull_request": _serialize_datetime_fields(pr_data),
            "pipeline": _serialize_datetime_fields(pipeline_data) if pipeline_data else None,
            "latest_insight": _serialize_datetime_fields(latest_insight) if latest_insight else None,
            "timestamp": datetime.now().isoformat()
        }
        
        return aggregated_state
        
    except Exception as e:
        logger.error(f"Failed to get aggregated PR state for PR #{pr_number} in repo {repo_id}", exception=e)
        return None


async def _generate_ai_insight_for_pr(repo_id: str, pr_number: int):
    """
    Generate AI insights for a PR if it has files_changed data.
    Returns True if insights were generated, False otherwise.
    """
    try:
        # Get PR data with files_changed
        pr_data = await db_helpers.select_one(
            "pull_requests",
            where={"repo_id": repo_id, "pr_number": pr_number}
        )
        
        if not pr_data:
            logger.warning(f"PR #{pr_number} not found for AI insight generation")
            return False
        
        # Check if we have files_changed data
        files_changed = pr_data.get('files_changed', [])
        if not files_changed:
            logger.info(f"No files_changed data for PR #{pr_number}, skipping AI insight generation")
            return False
        
        # Generate AI insights
        logger.info(f"Generating AI insights for PR #{pr_number} with {len(files_changed)} changed files")
        ai_insight_json = await ai_service.get_ai_insights(pr_data)
        
        if ai_insight_json:
            # Store the insights in the database
            insight_record = {
                "repo_id": repo_id,
                "pr_number": pr_number,
                "commit_sha": pr_data.get("commit_sha"),
                "author": pr_data.get("author"),
                "avatar_url": pr_data.get("author_avatar"),
                "risk_level": ai_insight_json.get("riskLevel", "low").lower(),
                "summary": ai_insight_json.get("summary"),
                "recommendation": ai_insight_json.get("recommendation"),
            }
            
            await db_helpers.insert("insights", insight_record)
            logger.success(f"Generated and saved AI insight for PR #{pr_number} in repository {repo_id}")
            return True
        else:
            logger.warning(f"AI insight generation failed for PR #{pr_number}")
            return False
            
    except Exception as e:
        logger.error(f"Failed to generate AI insight for PR #{pr_number} in repo {repo_id}", exception=e)
        return False


async def process_notification_by_type_and_id(event_type: str, record_id: str):
    """
    Processes database notifications from the new trigger system.
    Handles pr_event, pipeline_event, and insight_event notifications.
    """
    logger.info(f"Processing {event_type} notification for record ID: {record_id}")
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"Record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        repo_id = None
        pr_number = None
        should_generate_insights = False
        
        if event_type == "pr_event":
            # Handle pull request events
            pr_record = await db_helpers.select_one("pull_requests", where={"id": record_id})
            if pr_record:
                repo_id = pr_record['repo_id']
                pr_number = pr_record['pr_number']
                
                # Check if this is a new PR or updated with new files
                files_changed = pr_record.get('files_changed', [])
                if files_changed:
                    # Check if we already have insights for this PR
                    existing_insights = await db_helpers.select(
                        "insights",
                        where={"repo_id": repo_id, "pr_number": pr_number},
                        limit=1
                    )
                    
                    # Generate insights if none exist
                    if not existing_insights:
                        should_generate_insights = True
                        logger.info(f"New PR #{pr_number} with file changes detected, will generate AI insights")
                
        elif event_type == "pipeline_event":
            # Handle pipeline events
            pipeline_record = await db_helpers.select_one("pipeline_runs", where={"id": record_id})
            if pipeline_record:
                repo_id = pipeline_record['repo_id']
                pr_number = pipeline_record['pr_number']
                
        elif event_type == "insight_event":
            # Handle insight events
            insight_record = await db_helpers.select_one("insights", where={"id": record_id})
            if insight_record:
                repo_id = insight_record['repo_id']
                pr_number = insight_record['pr_number']
        
        # If we couldn't determine repo_id and pr_number, log and exit
        if not repo_id or not pr_number:
            logger.warning(f"Could not determine repo_id and pr_number for {event_type} record {record_id}")
            return
        
        # Generate AI insights if needed (for PR events with file changes)
        if should_generate_insights:
            insights_generated = await _generate_ai_insight_for_pr(repo_id, pr_number)
            if insights_generated:
                logger.info(f"AI insights generated for PR #{pr_number}, will broadcast updated state")
        
        # Get the complete aggregated state and broadcast to WebSocket clients
        aggregated_state = await _get_aggregated_pr_state(repo_id, pr_number)
        if aggregated_state:
            await websocket_manager.broadcast_json(aggregated_state)
            logger.success(f"Broadcasted {event_type} update for PR #{pr_number} in repository {repo_id}")
        else:
            logger.warning(f"Could not get aggregated state for PR #{pr_number} in repository {repo_id}")
            
    except Exception as e:
        logger.error(f"Critical failure during processing of {event_type} record {record_id}", exception=e)
        # Re-raise the exception so it can be handled by the caller
        raise e
    finally:
        # Always remove from processing set
        PROCESSING_EVENTS.discard(record_id)


# Legacy function for backward compatibility (if event_poller still needs it)
async def process_event_by_id(event_id: str):
    """
    Legacy function for backward compatibility.
    This should not be used with the new schema since raw_events table no longer exists.
    """
    logger.warning(f"Legacy process_event_by_id called with event_id {event_id}. This function is deprecated with the new schema.")
    # This function is now a no-op since raw_events table doesn't exist