# api_service/app/services/event_poller.py

import asyncio
from loguru import logger
from app.data.database import db_helpers
from app.services.event_processor import process_new_pull_request, process_new_pipeline, process_new_insight, process_failed_insight_retries

_running = True

def stop_poller():
    global _running
    _running = False
    logger.info("Stop signal received for event poller.")


async def poll_for_events():
    """
    Polls the database every 2 seconds for new or updated records.
    Uses 'processed' column to track which records have been handled.
    Also processes failed insight retries periodically.
    """
    POLL_INTERVAL = 2  # 2 seconds as requested
    retry_counter = 0  # Counter for retry processing
    
    logger.info(f"Starting database poller with {POLL_INTERVAL}s interval...")
    
    while _running:
        try:
            # Check for unprocessed pull requests (including updates)
            new_prs = await db_helpers.select(
                "pull_requests",
                where={"processed": False},
                order_by="updated_at",
                desc=True,
                limit=10  # Process up to 10 at a time
            )
            
            if new_prs:
                logger.info(f"Found {len(new_prs)} unprocessed pull requests (new or updated)")
                for pr in new_prs:
                    try:
                        await process_new_pull_request(pr)
                        # Mark as processed
                        await db_helpers.update(
                            "pull_requests",
                            where={"id": pr['id']},
                            data={"processed": True}
                        )
                        logger.success(f"Processed PR #{pr['pr_number']} from repository {pr['repo_id']}")
                    except Exception as e:
                        logger.error(f"Failed to process PR {pr['id']}: {e}")
            
            # Check for unprocessed pipeline runs (including updates)
            new_pipelines = await db_helpers.select(
                "pipeline_runs",
                where={"processed": False},
                order_by="updated_at",
                desc=True,
                limit=10
            )
            
            if new_pipelines:
                logger.info(f"Found {len(new_pipelines)} unprocessed pipeline runs (new or updated)")
                for pipeline in new_pipelines:
                    try:
                        await process_new_pipeline(pipeline)
                        # Mark as processed
                        await db_helpers.update(
                            "pipeline_runs",
                            where={"id": pipeline['id']},
                            data={"processed": True}
                        )
                        logger.success(f"Processed pipeline for PR #{pipeline['pr_number']} from repository {pipeline['repo_id']}")
                    except Exception as e:
                        logger.error(f"Failed to process pipeline {pipeline['id']}: {e}")
            
            # Check for unprocessed insights
            new_insights = await db_helpers.select(
                "insights",
                where={"processed": False},
                order_by="created_at",
                desc=True,
                limit=10
            )
            
            if new_insights:
                logger.info(f"Found {len(new_insights)} unprocessed insights")
                for insight in new_insights:
                    try:
                        await process_new_insight(insight)
                        # Mark as processed
                        await db_helpers.update(
                            "insights",
                            where={"id": insight['id']},
                            data={"processed": True}
                        )
                        logger.success(f"Processed insight for PR #{insight['pr_number']} from repository {insight['repo_id']}")
                    except Exception as e:
                        logger.error(f"Failed to process insight {insight['id']}: {e}")
            
            # Process failed insight retries every 30 poll cycles (60 seconds)
            retry_counter += 1
            if retry_counter >= 30:
                retry_counter = 0
                try:
                    await process_failed_insight_retries()
                except Exception as e:
                    logger.error(f"Failed to process insight retries: {e}")
            
            # Sleep before next poll
            await asyncio.sleep(POLL_INTERVAL)

        except asyncio.CancelledError:
            logger.warning("Event poller task was cancelled.")
            break
        except Exception as e:
            logger.error(f"Event poller encountered an error: {e}. Retrying in 5s.")
            await asyncio.sleep(5)
    
    logger.info("Database event poller has shut down.")