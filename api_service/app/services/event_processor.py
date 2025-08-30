# api_service/app/services/event_processor.py
from loguru import logger
from app.data.database import db_helpers
from app.services import ai_service
from app.services.websocket_manager import websocket_manager

async def _handle_pull_request_event(payload: dict):
    pr_payload = payload.get('pull_request', {})
    pr_number = pr_payload.get('number')
    action = payload.get('action')

    # --- 1. Upsert PR data for the Flutter view ---
    pr_view_data = {
        "pr_number": pr_number,
        "title": pr_payload.get('title', ''),
        "author": pr_payload.get('user', {}).get('login', 'unknown'),
        "author_avatar": pr_payload.get('user', {}).get('avatar_url', ''),
        "commit_sha": pr_payload.get('head', {}).get('sha', ''),
        "repository_name": payload.get('repository', {}).get('full_name', ''),
        "branch_name": pr_payload.get('head', {}).get('ref', ''),
        "created_at": pr_payload.get('created_at'),
        "updated_at": pr_payload.get('updated_at'),
    }
    await db_helpers.upsert("pull_requests_view", pr_view_data, conflict_keys=["pr_number"])
    
    # --- 2. Update pipeline status based on PR action ---
    status_update = {"updated_at": pr_payload.get('updated_at')}
    if action == 'opened':
        status_update['status_pr'] = 'created'
    elif action == 'closed':
        if pr_payload.get('merged'):
            status_update['status_merge'] = 'merged'
        else:
            status_update['status_merge'] = 'closed'
    
    await db_helpers.update("pipeline_runs", status_update, where={"pr_number": pr_number})

    # --- 3. Generate AI Insight if it's a code-changing event ---
    if action in ['opened', 'reopened', 'synchronize']:
        ai_insight = await ai_service.get_ai_insights(pr_view_data)
        if ai_insight:
            insight_record = {
                "pr_number": pr_number,
                "commit_sha": pr_view_data["commit_sha"],
                "risk_level": ai_insight.get("riskLevel"),
                "summary": ai_insight.get("summary"),
                "recommendation": ai_insight.get("recommendation"),
            }
            await db_helpers.insert("insights", insight_record)
            
            # --- 4. Broadcast the new insight ---
            await websocket_manager.broadcast_json({
                "event": "new_insight",
                "data": {**insight_record, "createdAt": "now"}
            })

    # Always broadcast the updated PR state
    await websocket_manager.broadcast_json({
        "event": "pr_update",
        "data": {"pr_number": pr_number, **status_update}
    })

async def _handle_workflow_run_event(payload: dict):
    workflow_run = payload.get('workflow_run', {})
    if not workflow_run.get('pull_requests'):
        logger.warning("Skipping workflow_run event not associated with a PR.")
        return

    pr_number = workflow_run['pull_requests'][0]['number']
    status = workflow_run.get('status')
    conclusion = workflow_run.get('conclusion')
    
    build_status = 'pending'
    if status == 'queued' or status == 'in_progress':
        build_status = 'building'
    elif status == 'completed':
        if conclusion == 'success':
            build_status = 'build_passed'
        else:
            build_status = 'build_failed'
    
    status_update = {"status_build": build_status, "updated_at": workflow_run.get('updated_at')}
    await db_helpers.update("pipeline_runs", status_update, where={"pr_number": pr_number})
    
    await websocket_manager.broadcast_json({
        "event": "pr_update",
        "data": {"pr_number": pr_number, **status_update}
    })

async def process_event_by_id(event_id: str):
    """Fetches a single event by its ID and processes it."""
    logger.info(f"Processing event with ID: {event_id}")
    try:
        event = await db_helpers.select_one("raw_events", where={"id": event_id})
        if not event:
            logger.error(f"Event {event_id} not found in database.")
            return

        if event['processed']:
            logger.warning(f"Event {event_id} has already been processed. Skipping.")
            return

        event_type = event.get('event_type')
        payload = event.get('payload', {})

        if event_type == "pull_request":
            await _handle_pull_request_event(payload)
        elif event_type == "workflow_run":
            await _handle_workflow_run_event(payload)
        else:
            logger.warning(f"Unhandled event type: {event_type}")

        await db_helpers.update("raw_events", data={"processed": True}, where={"id": event_id})
        logger.success(f"Successfully processed event {event_id}")

    except Exception as e:
        logger.error(f"Failed to process event {event_id}", exception=e)