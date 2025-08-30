# api_service/app/routes/api.py

from fastapi import APIRouter, HTTPException
from loguru import logger
from app.data.database import db_helpers

# Renamed the router to be more generic for all API endpoints
router = APIRouter(prefix="/api", tags=["Frontend API"])

@router.get("/prs")
async def get_all_pull_requests():
    """
    Endpoint 1: Fetches the initial state for the main dashboard.
    Combines data from all tables to match the Flutter app's needs.
    """
    logger.info("Fetching initial state for all pull requests...")
    try:
        # This single, efficient query builds the entire initial state for the dashboard
        query = """
            SELECT
                pr.pr_number, pr.title, pr.description, pr.author, pr.author_avatar,
                pr.commit_sha, pr.repository_name, pr.created_at, pr.updated_at,
                pr.branch_name, pr.files_changed, pr.additions, pr.deletions, pr.is_draft,
                -- Combine all pipeline statuses into a single status object
                json_build_object(
                    'pr', COALESCE(p.status_pr, 'pending'),
                    'build', COALESCE(p.status_build, 'pending'),
                    'approval', COALESCE(p.status_approval, 'pending'),
                    'merge', COALESCE(p.status_merge, 'pending')
                ) AS status,
                -- Get the latest AI insight for this PR
                (SELECT to_json(i) FROM insights i
                 WHERE i.pr_number = pr.pr_number
                 ORDER BY i.created_at DESC LIMIT 1) AS "ai_insight"
            FROM pull_requests_view pr
            LEFT JOIN pipeline_runs p ON pr.pr_number = p.pr_number
            ORDER BY pr.updated_at DESC;
        """
        pool = await db_helpers.get_pool()
        async with pool.acquire() as connection:
            rows = await connection.fetch(query)
        
        # Format the data exactly as the Flutter models expect
        response_data = []
        for row in rows:
            pr_data = dict(row)
            # The query already structures most of it, we just need to assemble
            # into the final list of PR objects
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
                "status": pr_data['status']['pr'], # A simplified main status
                "filesChanged": pr_data['files_changed'],
                "additions": pr_data['additions'],
                "deletions": pr_data['deletions'],
                "branchName": pr_data['branch_name'],
                "isDraft": pr_data['is_draft'],
                # We can embed the insight and full status directly if needed
                # "fullStatus": pr_data['status'],
                # "aiInsight": pr_data['ai_insight']
            })

        logger.success(f"Successfully fetched {len(response_data)} PRs for dashboard.")
        return response_data

    except Exception as e:
        logger.error("Failed to fetch dashboard data", exception=e)
        raise HTTPException(status_code=500, detail="Database error occurred.")


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
            raise HTTPException(status_code=404, detail=f"No insights found for PR #{pr_number}")
        
        # Format to match AIInsight.fromJson factory
        return [
            {
                "id": insight['id'],
                "prNumber": insight['pr_number'],
                "commitSha": insight['commit_sha'],
                "riskLevel": insight['risk_level'],
                "summary": insight['summary'],
                "recommendation": insight['recommendation'],
                "createdAt": insight['created_at'].isoformat(),
                "keyChanges": [], # You can add this to your prompt/DB if needed
                "confidenceScore": 0.0 # You can add this to your prompt/DB if needed
            } for insight in insights
        ]
    except db_helpers.DatabaseError as e:
        logger.error(f"Failed to fetch insights for PR #{pr_number}", exception=e)
        raise HTTPException(status_code=500, detail="Database error.")


@router.get("/repository")
async def get_repository_info():
    """
    Endpoint 3: Provides static, hardcoded repository information for the demo.
    """
    logger.info("Fetching hardcoded repository information.")
    # In a real app, this data would be fetched from the DB or GitHub API
    return {
        "name": "FlowLens-Demo",
        "fullName": "DevByZero/FlowLens-Demo",
        "description": "AI-Powered DevOps Workflow Visualizer",
        "owner": "DevByZero",
        "ownerAvatar": "https://avatars.githubusercontent.com/u/your-org-id",
        "isPrivate": True,
        "defaultBranch": "main",
        "openPRs": 1, # You could make this a live query for extra points
        "totalPRs": 10,
        "lastActivity": "2025-08-30T10:00:00Z",
        "languages": ["Dart", "Python", "Node.js"],
        "stars": 42,
        "forks": 12
    }