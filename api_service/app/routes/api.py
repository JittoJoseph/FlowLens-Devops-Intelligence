# api_service/app/routes/api.py

from typing import Dict, Any
from fastapi import APIRouter, HTTPException, Request, BackgroundTasks
from loguru import logger
from app.data.database import db_helpers
from app.services import event_processor

router = APIRouter(prefix="/api", tags=["Core API"])

@router.get("/dashboard")
async def get_dashboard_data():
    """Provides the initial state of all PRs for the Flutter app on load."""
    logger.info("Fetching initial dashboard data...")
    try:
        pool = await db_helpers.get_pool()
        async with pool.acquire() as connection:
            rows = await connection.fetch("""
                SELECT
                    (SELECT to_json(pr) FROM pull_requests_view pr WHERE pr.pr_number = p.pr_number) AS "pullRequest",
                    (SELECT to_json(pipe) FROM pipeline_runs pipe WHERE pipe.pr_number = p.pr_number) AS "pipelineStatus",
                    (SELECT to_json(i) FROM insights i WHERE i.pr_number = p.pr_number ORDER BY i.created_at DESC LIMIT 1) AS "aiInsight"
                FROM pull_requests_view p
                ORDER BY p.updated_at DESC;
            """)
        # Filter out rows where essential data might be null, and format correctly
        dashboard_data = [
            {k: v for k, v in dict(row).items() if v is not None}
            for row in rows
        ]
        return dashboard_data
    except db_helpers.DatabaseError as e:
        logger.error("Dashboard data fetch failed: {}", e)
        raise HTTPException(status_code=500, detail="Database error.")


# THIS IS THE NEW CRITICAL ENDPOINT FOR LOW-LATENCY UPDATES
@router.post("/internal/webhook-event")
async def process_webhook_event(request: Request, background_tasks: BackgroundTasks):
    """
    Internal endpoint for the ingestion-service to push events to.
    This replaces the polling mechanism.
    """
    github_event = request.headers.get("x-github-event")
    payload = await request.json()
    logger.info("Received internal event push for event type: {}", github_event)

    async def handle_event():
        if github_event == "pull_request":
            await event_processor.process_pull_request_event(payload)
        elif github_event == "workflow_run":
            await event_processor.process_workflow_run_event(payload)
        else:
            logger.warning("Received unhandled event type: {}", github_event)

    # Run the processing in the background to return an immediate 200 OK
    background_tasks.add_task(handle_event)
    return {"status": "event received and queued for processing"}