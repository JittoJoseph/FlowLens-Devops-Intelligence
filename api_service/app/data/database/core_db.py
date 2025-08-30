import asyncio
from typing import Optional
from loguru import logger

import asyncpg
from app.data.configs.app_settings import settings

# --- Configuration ---
# These settings control the connection pool from your app to the PgBouncer.
# This pool size is per-process (i.e., per FastAPI worker).
POOL_MIN_SIZE = settings.POOL_MIN_SIZE          # Keep a couple of connections warm to the pooler for low latency.
POOL_MAX_SIZE = settings.POOL_MAX_SIZE         # Max concurrent DB queries from this worker. A safe start for 2vCPU.
POOL_ACQUIRE_TIMEOUT = settings.POOL_ACQUIRE_TIMEOUT # How long a request will wait for a connection from this pool.

# --- Database State ---
pool: Optional[asyncpg.Pool] = None
_pool_lock = asyncio.Lock()

async def get_pool() -> asyncpg.Pool:
    """
    Returns the connection pool, creating it if it doesn't exist.
    This is the primary function to be used by DB helper functions.
    It's safe to call this concurrently from multiple coroutines.
    """
    global pool
    # Fast path: if the pool is already created, return it immediately.
    if pool:
        return pool
    
    # If the pool needs to be created, acquire a lock to prevent multiple
    # coroutines from creating it at the same time.
    async with _pool_lock:
        # Double-check that the pool wasn't created by another coroutine
        # while we were waiting for the lock.
        if pool is None:
            logger.info("Creating database connection pool...")
            try:
                # This creates a pool of persistent connections to your NeonDB pooler.
                # It is highly efficient and avoids the overhead of reconnecting.
                pool = await asyncpg.create_pool(
                    dsn=settings.DATABASE_URL,
                    min_size=POOL_MIN_SIZE,
                    max_size=POOL_MAX_SIZE,
                    timeout=POOL_ACQUIRE_TIMEOUT,
                )
                logger.success("Database connection pool created successfully.")
            except Exception as e:
                logger.critical("Could not create database pool", error=str(e))
                # This is a critical failure; the application cannot run without a database.
                raise
    return pool

async def connect():
    """Call from FastAPI startup to eagerly initialize the database pool."""
    await get_pool()

async def disconnect():
    """Call from FastAPI shutdown to gracefully close all connections in the pool."""
    global pool
    if pool:
        logger.info("Closing database connection pool...")
        await pool.close()
        pool = None
        logger.success("Database connection pool closed.")
