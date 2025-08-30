# api_service/app/routes/api.py

import json # <-- **FIX 1: Import the JSON library**
from fastapi import APIRouter, HTTPException
from loguru import logger
from app.data.database import db_helpers

router = APIRouter(prefix="/api", tags=["Frontend API"])

@router.get("/prs")
async def get_all_pull_requests():
    """
    Endpoint 1: Fetches the initial state for the main dashboard.
    (FIXED to correctly parse JSON from the database).
    """
    logger.info("Fetching initial state for all pull requests...")
    try:
        query = """
            SELECT
                pr.*,
                -- Pipeline statuses are aggregated into a single JSON object
                (SELECT to_json(p) FROM pipeline_runs p WHERE p.pr_number = pr.pr_number) AS pipeline_status,
                -- The latest AI insight is selected as a single JSON object
                (SELECT to_json(i) FROM insights i
                 WHERE i.pr_number = pr.pr_number
                 ORDER BY i.created_at DESC LIMIT 1) AS ai_insight
            FROM pull_requests_view pr
            ORDER BY pr.updated_at DESC;
        """
        pool = await db_helpers.get_pool()
        async with pool.acquire() as connection:
            rows = await connection.fetch(query)

        response_data = []
        for row in rows:
            pr_data = dict(row)

            # --- FIX 2: Parse the JSON strings into Python dictionaries ---
            # Handle cases where a PR might not have a pipeline run or insight yet
            pipeline_status = json.loads(pr_data['pipeline_status']) if pr_data['pipeline_status'] else {}
            ai_insight = json.loads(pr_data['ai_insight']) if pr_data['ai_insight'] else None

            # --- FIX 3: Determine a single, representative status for the Flutter model ---
            # This logic can be adjusted to match your exact UI needs
            status_name = "pending"
            if pipeline_status.get('status_merge') in ['merged', 'closed']:
                status_name = pipeline_status['status_merge']
            elif pipeline_status.get('status_build') in ['build_passed', 'build_failed']:
                status_name = pipeline_status['status_build']
            elif pipeline_status.get('status_build') == 'building':
                status_name = 'building'
            elif pipeline_status.get('status_pr') == 'created':
                 status_name = 'pending' # Or 'opened' if you have that enum

            # Assemble the final JSON object in the exact format Flutter expects
            response_data.append({
                "number": pr_data['pr_number'],
                "title": pr_data['title'],
                "description": pr_data['description'],
                "author": pr_data['author'],
                "authorAvatar": pr_data['author_avatar'],
                "commitSha": pr_data['commit_sha'],
                "repositoryName": pr_data['repository_name'],
                "createdAt": pr_data['created_at'].isoformat(),
                "updatedAt": pr_data['updated_at'].isoformat(),
                "status": status_name,
                "filesChanged": pr_data.get('files_changed', []), # Use .get for safety
                "additions": pr_data['additions'],
                "deletions": pr_data['deletions'],
                "branchName": pr_data['branch_name'],
                "isDraft": pr_data['is_draft'],
                # You can now pass the full objects if your Flutter model needs them
                # "fullPipelineStatus": pipeline_status,
                # "latestAiInsight": ai_insight
            })

        logger.success(f"Successfully fetched and formatted {len(response_data)} PRs.")
        return response_data

    except Exception as e:
        # The new log line will give a full traceback for easier debugging
        logger.error("Failed to fetch dashboard data", exception=e)
        raise HTTPException(status_code=500, detail="An internal error occurred while fetching dashboard data.")


@router.get("/insights/{pr_number}")
async def get_insights_for_pr(pr_number: int):
    """
    Endpoint 2: Fetches all historical AI insights for a specific Pull Request.
    """
    logger.info(f"Fetching all insights for PR #{pr_number}")
    try:
        insights = await db_helpers.select(
            "insights",
            where={"pr_number": pr_number},
            order_by="created_at",
            desc=True
        )
        if not insights:
            # It's better to return an empty list than a 404 if the PR exists but has no insights
            return []
        
        return [
            {
                "id": insight['id'],
                "prNumber": insight['pr_number'],
                "commitSha": insight['commit_sha'],
                "riskLevel": insight['risk_level'].lower(), # Ensure enum compatibility
                "summary": insight['summary'],
                "recommendation": insight['recommendation'],
                "createdAt": insight['created_at'].isoformat(),
                "keyChanges": [], # Placeholder
                "confidenceScore": 0.0 # Placeholder
            } for insight in insights
        ]
    except db_helpers.DatabaseError as e:
        logger.error(f"Failed to fetch insights for PR #{pr_number}", exception=e)
        raise HTTPException(status_code=500, detail="Database error.")


@router.get("/repository")
async def get_repository_info():
    """
    Endpoint 3: Provides static repository information for the demo.
    """
    logger.info("Fetching hardcoded repository information.")
    return {
        "name": "FlowLens-Demo",
        "fullName": "DevByZero/FlowLens-Demo",
        "description": "AI-Powered DevOps Workflow Visualizer",
        "owner": "DevByZero",
        "ownerAvatar": "https://avatars.githubusercontent.com/u/1",
        "isPrivate": True,
        "defaultBranch": "main",
        "openPRs": 1,
        "totalPRs": 10,
        "lastActivity": "2025-08-30T10:00:00Z",
        "languages": ["Dart", "Python", "Node.js"],
        "stars": 42,
        "forks": 12
    }