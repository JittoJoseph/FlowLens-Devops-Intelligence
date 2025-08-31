# api_service/app/services/event_processor.py

import json # <-- **FIX 1: Import the JSON library**
from loguru import logger
from app.data.database import db_helpers
from app.services import ai_service
from app.services.websocket_manager import websocket_manager

async def _get_latest_pr_state(pr_number: int):
    """Fetches the complete, aggregated state of a single PR."""
    query = """
        SELECT
            pr.*,
            (SELECT to_json(p) FROM pipeline_runs p WHERE p.pr_number = pr.pr_number) AS pipeline_status,
            (SELECT to_json(i) FROM insights i
             WHERE i.pr_number = pr.pr_number
             ORDER BY i.created_at DESC LIMIT 1) AS ai_insight
        FROM pull_requests_view pr
        WHERE pr.pr_number = $1;
    """
    pool = await db_helpers.get_pool()
    async with pool.acquire() as connection:
        row = await connection.fetchrow(query, pr_number)
    
    if not row: return None
    
    # Ensure nested JSON is also parsed correctly before sending
    state = dict(row)
    if state.get('pipeline_status'):
        state['pipeline_status'] = json.loads(state['pipeline_status'])
    if state.get('ai_insight'):
        state['ai_insight'] = json.loads(state['ai_insight'])
    return state


async def process_event_by_id(event_id: str):
    """
    The main processor function, triggered by the poller.
    (FIXED to correctly parse the JSON payload).
    """
    logger.info(f"Processing event with ID: {event_id}")
    try:
        event = await db_helpers.select_one("raw_events", where={"id": event_id})
        if not event:
            logger.error(f"Event {event_id} not found in database.")
            return

        # --- FIX 2: Parse the payload string into a Python dictionary ---
        payload = json.loads(event.get('payload', '{}'))
        event_type = event.get('event_type')
        pr_number = None

        # --- Step 1: Identify the associated Pull Request ---
        if 'pull_request' in payload:
            pr_number = payload['pull_request'].get('number')
        elif 'workflow_run' in payload and payload['workflow_run'].get('pull_requests'):
            pr_number = payload['workflow_run']['pull_requests'][0].get('number')
        elif 'check_run' in payload and payload['check_run'].get('pull_requests'):
            pr_number = payload['check_run']['pull_requests'][0].get('number')

        if not pr_number:
            logger.warning(f"Event {event_id} (type: {event_type}) is not associated with a PR. Skipping.")
            return

        # --- Step 2: Generate AI Insight if it's a code change event ---
        if event_type == 'pull_request' and payload.get('action') in ['opened', 'reopened', 'synchronize']:
            pr_view_data = await db_helpers.select_one("pull_requests_view", where={"pr_number": pr_number})
            if pr_view_data:
                ai_insight_json = await ai_service.get_ai_insights(pr_view_data)
                if ai_insight_json:
                    insight_record = {
                        "pr_number": pr_number,
                        "commit_sha": pr_view_data.get("commit_sha"),
                        "risk_level": ai_insight_json.get("riskLevel"),
                        "summary": ai_insight_json.get("summary"),
                        "recommendation": ai_insight_json.get("recommendation"),
                    }
                    await db_helpers.insert("insights", insight_record)
                    logger.success(f"Generated and saved new AI insight for PR #{pr_number}")

        # --- Step 3: Broadcast the new, complete state of the PR to all clients ---
        latest_state = await _get_latest_pr_state(pr_number)
        if latest_state:
            await websocket_manager.broadcast_json({
                "event": "pr_update",
                "data": latest_state
            })
            logger.success(f"Broadcasted latest state for PR #{pr_number} to all clients.")

    except Exception as e:
        logger.error(f"Failed during processing of event {event_id}", exception=e)
        # We re-raise the exception so the poller knows it failed and doesn't mark it as processed.
        # This ensures the event will be retried on the next cycle.
        raise e