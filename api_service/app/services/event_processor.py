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


async def process_new_pull_request(pr_record: dict):
    """
    Process a new or updated pull request.
    Generates AI insights only for new PRs with files_changed data.
    For updates (status changes, approvals, etc.), just broadcasts the updated state.
    """
    repo_id = pr_record['repo_id']
    pr_number = pr_record['pr_number']
    record_id = pr_record['id']
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"PR record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        logger.info(f"Processing PR #{pr_number} in repository {repo_id}")
        
        # Check if this is a genuinely new PR or just a status update
        files_changed = pr_record.get('files_changed', [])
        
        # Handle case where files_changed might be a JSON string
        if isinstance(files_changed, str):
            try:
                files_changed = json.loads(files_changed)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in files_changed for PR #{pr_number}")
                files_changed = []
        existing_insights = await db_helpers.select(
            "insights",
            where={"repo_id": repo_id, "pr_number": pr_number},
            limit=1
        )
        
        # Only generate insights if:
        # 1. This PR has files_changed data AND
        # 2. No insights exist yet (meaning this is a new PR, not just a status update)
        should_generate_insights = files_changed and not existing_insights
        
        if should_generate_insights:
            logger.info(f"New PR #{pr_number} detected with {len(files_changed)} changed files, generating AI analysis...")
            # Update pr_record with parsed files_changed for AI processing
            pr_record_with_parsed_files = pr_record.copy()
            pr_record_with_parsed_files['files_changed'] = files_changed
            await _generate_ai_insight_for_pr(pr_record_with_parsed_files)
            # Broadcast as new PR with insight generation
            event_state = _determine_pr_event_state(pr_record)
            await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        elif existing_insights:
            logger.info(f"PR #{pr_number} update detected (status/approval change), broadcasting updated state...")
            # Broadcast as state update only
            event_state = _determine_pr_event_state(pr_record)
            await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        else:
            logger.info(f"PR #{pr_number} has no file changes, skipping insight generation...")
            # Broadcast as basic update
            event_state = _determine_pr_event_state(pr_record)
            await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        
    except Exception as e:
        logger.error(f"Failed to process PR #{pr_number} in repo {repo_id}", exception=e)
        raise e
    finally:
        PROCESSING_EVENTS.discard(record_id)


async def process_new_pipeline(pipeline_record: dict):
    """
    Process a new or updated pipeline run.
    """
    repo_id = pipeline_record['repo_id']
    pr_number = pipeline_record['pr_number']
    record_id = pipeline_record['id']
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"Pipeline record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        logger.info(f"Processing pipeline update for PR #{pr_number} in repository {repo_id}")
        
        # Determine the actual event state from pipeline status
        event_state = _determine_pipeline_event_state(pipeline_record)
        
        # Broadcast pipeline state change with actual event state
        await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        
    except Exception as e:
        logger.error(f"Failed to process pipeline for PR #{pr_number} in repo {repo_id}", exception=e)
        raise e
    finally:
        PROCESSING_EVENTS.discard(record_id)


def _determine_pipeline_event_state(pipeline_record: dict) -> str:
    """
    Determine the actual event state from pipeline status fields.
    Returns the most recent/significant status change.
    """
    status_pr = pipeline_record.get('status_pr', 'pending')
    status_build = pipeline_record.get('status_build', 'pending')
    status_approval = pipeline_record.get('status_approval', 'pending')
    status_merge = pipeline_record.get('status_merge', 'pending')
    
    # Priority order: merged > approval > build > PR creation
    # Match the actual values stored in the database
    if status_merge == 'merged':
        return 'merged'
    elif status_merge == 'closed':
        return 'closed'
    elif status_merge == 'failed':
        return 'mergeFailed'
    elif status_approval == 'approved':
        return 'approved'
    elif status_approval == 'rejected':
        return 'rejected'
    elif status_build == 'buildPassed':
        return 'buildPassed'
    elif status_build == 'buildFailed':
        return 'buildFailed'
    elif status_build == 'building':
        return 'building'
    elif status_pr == 'opened' or status_pr == 'pending':
        return 'opened'
    else:
        return 'updated'


def _determine_pr_event_state(pr_record: dict) -> str:
    """
    Determine the actual event state from PR record fields.
    Returns the actual PR state based on fields.
    For PRs, check the most recent history entry to get the current workflow state.
    """
    state = pr_record.get('state', 'open')
    merged = pr_record.get('merged', False)
    is_draft = pr_record.get('is_draft', False)
    history = pr_record.get('history', [])
    
    # If we have history, use the most recent state
    if history and isinstance(history, list):
        latest_history = history[-1] if history else {}
        latest_state = latest_history.get('state')
        
        # Use history state if it's a workflow state
        if latest_state in ['building', 'buildPassed', 'buildFailed', 'approved', 'rejected']:
            return latest_state
    
    # Fallback to record-level state determination
    if merged:
        return 'merged'
    elif state == 'closed' and not merged:
        return 'closed'
    elif is_draft:
        return 'draft'
    elif state == 'open':
        return 'opened'
    else:
        return state


async def process_new_insight(insight_record: dict):
    """
    Process a new insight (usually generated by AI).
    Do not broadcast WebSocket events as insights are internal processing.
    """
    repo_id = insight_record['repo_id']
    pr_number = insight_record['pr_number']
    record_id = insight_record['id']
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"Insight record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        logger.info(f"Processing new insight for PR #{pr_number} in repository {repo_id}")
        
        # Insights are internal processing - no WebSocket broadcast needed
        # The initial PR or pipeline event already broadcasted the state
        
    except Exception as e:
        logger.error(f"Failed to process insight for PR #{pr_number} in repo {repo_id}", exception=e)
        raise e
    finally:
        PROCESSING_EVENTS.discard(record_id)


async def _generate_ai_insight_for_pr(pr_record: dict):
    """
    Generate AI insights for a PR using the files_changed data.
    Returns True if insights were generated, False otherwise.
    """
    try:
        repo_id = pr_record['repo_id']
        pr_number = pr_record['pr_number']
        
        # Check if we have files_changed data and parse it if it's a JSON string
        files_changed = pr_record.get('files_changed', [])
        if isinstance(files_changed, str):
            try:
                files_changed = json.loads(files_changed)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in files_changed for PR #{pr_number}")
                return False
        
        if not files_changed:
            logger.info(f"No files_changed data for PR #{pr_number}, skipping AI insight generation")
            return False
        
        # Generate AI insights using the AI service
        logger.info(f"Generating AI insights for PR #{pr_number} with {len(files_changed)} changed files")
        ai_insight_json = await ai_service.get_ai_insights(pr_record)
        
        logger.info(f"AI service returned: {ai_insight_json}")
        
        if ai_insight_json:
            # Store the insights in the database with processed=false initially
            insight_record = {
                "repo_id": repo_id,
                "pr_number": pr_number,
                "commit_sha": pr_record.get("commit_sha"),
                "author": pr_record.get("author"),
                "avatar_url": pr_record.get("author_avatar"),
                "risk_level": ai_insight_json.get("risk_level", ai_insight_json.get("riskLevel", "low")).lower(),
                "summary": ai_insight_json.get("summary"),
                "recommendation": ai_insight_json.get("recommendation"),
                "processed": False  # Will be processed by the poller
            }
            
            result = await db_helpers.insert("insights", insight_record)
            logger.success(f"Generated and saved AI insight for PR #{pr_number} in repository {repo_id}")
            return True
        else:
            logger.warning(f"AI insight generation failed for PR #{pr_number}")
            return False
            
    except Exception as e:
        logger.error(f"Failed to generate AI insight for PR #{pr_number}", exception=e)
        return False