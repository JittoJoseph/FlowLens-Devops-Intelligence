# api_service/app/services/event_processor.py

import json
import asyncio
from typing import Set
from datetime import datetime
from loguru import logger
from app.data.database import db_helpers
from app.services import ai_service
from app.services.websocket_manager import websocket_manager

# A simple in-memory lock to prevent race conditions
PROCESSING_EVENTS: Set[str] = set()

# Retry tracking for failed AI insights
FAILED_INSIGHTS_RETRY: dict = {}


def _serialize_datetime_fields(data: dict) -> dict:
    """Convert datetime objects to ISO format strings for JSON serialization."""
    serialized = {}
    for key, value in data.items():
        if isinstance(value, datetime):
            serialized[key] = value.isoformat()
        else:
            serialized[key] = value
    return serialized


async def process_new_pull_request(pr_record: dict):
    """
    Process a new or updated pull request.
    Generates AI insights for new PRs with files_changed data or attempts alternative approaches.
    For updates (status changes, approvals, etc.), just broadcasts the updated state.
    Now includes robust retry mechanisms and fallback strategies.
    """
    repo_id = pr_record['repo_id']
    pr_number = pr_record['pr_number']
    record_id = pr_record['id']
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"PR record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        logger.info(f"Processing PR #{pr_number} in repository {repo_id}")
        
        # Check if this is a genuinely new PR or just a status update
        files_changed = pr_record.get('files_changed', [])
        
        # Handle case where files_changed might be a JSON string
        if isinstance(files_changed, str):
            try:
                files_changed = json.loads(files_changed)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in files_changed for PR #{pr_number}")
                files_changed = []
        
        existing_insights = await db_helpers.select(
            "insights",
            where={"repo_id": repo_id, "pr_number": pr_number},
            limit=1
        )
        
        # Enhanced insight generation logic with fallback strategies
        should_attempt_insights = not existing_insights
        
        if should_attempt_insights:
            insight_success = False
            
            if files_changed:
                logger.info(f"New PR #{pr_number} detected with {len(files_changed)} changed files, generating AI analysis...")
                # Update pr_record with parsed files_changed for AI processing
                pr_record_with_parsed_files = pr_record.copy()
                pr_record_with_parsed_files['files_changed'] = files_changed
                insight_success = await _generate_ai_insight_for_pr_with_retry(pr_record_with_parsed_files)
            else:
                logger.warning(f"PR #{pr_number} has no files_changed data, attempting fallback insight generation...")
                # Fallback: Generate basic insight with available PR metadata
                insight_success = await _generate_fallback_insight(pr_record)
            
            if insight_success:
                # Broadcast as new PR with insight generation
                event_state = _determine_pr_event_state(pr_record)
                await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
            else:
                logger.error(f"Failed to generate any insight for PR #{pr_number}, will retry in background")
                # Schedule for background retry
                await _schedule_insight_retry(pr_record)
                
        elif existing_insights:
            logger.info(f"PR #{pr_number} update detected (status/approval change), broadcasting updated state...")
            # Broadcast as state update only
            event_state = _determine_pr_event_state(pr_record)
            await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        else:
            logger.info(f"PR #{pr_number} processing complete, broadcasting basic update...")
            # Broadcast as basic update
            event_state = _determine_pr_event_state(pr_record)
            await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        
    except Exception as e:
        logger.error(f"Failed to process PR #{pr_number} in repo {repo_id}", exception=e)
        raise e
    finally:
        PROCESSING_EVENTS.discard(record_id)


async def process_new_pipeline(pipeline_record: dict):
    """
    Process a new or updated pipeline run.
    """
    repo_id = pipeline_record['repo_id']
    pr_number = pipeline_record['pr_number']
    record_id = pipeline_record['id']
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"Pipeline record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        logger.info(f"Processing pipeline update for PR #{pr_number} in repository {repo_id}")
        
        # Determine the actual event state from pipeline status
        event_state = _determine_pipeline_event_state(pipeline_record)
        
        # Broadcast pipeline state change with actual event state
        await websocket_manager.broadcast_pr_state_update(repo_id, pr_number, event_state)
        
    except Exception as e:
        logger.error(f"Failed to process pipeline for PR #{pr_number} in repo {repo_id}", exception=e)
        raise e
    finally:
        PROCESSING_EVENTS.discard(record_id)


def _determine_pipeline_event_state(pipeline_record: dict) -> str:
    """
    Determine the actual event state from pipeline status fields.
    Returns the most recent/significant status change.
    """
    status_pr = pipeline_record.get('status_pr', 'pending')
    status_build = pipeline_record.get('status_build', 'pending')
    status_approval = pipeline_record.get('status_approval', 'pending')
    status_merge = pipeline_record.get('status_merge', 'pending')
    
    # Priority order: merged > approval > build > PR creation
    # Match the actual values stored in the database
    if status_merge == 'merged':
        return 'merged'
    elif status_merge == 'closed':
        return 'closed'
    elif status_merge == 'failed':
        return 'mergeFailed'
    elif status_approval == 'approved':
        return 'approved'
    elif status_approval == 'rejected':
        return 'rejected'
    elif status_build == 'buildPassed':
        return 'buildPassed'
    elif status_build == 'buildFailed':
        return 'buildFailed'
    elif status_build == 'building':
        return 'building'
    elif status_pr == 'opened' or status_pr == 'pending':
        return 'opened'
    else:
        return 'updated'


def _determine_pr_event_state(pr_record: dict) -> str:
    """
    Determine the actual event state from PR record fields.
    Returns the actual PR state based on fields.
    For PRs, check the most recent history entry to get the current workflow state.
    """
    state = pr_record.get('state', 'open')
    merged = pr_record.get('merged', False)
    is_draft = pr_record.get('is_draft', False)
    history = pr_record.get('history', [])
    
    # If we have history, use the most recent state
    if history and isinstance(history, list):
        latest_history = history[-1] if history else {}
        latest_state = latest_history.get('state')
        
        # Use history state if it's a workflow state
        if latest_state in ['building', 'buildPassed', 'buildFailed', 'approved', 'rejected']:
            return latest_state
    
    # Fallback to record-level state determination
    if merged:
        return 'merged'
    elif state == 'closed' and not merged:
        return 'closed'
    elif is_draft:
        return 'draft'
    elif state == 'open':
        return 'opened'
    else:
        return state


async def process_new_insight(insight_record: dict):
    """
    Process a new insight (usually generated by AI).
    Do not broadcast WebSocket events as insights are internal processing.
    """
    repo_id = insight_record['repo_id']
    pr_number = insight_record['pr_number']
    record_id = insight_record['id']
    
    if record_id in PROCESSING_EVENTS:
        logger.warning(f"Insight record {record_id} is already being processed. Skipping.")
        return
    
    PROCESSING_EVENTS.add(record_id)
    
    try:
        logger.info(f"Processing new insight for PR #{pr_number} in repository {repo_id}")
        
        # Insights are internal processing - no WebSocket broadcast needed
        # The initial PR or pipeline event already broadcasted the state
        
    except Exception as e:
        logger.error(f"Failed to process insight for PR #{pr_number} in repo {repo_id}", exception=e)
        raise e
    finally:
        PROCESSING_EVENTS.discard(record_id)


async def _generate_ai_insight_for_pr(pr_record: dict):
    """
    Generate AI insights for a PR using the files_changed data.
    Returns True if insights were generated, False otherwise.
    """
    try:
        repo_id = pr_record['repo_id']
        pr_number = pr_record['pr_number']
        
        # Check if we have files_changed data and parse it if it's a JSON string
        files_changed = pr_record.get('files_changed', [])
        if isinstance(files_changed, str):
            try:
                files_changed = json.loads(files_changed)
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON in files_changed for PR #{pr_number}")
                return False
        
        if not files_changed:
            logger.info(f"No files_changed data for PR #{pr_number}, skipping AI insight generation")
            return False
        
        # Generate AI insights using the AI service
        logger.info(f"Generating AI insights for PR #{pr_number} with {len(files_changed)} changed files")
        ai_insight_json = await ai_service.get_ai_insights(pr_record)
        
        logger.info(f"AI service returned: {ai_insight_json}")
        
        if ai_insight_json:
            # Store the insights in the database with processed=false initially
            insight_record = {
                "repo_id": repo_id,
                "pr_number": pr_number,
                "commit_sha": pr_record.get("commit_sha"),
                "author": pr_record.get("author"),
                "avatar_url": pr_record.get("author_avatar"),
                "risk_level": ai_insight_json.get("risk_level", ai_insight_json.get("riskLevel", "low")).lower(),
                "summary": ai_insight_json.get("summary"),
                "recommendation": ai_insight_json.get("recommendation"),
                "processed": False  # Will be processed by the poller
            }
            
            result = await db_helpers.insert("insights", insight_record)
            logger.success(f"Generated and saved AI insight for PR #{pr_number} in repository {repo_id}")
            return True
        else:
            logger.warning(f"AI insight generation failed for PR #{pr_number}")
            return False
            
    except Exception as e:
        logger.error(f"Failed to generate AI insight for PR #{pr_number}", exception=e)
        return False


async def _generate_ai_insight_for_pr_with_retry(pr_record: dict, max_retries: int = 3):
    """
    Enhanced AI insight generation with retry logic and progressive data reduction.
    Attempts multiple strategies to handle large file changes and API limitations.
    """
    repo_id = pr_record['repo_id']
    pr_number = pr_record['pr_number']
    
    for attempt in range(max_retries):
        try:
            logger.info(f"AI insight generation attempt {attempt + 1}/{max_retries} for PR #{pr_number}")
            
            # Progressive data reduction for large files
            if attempt > 0:
                pr_record = await _reduce_file_data_for_retry(pr_record, attempt)
            
            # Generate AI insights using the AI service
            ai_insight_json = await ai_service.get_ai_insights(pr_record)
            
            if ai_insight_json:
                # Store the insights in the database
                insight_record = {
                    "repo_id": repo_id,
                    "pr_number": pr_number,
                    "commit_sha": pr_record.get("commit_sha"),
                    "author": pr_record.get("author"),
                    "avatar_url": pr_record.get("author_avatar"),
                    "risk_level": ai_insight_json.get("risk_level", ai_insight_json.get("riskLevel", "low")).lower(),
                    "summary": ai_insight_json.get("summary"),
                    "recommendation": ai_insight_json.get("recommendation"),
                    "processed": False
                }
                
                result = await db_helpers.insert("insights", insight_record)
                logger.success(f"Generated and saved AI insight for PR #{pr_number} in repository {repo_id} (attempt {attempt + 1})")
                return True
            else:
                logger.warning(f"AI insight generation failed for PR #{pr_number} (attempt {attempt + 1})")
                if attempt < max_retries - 1:
                    await asyncio.sleep(2 ** attempt)  # Exponential backoff
                    
        except Exception as e:
            logger.error(f"AI insight generation attempt {attempt + 1} failed for PR #{pr_number}: {e}")
            if attempt < max_retries - 1:
                await asyncio.sleep(2 ** attempt)  # Exponential backoff
            else:
                logger.error(f"All {max_retries} attempts failed for PR #{pr_number}")
    
    return False


async def _reduce_file_data_for_retry(pr_record: dict, attempt: int) -> dict:
    """
    Progressively reduce file data size for retry attempts.
    """
    pr_record_copy = pr_record.copy()
    files_changed = pr_record_copy.get('files_changed', [])
    
    if not files_changed:
        return pr_record_copy
    
    logger.info(f"Reducing file data for retry attempt {attempt}")
    
    reduced_files = []
    for file_data in files_changed:
        reduced_file = file_data.copy()
        patch = reduced_file.get('patch', '')
        
        if attempt == 1:
            # First retry: Reduce patch size to 300 characters
            if len(patch) > 300:
                reduced_file['patch'] = patch[:300] + "... [truncated for retry]"
        elif attempt == 2:
            # Second retry: Remove patch data entirely, keep only metadata
            reduced_file['patch'] = f"[File modified: +{file_data.get('additions', 0)}/-{file_data.get('deletions', 0)} changes]"
        else:
            # Final retry: Keep only filename and basic stats
            reduced_file = {
                'filename': file_data.get('filename', 'unknown'),
                'status': file_data.get('status', 'modified'),
                'additions': file_data.get('additions', 0),
                'deletions': file_data.get('deletions', 0),
                'patch': '[Patch data removed for compatibility]'
            }
        
        reduced_files.append(reduced_file)
    
    pr_record_copy['files_changed'] = reduced_files
    logger.info(f"Reduced files_changed from original to {len(reduced_files)} files for attempt {attempt}")
    return pr_record_copy


async def _generate_fallback_insight(pr_record: dict):
    """
    Generate a basic insight when files_changed data is missing.
    Uses available PR metadata to create a minimal but useful insight.
    """
    try:
        repo_id = pr_record['repo_id']
        pr_number = pr_record['pr_number']
        
        logger.info(f"Generating fallback insight for PR #{pr_number} (no files_changed data)")
        
        # Create a fallback insight based on PR metadata
        title = pr_record.get('title', 'Pull Request')
        author = pr_record.get('author', 'Unknown')
        additions = pr_record.get('additions', 0)
        deletions = pr_record.get('deletions', 0)
        changed_files = pr_record.get('changed_files', 0)
        
        # Determine risk level based on change magnitude
        total_changes = additions + deletions
        if total_changes > 200 or changed_files > 10:
            risk_level = "high"
        elif total_changes > 50 or changed_files > 3:
            risk_level = "medium"
        else:
            risk_level = "low"
        
        # Generate summary and recommendation
        summary = f"Pull request modifies {changed_files} file(s) with {additions} additions and {deletions} deletions."
        recommendation = f"Review the {changed_files} modified files carefully. Pay attention to the scope of changes ({total_changes} total line changes)."
        
        if 'refactor' in title.lower():
            recommendation += " This appears to be a refactoring - verify functionality is preserved."
        elif 'feature' in title.lower():
            recommendation += " This appears to be a new feature - ensure proper testing and documentation."
        elif 'fix' in title.lower() or 'bug' in title.lower():
            recommendation += " This appears to be a bug fix - verify the fix addresses the root cause."
        
        # Store the fallback insight
        insight_record = {
            "repo_id": repo_id,
            "pr_number": pr_number,
            "commit_sha": pr_record.get("commit_sha"),
            "author": author,
            "avatar_url": pr_record.get("author_avatar"),
            "risk_level": risk_level,
            "summary": summary,
            "recommendation": recommendation,
            "processed": False
        }
        
        result = await db_helpers.insert("insights", insight_record)
        logger.success(f"Generated and saved fallback insight for PR #{pr_number} in repository {repo_id}")
        return True
        
    except Exception as e:
        logger.error(f"Failed to generate fallback insight for PR #{pr_number}", exception=e)
        return False


async def _schedule_insight_retry(pr_record: dict):
    """
    Schedule a PR for background retry of insight generation.
    """
    repo_id = pr_record['repo_id']
    pr_number = pr_record['pr_number']
    retry_key = f"{repo_id}:{pr_number}"
    
    # Track retry attempts
    if retry_key not in FAILED_INSIGHTS_RETRY:
        FAILED_INSIGHTS_RETRY[retry_key] = {
            'attempts': 0,
            'pr_record': pr_record,
            'last_attempt': datetime.now()
        }
    
    FAILED_INSIGHTS_RETRY[retry_key]['attempts'] += 1
    logger.info(f"Scheduled PR #{pr_number} for background insight retry (attempt {FAILED_INSIGHTS_RETRY[retry_key]['attempts']})")


async def process_failed_insight_retries():
    """
    Background task to retry failed insight generations.
    Should be called periodically by the poller.
    """
    if not FAILED_INSIGHTS_RETRY:
        return
    
    logger.info(f"Processing {len(FAILED_INSIGHTS_RETRY)} failed insight retries...")
    
    completed_retries = []
    
    for retry_key, retry_data in FAILED_INSIGHTS_RETRY.items():
        if retry_data['attempts'] >= 5:  # Max 5 attempts
            logger.warning(f"Giving up on insight generation for {retry_key} after 5 attempts")
            completed_retries.append(retry_key)
            continue
        
        # Wait at least 5 minutes between retries
        time_since_last = (datetime.now() - retry_data['last_attempt']).total_seconds()
        if time_since_last < 300:  # 5 minutes
            continue
        
        try:
            logger.info(f"Retrying insight generation for {retry_key}")
            pr_record = retry_data['pr_record']
            
            # Try fallback insight if multiple attempts failed
            if retry_data['attempts'] >= 3:
                success = await _generate_fallback_insight(pr_record)
            else:
                success = await _generate_ai_insight_for_pr_with_retry(pr_record, max_retries=1)
            
            if success:
                logger.success(f"Successfully generated insight for {retry_key} on retry attempt {retry_data['attempts']}")
                completed_retries.append(retry_key)
            else:
                retry_data['attempts'] += 1
                retry_data['last_attempt'] = datetime.now()
                
        except Exception as e:
            logger.error(f"Failed retry attempt for {retry_key}: {e}")
            retry_data['attempts'] += 1
            retry_data['last_attempt'] = datetime.now()
    
    # Clean up completed retries
    for retry_key in completed_retries:
        del FAILED_INSIGHTS_RETRY[retry_key]
        
    if completed_retries:
        logger.info(f"Completed {len(completed_retries)} insight retries")