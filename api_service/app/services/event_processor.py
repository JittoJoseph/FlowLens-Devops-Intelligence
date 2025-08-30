# api_service/app/services/event_processor.py

from loguru import logger
from app.data.database import db_helpers
from app.services import ai_service
from app.services.websocket_manager import websocket_manager


async def _parse_and_process_event(event: dict):
    """Parses a raw event payload and triggers all subsequent actions."""
    event_id = event['id']
    payload = event['payload']
    event_type = event['event_type']

    if event_type != "pull_request":
        logger.warning(f"Skipping event {event_id} of non-PR type: {event_type}")
        return
    
    pr_payload = payload.get('pull_request', {})
    if not pr_payload:
        logger.error(f"Event {event_id} is missing 'pull_request' data.")
        return

    pr_number = pr_payload.get('number')
    if not pr_number:
        logger.error(f"Event {event_id} is missing PR number.")
        return

    # --- 1. Extract data and populate the pull_requests_view table ---
    pr_view_data = {
        "pr_number": pr_number,
        "title": pr_payload.get('title', ''),
        "description": pr_payload.get('body', ''),
        "author": pr_payload.get('user', {}).get('login', 'unknown'),
        "author_avatar": pr_payload.get('user', {}).get('avatar_url', ''),
        "commit_sha": pr_payload.get('head', {}).get('sha', ''),
        "repository_name": payload.get('repository', {}).get('full_name', ''),
        "branch_name": pr_payload.get('head', {}).get('ref', ''),
        "additions": pr_payload.get('additions', 0),
        "deletions": pr_payload.get('deletions', 0),
        "is_draft": pr_payload.get('draft', False),
        "created_at": pr_payload.get('created_at'),
        "updated_at": pr_payload.get('updated_at'),
    }
    await db_helpers.upsert("pull_requests_view", pr_view_data, conflict_keys=["pr_number"])
    logger.info(f"Upserted PR view data for PR #{pr_number}")
    
    # --- 2. Update the pipeline status ---
    pipeline_data = {
        "pr_number": pr_number,
        "commit_sha": pr_view_data["commit_sha"],
        "author": pr_view_data["author"],
        "avatar_url": pr_view_data["author_avatar"],
        "status_pr": "created", # This event signifies PR creation
        "updated_at": pr_view_data["updated_at"]
    }
    await db_helpers.upsert("pipeline_runs", pipeline_data, conflict_keys=["pr_number"])
    logger.info(f"Upserted pipeline status for PR #{pr_number}")

    # --- 3. Get AI insights (only for 'opened' or 'reopened' actions) ---
    action = payload.get('action')
    if action in ['opened', 'reopened', 'synchronize']:
        # Note: We are using pr_view_data which is already extracted
        ai_insight_data = await ai_service.get_ai_insights(pr_view_data)
        
        if ai_insight_data:
            insight_record = {
                "pr_number": pr_number,
                "commit_sha": pr_view_data["commit_sha"],
                "author": pr_view_data["author"],
                "avatar_url": pr_view_data["author_avatar"],
                "risk_level": ai_insight_data.get("riskLevel"),
                "summary": ai_insight_data.get("summary"),
                "recommendation": ai_insight_data.get("recommendation"),
            }
            await db_helpers.insert("insights", insight_record)
            logger.success(f"Inserted AI insight for PR #{pr_number}")
            
            # --- 4. Broadcast the new insight via WebSocket ---
            await websocket_manager.broadcast_json({
                "event_type": "new_insight",
                "data": {**insight_record, "createdAt": "now"} # Frontend will parse
            })


async def process_pending_events():
    """Fetches and processes all events marked as not processed."""
    logger.debug("Polling for new events...")
    try:
        events = await db_helpers.select(
            "raw_events", 
            where={"processed": False}, 
            order_by="received_at", 
            desc=False
        )

        if not events:
            return
        
        logger.info(f"Found {len(events)} new events to process.")

        for event in events:
            try:
                await _parse_and_process_event(event)
                # Mark as processed only after successful processing
                await db_helpers.update("raw_events", data={"processed": True}, where={"id": event['id']})
                logger.success(f"Successfully processed event {event['id']}")
            except Exception as e:
                logger.error(f"Failed to process event {event['id']}. Error: {e}")
                # Optional: Mark as failed instead of leaving as unprocessed
                # await db_helpers.update("raw_events", data={"processed": True, "failed": True}, where={"id": event['id']})

    except db_helpers.DatabaseError as e:
        logger.error(f"Database error during event polling: {e}")
    except Exception as e:
        logger.critical(f"An unexpected error occurred in the event processor: {e}")