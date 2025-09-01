# api_service/app/routes/api.py

import json
from datetime import datetime
from fastapi import APIRouter, HTTPException
from loguru import logger
from app.data.database.core_db import get_db
from app.data.database import db_helpers

router = APIRouter(prefix="/api", tags=["Frontend API"])

@router.get("/prs")
async def get_all_pull_requests():
    """
    Endpoint 1: Fetches the initial state for the main dashboard.
    This query is now aligned with the new `pull_requests` and `pipeline_runs` tables.
    """
    logger.info("Fetching initial state for all pull requests...")
    try:
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
                (SELECT to_json(p) FROM pipeline_runs p WHERE p.pr_number = pr.pr_number) AS pipeline_status
            FROM pull_requests pr
            ORDER BY pr.updated_at DESC;
        """
        db = get_db()
        rows = await db.fetch_all(query)

        response_data = []
        for row in rows:
            pr_data = dict(row)
            pipeline_status = json.loads(pr_data['pipeline_status']) if pr_data.get('pipeline_status') else {}
            
            # This logic determines the single 'status' string for the Flutter UI card.
            status_map = {
                'merged': 'merged',
                'closed': 'closed',
                'buildPassed': 'buildPassed',
                'passed': 'buildPassed', # Handle variations
                'buildFailed': 'buildFailed',
                'failed': 'buildFailed', # Handle variations
                'building': 'building',
                'running': 'building', # Handle variations
                'approved': 'approved',
                'opened': 'pending',
                'updated': 'pending'
            }
            merge_status = pipeline_status.get('status_merge', 'pending')
            approval_status = pipeline_status.get('status_approval', 'pending')
            build_status = pipeline_status.get('status_build', 'pending')
            pr_status = pipeline_status.get('status_pr', 'pending')

            final_status = 'pending'
            if merge_status in ['merged', 'closed']:
                final_status = status_map[merge_status]
            elif approval_status == 'approved':
                final_status = status_map[approval_status]
            elif build_status in ['passed', 'failed', 'building', 'running']:
                final_status = status_map[build_status]
            elif pr_status in ['opened', 'updated']:
                final_status = status_map[pr_status]

            # Construct the final JSON object matching the README and Flutter models.
            response_data.append({
                "number": pr_data['pr_number'],
                "title": pr_data['title'],
                "author": pr_data['author'],
                "authorAvatar": pr_data['author_avatar'],
                "commitSha": pr_data['commit_sha'],
                "repositoryName": pr_data['repository_name'],
                "createdAt": pr_data['created_at'].isoformat(),
                "updatedAt": pr_data['updated_at'].isoformat(),
                "status": final_status,
                "filesChanged": "[]", # This field is no longer in the DB, send empty list.
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
    """Endpoint 2: Fetches all historical AI insights for a specific PR."""
    logger.info(f"Fetching all insights for PR #{pr_number}")
    try:
        insights = await db_helpers.select(
            "insights", where={"pr_number": pr_number}, order_by="created_at", desc=True
        )
        return [
            {
                "id": i['id'], "prNumber": i['pr_number'], "commitSha": i['commit_sha'],
                "riskLevel": i['risk_level'].lower() if i.get('risk_level') else 'low',
                "summary": i['summary'],
                "recommendation": i['recommendation'],
                "createdAt": i['created_at'].isoformat(),
                "keyChanges": [], # Static fields as per README
                "confidenceScore": 0 # Static fields as per README
            } for i in insights
        ]
    except db_helpers.DatabaseError as e:
        logger.error(f"Failed to fetch insights for PR #{pr_number}", exception=e)
        raise HTTPException(status_code=500, detail="Database error.")


@router.get("/repository")
async def get_repository_info():
    """Endpoint 3: Provides static repository information for the demo."""
    logger.info("Fetching hardcoded repository information.")
    # This remains the same as it's static demo data.
    return {
        "name": "FlowLens-Demo", "fullName": "DevByZero/FlowLens-Demo",
        "description": "AI-Powered DevOps Workflow Visualizer", "owner": "DevByZero",
        "ownerAvatar": "https://avatars.githubusercontent.com/u/1", "isPrivate": True,
        "defaultBranch": "main", "openPRs": 1, "totalPRs": 10,
        "lastActivity": "2025-08-30T10:00:00Z",
        "languages": ["Dart", "Python", "Node.js"], "stars": 42, "forks": 12
    }