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


async def _build_pr_history(repo_id: str, pr_number: int) -> list:
    """
    Build comprehensive PR history by extracting state changes from PR history.
    Returns a chronological list of state changes with state_name and timestamp.
    """
    try:
        # Get PR record with history
        pr_records = await db_helpers.select(
            table="pull_requests",
            where={"repo_id": repo_id, "pr_number": pr_number},
            limit=1
        )
        
        if not pr_records:
            logger.warning(f"No PR record found for repo {repo_id}, PR #{pr_number}")
            return []
        
        pr_history = pr_records[0].get('history', [])
        
        # Handle case where history might be stored as JSON string
        if isinstance(pr_history, str):
            try:
                pr_history = json.loads(pr_history)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in history field for PR #{pr_number}")
                return []
        
        if not isinstance(pr_history, list):
            logger.warning(f"History field is not a list for PR #{pr_number}, type: {type(pr_history)}")
            return []
        
        logger.info(f"Found {len(pr_history)} history events for PR #{pr_number}")
        
        # Extract meaningful state changes from PR history
        history_events = []
        seen_states = set()
        
        for event in pr_history:
            if not isinstance(event, dict):
                continue
                
            # Check if this event has a meaningful state
            state = event.get('state')
            timestamp = event.get('at')
            
            if not state or not timestamp:
                continue
            
            # Only include workflow-related states, skip generic ones
            meaningful_states = {
                'opened', 'building', 'buildPassed', 'buildFailed', 
                'approved', 'rejected', 'merged', 'closed', 'open'
            }
            
            if state in meaningful_states and state not in seen_states:
                history_events.append({
                    "state_name": state,
                    "timestamp": timestamp
                })
                seen_states.add(state)
                logger.debug(f"Added history event: {state} at {timestamp}")
        
        # Sort by timestamp to ensure chronological order
        history_events.sort(key=lambda x: x['timestamp'])
        
        logger.info(f"Extracted {len(history_events)} meaningful events for PR #{pr_number}")
        return history_events
        
    except Exception as e:
        logger.error(f"Failed to build history for PR #{pr_number} in repo {repo_id}: {e}")
        return []


async def _calculate_pr_metrics(repo_id: str) -> dict:
    """Calculate comprehensive PR metrics for a repository."""
    try:
        # Get all PRs for this repository
        all_prs = await db_helpers.select(
            table="pull_requests",
            where={"repo_id": repo_id}
        )
        
        total = len(all_prs)
        open_count = 0
        merged_count = 0
        closed_count = 0
        draft_count = 0
        total_changes = 0
        pr_count_with_changes = 0
        
        for pr in all_prs:
            state = pr.get("state", "open")
            merged = pr.get("merged", False)
            is_draft = pr.get("is_draft", False)
            
            if is_draft:
                draft_count += 1
            elif merged:
                merged_count += 1
            elif state == "closed":
                closed_count += 1
            elif state == "open":
                open_count += 1
            
            # Calculate average PR size
            additions = pr.get("additions", 0) or 0
            deletions = pr.get("deletions", 0) or 0
            if additions > 0 or deletions > 0:
                total_changes += additions + deletions
                pr_count_with_changes += 1
        
        avg_changes = total_changes // pr_count_with_changes if pr_count_with_changes > 0 else 0
        
        return {
            "total": total,
            "open": open_count,
            "merged": merged_count,
            "closed": closed_count,
            "draft": draft_count,
            "avg_changes": avg_changes
        }
        
    except Exception as e:
        logger.error(f"Failed to calculate PR metrics for repo {repo_id}: {e}")
        return {"total": 0, "open": 0, "merged": 0, "closed": 0, "draft": 0, "avg_changes": 0}


async def _calculate_pipeline_metrics(repo_id: str) -> dict:
    """Calculate pipeline status metrics for a repository."""
    try:
        # Get all pipeline runs for this repository
        pipelines = await db_helpers.select(
            table="pipeline_runs",
            where={"repo_id": repo_id}
        )
        
        build_passed = 0
        build_failed = 0
        building = 0
        pending_approval = 0
        approved = 0
        
        for pipeline in pipelines:
            status_build = pipeline.get("status_build", "pending")
            status_approval = pipeline.get("status_approval", "pending")
            
            # Count build statuses
            if status_build == "buildPassed":
                build_passed += 1
            elif status_build == "buildFailed":
                build_failed += 1
            elif status_build == "building":
                building += 1
            
            # Count approval statuses
            if status_approval == "approved":
                approved += 1
            elif status_approval == "pending":
                pending_approval += 1
        
        return {
            "buildPassed": build_passed,
            "buildFailed": build_failed,
            "building": building,
            "pendingApproval": pending_approval,
            "approved": approved
        }
        
    except Exception as e:
        logger.error(f"Failed to calculate pipeline metrics for repo {repo_id}: {e}")
        return {"buildPassed": 0, "buildFailed": 0, "building": 0, "pendingApproval": 0, "approved": 0}


async def _count_insights(repo_id: str) -> int:
    """Count total insights generated for a repository."""
    try:
        insights = await db_helpers.select(
            table="insights",
            where={"repo_id": repo_id}
        )
        return len(insights)
    except Exception as e:
        logger.error(f"Failed to count insights for repo {repo_id}: {e}")
        return 0


@router.get("/repositories")
async def get_repositories():
    """
    Returns all repositories in the system with complete metadata and accurate counts.
    Calculates real-time metrics from pull_requests and pipeline_runs tables.
    """
    logger.info("Fetching all repositories with enhanced metrics...")
    try:
        repositories = await db_helpers.select(
            table="repositories",
            order_by="updated_at",
            desc=True
        )
        
        # Enhanced response data with calculated metrics
        response_data = []
        
        for repo in repositories:
            repo_data = _serialize_datetime_fields(repo)
            repo_id = repo['id']
            
            # Calculate PR metrics
            pr_metrics = await _calculate_pr_metrics(repo_id)
            
            # Calculate pipeline metrics  
            pipeline_metrics = await _calculate_pipeline_metrics(repo_id)
            
            # Enhanced repository data with accurate counts
            enhanced_repo = {
                **repo_data,
                # Accurate PR counts
                "total_prs": pr_metrics["total"],
                "open_prs": pr_metrics["open"],
                "merged_prs": pr_metrics["merged"],
                "closed_prs": pr_metrics["closed"],
                "draft_prs": pr_metrics["draft"],
                
                # Pipeline status counts
                "build_passed": pipeline_metrics["buildPassed"],
                "build_failed": pipeline_metrics["buildFailed"],
                "builds_running": pipeline_metrics["building"],
                "pending_approval": pipeline_metrics["pendingApproval"],
                "approved_prs": pipeline_metrics["approved"],
                
                # Additional insights
                "avg_pr_size": pr_metrics["avg_changes"],
                "total_insights": await _count_insights(repo_id),
                
                # Keep original fields for compatibility
                "stars": repo_data.get("stars", 0),
                "forks": repo_data.get("forks", 0)
            }
            
            response_data.append(enhanced_repo)
        
        logger.success(f"Successfully fetched {len(response_data)} repositories with enhanced metrics.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch repositories", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch repositories.")


@router.get("/pull-requests")
async def get_pull_requests(repository_id: Optional[str] = Query(None, description="Filter by repository ID")):
    """
    Returns pull requests with optional repository filtering.
    Excludes files_changed field (internal only) and builds comprehensive history from both PR and pipeline data.
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
        
        # Process each PR to build comprehensive history
        response_data = []
        for pr in pull_requests:
            pr_data = _serialize_datetime_fields(pr)
            
            # Remove files_changed field (internal only)
            pr_data.pop('files_changed', None)
            
            # Build comprehensive history from PR history and pipeline data
            comprehensive_history = await _build_pr_history(pr['repo_id'], pr['pr_number'])
            pr_data['history'] = comprehensive_history
            
            response_data.append(pr_data)
        
        logger.success(f"Successfully fetched {len(response_data)} pull requests with comprehensive history.")
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
    Returns latest 15 insights when no specific filters are provided.
    """
    logger.info(f"Fetching insights{f' for repository {repository_id}' if repository_id else ''}{f' for PR #{pr_id}' if pr_id else ''}...")
    try:
        # Build where clause for simple query
        where_clause = {}
        if repository_id:
            where_clause["repo_id"] = repository_id
        if pr_id:
            where_clause["pr_number"] = pr_id
        
        # Use simple query to fetch insights
        insights = await db_helpers.select(
            table="insights",
            where=where_clause if where_clause else None,
            order_by="created_at",
            desc=True,
            limit=15  # Return latest 15 insights when no specific filter
        )
        
        # Format insights for API response
        response_data = []
        for insight in insights:
            insight_data = _serialize_datetime_fields(insight)
            
            # Get additional PR details if needed
            pr_details = None
            if insight['repo_id'] and insight['pr_number']:
                try:
                    pr_records = await db_helpers.select(
                        table="pull_requests",
                        where={"repo_id": insight['repo_id'], "pr_number": insight['pr_number']},
                        limit=1
                    )
                    if pr_records:
                        pr_details = pr_records[0]
                except Exception as pr_error:
                    logger.warning(f"Could not fetch PR details for insight {insight['id']}: {pr_error}")
            
            # Extract file paths from PR details if available
            file_paths = []
            if pr_details:
                files_changed = pr_details.get('files_changed', [])
                if isinstance(files_changed, str):
                    try:
                        files_changed = json.loads(files_changed)
                    except json.JSONDecodeError:
                        files_changed = []
                
                if isinstance(files_changed, list):
                    for file_change in files_changed:
                        if isinstance(file_change, dict) and 'filename' in file_change:
                            file_paths.append(file_change['filename'])
            
            cleaned_insight = {
                "id": insight_data['id'],
                "repo_id": insight_data['repo_id'],
                "pr_number": insight_data['pr_number'],
                "commit_sha": insight_data['commit_sha'],
                "author": insight_data['author'],
                "avatar_url": insight_data['avatar_url'],
                "risk_level": insight_data['risk_level'],
                "summary": insight_data['summary'],
                "recommendation": insight_data['recommendation'],
                "created_at": insight_data['created_at'],
                # Additional PR details (0 if no PR details available)
                "additions": pr_details.get('additions', 0) if pr_details else 0,
                "deletions": pr_details.get('deletions', 0) if pr_details else 0,
                "changed_files_count": pr_details.get('changed_files', 0) if pr_details else 0,
                "changed_file_paths": file_paths
            }
            response_data.append(cleaned_insight)
        
        logger.success(f"Successfully fetched {len(response_data)} insights.")
        return response_data
    except Exception as e:
        logger.error("Failed to fetch insights", exception=e)
        raise HTTPException(status_code=500, detail="Failed to fetch insights.")


@router.get("/insights/{pr_number}")
async def get_insights_for_pr(pr_number: int, repository_id: Optional[str] = Query(None, description="Filter by repository ID")):
    """
    Fetches all historical AI insights for a specific PR.
    Optionally filtered by repository for multi-repo scenarios.
    Includes filenames in keyChanges field.
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
            # Get PR details to extract filenames for keyChanges
            key_changes = []
            try:
                pr_records = await db_helpers.select(
                    table="pull_requests",
                    where={"repo_id": insight['repo_id'], "pr_number": insight['pr_number']},
                    limit=1
                )
                
                if pr_records:
                    pr_details = pr_records[0]
                    files_changed = pr_details.get('files_changed', [])
                    
                    # Handle JSON string format
                    if isinstance(files_changed, str):
                        try:
                            files_changed = json.loads(files_changed)
                        except json.JSONDecodeError:
                            files_changed = []
                    
                    # Extract filenames
                    if isinstance(files_changed, list):
                        for file_change in files_changed:
                            if isinstance(file_change, dict) and 'filename' in file_change:
                                key_changes.append(file_change['filename'])
                                
            except Exception as pr_error:
                logger.warning(f"Could not fetch PR details for insight {insight['id']}: {pr_error}")
            
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
                # Populated with actual filenames from files_changed
                "keyChanges": key_changes,
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