# api_service/app/services/event_poller.py

import asyncio
from loguru import logger
from app.data.database import db_helpers
from app.services.event_processor import process_notification_by_type_and_id

_running = True

def stop_poller():
    global _running
    _running = False
    logger.info("Stop signal received for event poller.")


async def poll_for_events(is_fallback: bool = False):
    """
    Fallback poller for the new trigger-based system.
    Since we no longer have raw_events table, this poller checks for newly created
    records in the main tables that might have been missed by the listener.
    """
    sleep_interval = 60 if is_fallback else 30  # Longer intervals since this is now just a safety net
    log_prefix = "Fallback Poller" if is_fallback else "Event Poller"
    
    if not is_fallback:
        logger.warning(f"Event poller running in primary mode. This should only be used if LISTEN mode is disabled.")
    
    logger.info(f"Starting {log_prefix} for trigger-based system with {sleep_interval}s interval...")
    
    # Track the last processed timestamps for each table to detect new records
    last_pr_timestamp = None
    last_pipeline_timestamp = None
    last_insight_timestamp = None
    
    while _running:
        try:
            # Check for new pull requests
            new_prs = await db_helpers.select(
                "pull_requests",
                where={} if last_pr_timestamp is None else {},
                order_by="updated_at",
                desc=True,
                limit=5  # Only check recent records
            )
            
            if new_prs:
                newest_pr_timestamp = new_prs[0]['updated_at']
                if last_pr_timestamp is None:
                    last_pr_timestamp = newest_pr_timestamp
                    logger.info(f"[{log_prefix}] Initialized PR timestamp tracking")
                else:
                    # Process any PRs newer than our last timestamp
                    for pr in new_prs:
                        if pr['updated_at'] > last_pr_timestamp:
                            logger.info(f"[{log_prefix}] Found new/updated PR #{pr['pr_number']}")
                            try:
                                await process_notification_by_type_and_id('pr_event', pr['id'])
                            except Exception as e:
                                logger.error(f"[{log_prefix}] Failed to process PR {pr['id']}: {e}")
                    last_pr_timestamp = newest_pr_timestamp
            
            # Check for new pipeline runs
            new_pipelines = await db_helpers.select(
                "pipeline_runs",
                where={} if last_pipeline_timestamp is None else {},
                order_by="updated_at",
                desc=True,
                limit=5
            )
            
            if new_pipelines:
                newest_pipeline_timestamp = new_pipelines[0]['updated_at']
                if last_pipeline_timestamp is None:
                    last_pipeline_timestamp = newest_pipeline_timestamp
                    logger.info(f"[{log_prefix}] Initialized pipeline timestamp tracking")
                else:
                    for pipeline in new_pipelines:
                        if pipeline['updated_at'] > last_pipeline_timestamp:
                            logger.info(f"[{log_prefix}] Found new/updated pipeline for PR #{pipeline['pr_number']}")
                            try:
                                await process_notification_by_type_and_id('pipeline_event', pipeline['id'])
                            except Exception as e:
                                logger.error(f"[{log_prefix}] Failed to process pipeline {pipeline['id']}: {e}")
                    last_pipeline_timestamp = newest_pipeline_timestamp
            
            # Check for new insights
            new_insights = await db_helpers.select(
                "insights",
                where={} if last_insight_timestamp is None else {},
                order_by="created_at",
                desc=True,
                limit=5
            )
            
            if new_insights:
                newest_insight_timestamp = new_insights[0]['created_at']
                if last_insight_timestamp is None:
                    last_insight_timestamp = newest_insight_timestamp
                    logger.info(f"[{log_prefix}] Initialized insights timestamp tracking")
                else:
                    for insight in new_insights:
                        if insight['created_at'] > last_insight_timestamp:
                            logger.info(f"[{log_prefix}] Found new insight for PR #{insight['pr_number']}")
                            try:
                                await process_notification_by_type_and_id('insight_event', insight['id'])
                            except Exception as e:
                                logger.error(f"[{log_prefix}] Failed to process insight {insight['id']}: {e}")
                    last_insight_timestamp = newest_insight_timestamp
            
            # Sleep before next check
            await asyncio.sleep(sleep_interval)

        except asyncio.CancelledError:
            logger.warning(f"[{log_prefix}] task was cancelled.")
            break
        except Exception as e:
            logger.error(f"[{log_prefix}] An unexpected error occurred in the loop: {e}. Retrying in 10s.")
            await asyncio.sleep(10)
    
    logger.info(f"{log_prefix} has shut down.")