# api_service/app/services/event_processor.py

import json
from datetime import datetime
from loguru import logger
from app.data.database import db_helpers
from app.services import ai_service
from app.services.websocket_manager import websocket_manager

async def _get_latest_pr_state(pr_number: int):
    """Fetches the complete, aggregated state of a single PR."""
    # This query aligns with the new schema and joins the necessary data.
    query = """
        SELECT
            pr.pr_number,
            pr.title,
            pr.description,
            pr.author,
            pr.author_avatar,
            pr.commit_sha,
            pr.repository_name,
            pr.branch_name,
            pr.additions,
            pr.deletions,
            pr.is_draft,
            pr.created_at,
            pr.updated_at,
            pr.state,
            (SELECT to_json(p) FROM pipeline_runs p WHERE p.pr_number = pr.pr_number) AS pipeline_status,
            (SELECT to_json(i) FROM insights i
             WHERE i.pr_number = pr.pr_number
             ORDER BY i.created_at DESC LIMIT 1) AS ai_insight
        FROM pull_requests pr
        WHERE pr.pr_number = :pr_number;
    """
    db = db_helpers.get_db()
    row = await db.fetch_one(query, {"pr_number": pr_number})
    
    if not row: return None
    
    state = dict(row)
    # The database returns JSON as strings; parse them into dicts.
    if state.get('pipeline_status'):
        state['pipeline_status'] = json.loads(state['pipeline_status'])
    if state.get('ai_insight'):
        state['ai_insight'] = json.loads(state['ai_insight'])

    # --- FIX 1: THE CRITICAL SERIALIZATION FIX ---
    # Iterate through the entire state dictionary and convert any
    # datetime objects to JSON-serializable ISO 8601 strings.
    for key, value in state.items():
        if isinstance(value, datetime):
            state[key] = value.isoformat()

    return state


async def process_event_by_id(event_id: str):
    """
    The main processor function. It's now more robust, correctly parses payloads,
    and handles AI failures gracefully.
    """
    logger.info(f"Processing event with ID: {event_id}")
    try:
        event = await db_helpers.select_one("raw_events", where={"id": event_id})
        if not event:
            logger.error(f"Event {event_id} not found in database.")
            raise ValueError(f"Event {event_id} not found")

        # --- FIX 2: Parse the payload string into a Python dictionary ---
        payload = json.loads(event.get('payload', '{}'))
        event_type = event.get('event_type')
        pr_number = None

        # --- Step 1: Reliably identify the associated Pull Request number ---
        if 'pull_request' in payload:
            pr_number = payload['pull_request'].get('number')
        elif 'workflow_run' in payload and payload['workflow_run'].get('pull_requests'):
            pr_number = payload['workflow_run']['pull_requests'][0].get('number')
        elif 'check_run' in payload and payload['check_run'].get('pull_requests'):
            pr_number = payload['check_run']['pull_requests'][0].get('number')

        if not pr_number:
            logger.info(f"Event {event_id} (type: {event_type}) is not associated with a PR. Skipping further processing.")
            return # This is a successful outcome for non-PR events.

        # --- Step 2: Trigger AI analysis only for relevant actions ---
        if event_type == 'pull_request' and payload.get('action') in ['opened', 'reopened', 'synchronize']:
            # Fetch data from the `pull_requests` table, which was populated by the ingestion service.
            pr_data = await db_helpers.select_one("pull_requests", where={"pr_number": pr_number})
            if pr_data:
                # --- FIX 3: HANDLE POTENTIAL AI FAILURE GRACEFULLY ---
                # The AI service can now return None, and we must handle it.
                ai_insight_json = await ai_service.get_ai_insights(pr_data)
                
                if ai_insight_json:
                    # This block only runs if the AI call was successful.
                    insight_record = {
                        "pr_number": pr_number,
                        "commit_sha": pr_data.get("commit_sha"),
                        "author": pr_data.get("author"),
                        "avatar_url": pr_data.get("author_avatar"),
                        "risk_level": ai_insight_json.get("riskLevel", "low").lower(),
                        "summary": ai_insight_json.get("summary"),
                        "recommendation": ai_insight_json.get("recommendation"),
                    }
                    await db_helpers.insert("insights", insight_record)
                    logger.success(f"Generated and saved new AI insight for PR #{pr_number}")
                else:
                    logger.warning(f"AI insight generation failed for PR #{pr_number}. Proceeding without new insight.")

        # --- Step 3: Broadcast the latest state to clients ---
        # This broadcast now happens REGARDLESS of AI success, so the UI always updates on any event.
        latest_state = await _get_latest_pr_state(pr_number)
        if latest_state:
            await websocket_manager.broadcast_json({
                "event": "pr_update",
                "data": latest_state
            })
            logger.success(f"Broadcasted latest state for PR #{pr_number} to all clients.")
        else:
            logger.warning(f"Could not fetch latest state for PR #{pr_number} after processing event {event_id}.")

    except Exception as e:
        logger.error(f"CRITICAL failure during processing of event {event_id}", exception=e)
        # Re-raise the exception so the poller knows it failed and can retry the event.
        raise e