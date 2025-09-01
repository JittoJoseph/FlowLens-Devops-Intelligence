# api_service/app/routes/api.py

import json
from fastapi import APIRouter, HTTPException
from loguru import logger
from app.data.database.core_db import get_db
from app.data.database import db_helpers

router = APIRouter(prefix="/api", tags=["Frontend API"])

@router.get("/prs")
async def get_all_pull_requests():
    """
    Endpoint 1: Fetches the initial state for the main dashboard.
    """
    logger.info("Fetching initial state for all pull requests...")
    try:
        # The ingestion service populates these tables, we just join and serve them.
        query = """
            SELECT
                pr.*,
                (SELECT to_json(p) FROM pipeline_runs p WHERE p.pr_number = pr.pr_number) AS pipeline_status,
                (SELECT to_json(i) FROM insights i
                 WHERE i.pr_number = pr.pr_number
                 ORDER BY i.created_at DESC LIMIT 1) AS ai_insight
            FROM pull_requests_view pr
            ORDER BY pr.updated_at DESC;
        """
        db = get_db()
        rows = await db.fetch_all(query)

        # This formatting logic now correctly handles JSON parsing and matches Flutter models.
        response_data = []
        for row in rows:
            pr_data = dict(row)
            pipeline_status = json.loads(pr_data['pipeline_status']) if pr_data['pipeline_status'] else {}
            
            status_map = {
                'merged': 'merged',
                'closed': 'closed',
                'passed': 'buildPassed',
                'failed': 'buildFailed',
                'running': 'building',
                'approved': 'approved',
                'opened': 'pending',
                'updated': 'pending'
            }
            pr_status = pipeline_status.get('status_pr', 'pending')
            build_status = pipeline_status.get('status_build', 'pending')
            approval_status = pipeline_status.get('status_approval', 'pending')
            merge_status = pipeline_status.get('status_merge', 'pending')

            final_status = 'pending'
            if merge_status in ['merged', 'closed']: final_status = status_map[merge_status]
            elif approval_status == 'approved': final_status = status_map[approval_status]
            elif build_status in ['passed', 'failed']: final_status = status_map[build_status]
            elif build_status == 'running': final_status = status_map[build_status]
            elif pr_status in ['opened', 'updated']: final_status = status_map[pr_status]

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
                "status": final_status,
                "filesChanged": pr_data.get('files_changed', []),
                "additions": pr_data['additions'],
                "deletions": pr_data['deletions'],
                "branchName": pr_data['branch_name'],
                "isDraft": pr_data['is_draft'],
            })
        
        logger.success(f"Successfully fetched and formatted {len(response_data)} PRs.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch dashboard data", exception=e)
        raise HTTPException(status_code=500, detail="An internal error occurred.")


@router.get("/insights/{pr_number}")
async def get_insights_for_pr(pr_number: int):
    """
    Endpoint 2: Fetches all historical AI insights for a specific Pull Request.
    """
    logger.info(f"Fetching all insights for PR #{pr_number}")
    try:
        insights = await db_helpers.select(
            "insights", where={"pr_number": pr_number}, order_by="created_at", desc=True
        )
        return [
            {
                "id": i['id'], "prNumber": i['pr_number'], "commitSha": i['commit_sha'],
                "riskLevel": i['risk_level'].lower(), "summary": i['summary'],
                "recommendation": i['recommendation'], "createdAt": i['created_at'].isoformat(),
                "keyChanges": [], "confidenceScore": 0.0
            } for i in insights
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
        "name": "FlowLens-Demo", "fullName": "DevByZero/FlowLens-Demo",
        "description": "AI-Powered DevOps Workflow Visualizer", "owner": "DevByZero",
        "ownerAvatar": "https://avatars.githubusercontent.com/u/1", "isPrivate": True,
        "defaultBranch": "main", "openPRs": 1, "totalPRs": 10,
        "lastActivity": "2025-08-30T10:00:00Z",
        "languages": ["Dart", "Python", "Node.js"], "stars": 42, "forks": 12
    }