# api_service/app/routes/api.py

import json
from typing import Optional
from datetime import datetime
from fastapi import APIRouter, HTTPException, Query
from loguru import logger
from app.data.database.core_db import get_db
from app.data.database import db_helpers

router = APIRouter(prefix="/api", tags=["Frontend API"])


def _serialize_datetime_fields(data: dict) -> dict:
    """Convert datetime objects to ISO format strings for JSON serialization."""
    serialized = {}
    for key, value in data.items():
        if isinstance(value, datetime):
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    return serialized


@router.get("/repositories")
async def get_repositories():
    """
    Returns all repositories in the system with complete metadata.
    Uses SELECT * for future schema flexibility.
    """
    logger.info("Fetching all repositories...")
    try:
        repositories = await db_helpers.select(
            table="repositories",
            order_by="updated_at",
            desc=True
        )
        
        # Serialize datetime fields and return all fields
        response_data = [_serialize_datetime_fields(repo) for repo in repositories]
        
        logger.success(f"Successfully fetched {len(response_data)} repositories.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch repositories", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch repositories.")


@router.get("/pull-requests")
async def get_pull_requests(repository_id: Optional[str] = Query(None, description="Filter by repository ID")):
    """
    Returns pull requests with optional repository filtering.
    Excludes files_changed field (internal only) and simplifies history.
    """
    logger.info(f"Fetching pull requests{f' for repository {repository_id}' if repository_id else ' (all repositories)'}...")
    try:
        where_clause = {"repo_id": repository_id} if repository_id else None
        
        pull_requests = await db_helpers.select(
            table="pull_requests",
            where=where_clause,
            order_by="updated_at",
            desc=True
        )
        
        # Process each PR to exclude files_changed and simplify history
        response_data = []
        for pr in pull_requests:
            pr_data = _serialize_datetime_fields(pr)
            
            # Remove files_changed field (internal only)
            pr_data.pop('files_changed', None)
            
            # Simplify history to only state + timestamp
            original_history = pr_data.get('history', [])
            simplified_history = []
            for history_item in original_history:
                if isinstance(history_item, dict) and 'state' in history_item:
                    simplified_history.append({
                        "state": history_item['state'],
                        "timestamp": history_item.get('at', history_item.get('timestamp', ''))
                    })
            pr_data['history'] = simplified_history
            
            response_data.append(pr_data)
        
        logger.success(f"Successfully fetched {len(response_data)} pull requests.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch pull requests", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch pull requests.")


@router.get("/pipelines")
async def get_pipeline_runs(repository_id: Optional[str] = Query(None, description="Filter by repository ID")):
    """
    Returns pipeline runs with optional repository filtering.
    Includes all fields using SELECT * for flexibility.
    """
    logger.info(f"Fetching pipeline runs{f' for repository {repository_id}' if repository_id else ' (all repositories)'}...")
    try:
        where_clause = {"repo_id": repository_id} if repository_id else None
        
        pipeline_runs = await db_helpers.select(
            table="pipeline_runs",
            where=where_clause,
            order_by="updated_at",
            desc=True
        )
        
        # Serialize datetime fields and return all fields
        response_data = [_serialize_datetime_fields(pipeline) for pipeline in pipeline_runs]
        
        logger.success(f"Successfully fetched {len(response_data)} pipeline runs.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch pipeline runs", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch pipeline runs.")


@router.get("/insights")
async def get_insights(
    repository_id: Optional[str] = Query(None, description="Filter by repository ID"),
    pr_id: Optional[int] = Query(None, description="Filter by PR number")
):
    """
    Returns AI insights with optional repository and PR filtering.
    Includes PR details like additions, deletions, and changed files.
    """
    logger.info(f"Fetching insights{f' for repository {repository_id}' if repository_id else ''}{f' for PR #{pr_id}' if pr_id else ''}...")
    try:
        # Get database connection for complex query
        db = get_db()
        
        # Build WHERE clause
        where_conditions = []
        params = {}
        
        if repository_id:
            where_conditions.append("i.repo_id = :repository_id")
            params["repository_id"] = repository_id
        if pr_id:
            where_conditions.append("i.pr_number = :pr_id")
            params["pr_id"] = pr_id
            
        where_clause = " AND ".join(where_conditions) if where_conditions else "1=1"
        
        # Enhanced query to join insights with pull_requests for additional details
        query = f"""
            SELECT 
                i.*,
                pr.additions,
                pr.deletions,
                pr.changed_files,
                pr.files_changed
            FROM insights i
            LEFT JOIN pull_requests pr ON i.repo_id = pr.repo_id AND i.pr_number = pr.pr_number
            WHERE {where_clause}
            ORDER BY i.created_at DESC
        """
        
        insights = await db.fetch_all(query, params)
        
        # Clean and format insights for API response
        response_data = []
        for insight in insights:
            # Extract file paths from files_changed JSONB
            files_changed = insight.get('files_changed', [])
            if isinstance(files_changed, str):
                try:
                    files_changed = json.loads(files_changed)
                except json.JSONDecodeError:
                    files_changed = []
            
            file_paths = []
            if isinstance(files_changed, list):
                for file_change in files_changed:
                    if isinstance(file_change, dict) and 'filename' in file_change:
                        file_paths.append(file_change['filename'])
                    elif isinstance(file_change, str):
                        file_paths.append(file_change)
            
            cleaned_insight = {
                "id": insight['id'],
                "repo_id": insight['repo_id'],
                "pr_number": insight['pr_number'],
                "commit_sha": insight['commit_sha'],
                "author": insight['author'],
                "avatar_url": insight['avatar_url'],
                "risk_level": insight['risk_level'],
                "summary": insight['summary'],
                "recommendation": insight['recommendation'],
                "created_at": insight['created_at'].isoformat() if insight['created_at'] else None,
                # Additional PR details
                "additions": insight.get('additions', 0),
                "deletions": insight.get('deletions', 0),
                "changed_files_count": insight.get('changed_files', 0),
                "changed_file_paths": file_paths
            }
            response_data.append(cleaned_insight)
        
        logger.success(f"Successfully fetched {len(response_data)} insights with PR details.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch insights", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch insights.")


@router.get("/insights/{pr_number}")
async def get_insights_for_pr(pr_number: int, repository_id: Optional[str] = Query(None, description="Filter by repository ID")):
    """
    Fetches all historical AI insights for a specific PR.
    Optionally filtered by repository for multi-repo scenarios.
    """
    logger.info(f"Fetching insights for PR #{pr_number}{f' in repository {repository_id}' if repository_id else ''}...")
    try:
        where_clause = {"pr_number": pr_number}
        if repository_id:
            where_clause["repo_id"] = repository_id
            
        insights = await db_helpers.select(
            table="insights",
            where=where_clause,
            order_by="created_at",
            desc=True
        )
        
        # Format for backward compatibility with Flutter app
        response_data = []
        for insight in insights:
            response_data.append({
                "id": insight['id'],
                "prNumber": insight['pr_number'],
                "repositoryId": insight['repo_id'],
                "commitSha": insight['commit_sha'],
                "author": insight['author'],
                "avatarUrl": insight['avatar_url'],
                "riskLevel": insight['risk_level'].lower() if insight.get('risk_level') else 'low',
                "summary": insight['summary'],
                "recommendation": insight['recommendation'],
                "createdAt": insight['created_at'].isoformat(),
                # Legacy fields for Flutter compatibility
                "keyChanges": [],
                "confidenceScore": 0
            })
        
        logger.success(f"Successfully fetched {len(response_data)} insights for PR #{pr_number}.")
        return response_data
    except Exception as e:
        logger.error(f"Failed to fetch insights for PR #{pr_number}", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch insights.")


# Legacy endpoint for backward compatibility
@router.get("/prs")
async def get_all_pull_requests_legacy():
    """
    Legacy endpoint for backward compatibility with existing Flutter app.
    Returns aggregated PR data with pipeline status and repository info.
    """
    logger.info("Fetching aggregated PR data (legacy endpoint)...")
    try:
        db = get_db()
        query = """
            SELECT 
                pr.*,
                r.name as repository_name,
                r.full_name as repository_full_name,
                r.owner as repository_owner,
                (SELECT to_json(p) FROM pipeline_runs p WHERE p.repo_id = pr.repo_id AND p.pr_number = pr.pr_number) AS pipeline_status
            FROM pull_requests pr
            JOIN repositories r ON pr.repo_id = r.id
            ORDER BY pr.updated_at DESC
        """
        
        rows = await db.fetch_all(query)
        response_data = []
        
        for row in rows:
            pr_data = dict(row)
            pipeline_status = json.loads(pr_data['pipeline_status']) if pr_data.get('pipeline_status') else {}
            
            # Status determination logic
            status_map = {
                'merged': 'merged',
                'closed': 'closed',
                'buildPassed': 'buildPassed',
                'passed': 'buildPassed',
                'buildFailed': 'buildFailed',
                'failed': 'buildFailed',
                'building': 'building',
                'running': 'building',
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
                final_status = status_map.get(merge_status, 'pending')
            elif approval_status == 'approved':
                final_status = status_map.get(approval_status, 'pending')
            elif build_status in ['passed', 'failed', 'building', 'running', 'buildPassed', 'buildFailed']:
                final_status = status_map.get(build_status, 'pending')
            elif pr_status in ['opened', 'updated']:
                final_status = status_map.get(pr_status, 'pending')

            # Format for Flutter compatibility (exclude files_changed field)
            response_data.append({
                "number": pr_data['pr_number'],
                "title": pr_data['title'],
                "author": pr_data['author'],
                "authorAvatar": pr_data['author_avatar'],
                "commitSha": pr_data['commit_sha'],
                "repositoryName": pr_data['repository_name'],
                "repositoryFullName": pr_data['repository_full_name'],
                "repositoryId": pr_data['repo_id'],
                "createdAt": pr_data['created_at'].isoformat(),
                "updatedAt": pr_data['updated_at'].isoformat(),
                "status": final_status,
                "additions": pr_data['additions'],
                "deletions": pr_data['deletions'],
                "branchName": pr_data['branch_name'],
                "isDraft": pr_data['is_draft'],
            })
        
        logger.success(f"Successfully fetched and formatted {len(response_data)} PRs (legacy).")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch legacy PR data", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch PR data.")


@router.get("/repository")
async def get_repository_info_legacy():
    """
    Legacy endpoint providing repository information.
    Now fetches from actual repositories table if available, fallback to static data.
    """
    logger.info("Fetching repository information (legacy endpoint)...")
    try:
        # Try to fetch the first repository from the database
        repositories = await db_helpers.select(
            table="repositories",
            order_by="updated_at",
            desc=True,
            limit=1
        )
        
        if repositories:
            repo = repositories[0]
            return {
                "name": repo['name'],
                "fullName": repo['full_name'],
                "description": repo['description'] or "AI-Powered DevOps Workflow Visualizer",
                "owner": repo['owner'],
                "ownerAvatar": f"https://avatars.githubusercontent.com/u/{repo['github_id']}",
                "isPrivate": repo['is_private'],
                "defaultBranch": repo['default_branch'],
                "openPRs": repo['open_prs'],
                "totalPRs": repo['total_prs'],
                "lastActivity": repo['last_activity'].isoformat() if repo['last_activity'] else None,
                "languages": [repo['language']] if repo['language'] else ["Unknown"],
                "stars": repo['stars'],
                "forks": repo['forks']
            }
        else:
            # Fallback to static data if no repositories found
            return {
                "name": "FlowLens-Demo",
                "fullName": "DevByZero/FlowLens-Demo",
                "description": "AI-Powered DevOps Workflow Visualizer",
                "owner": "DevByZero",
                "ownerAvatar": "https://avatars.githubusercontent.com/u/1",
                "isPrivate": True,
                "defaultBranch": "main",
                "openPRs": 0,
                "totalPRs": 0,
                "lastActivity": "2025-08-30T10:00:00Z",
                "languages": ["Dart", "Python", "Node.js"],
                "stars": 42,
                "forks": 12
            }
    except Exception as e:
        logger.error("Failed to fetch repository info", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch repository information.")