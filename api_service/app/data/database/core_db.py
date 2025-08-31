# api_service/app/data/database/core_db.py

import asyncio
from typing import Optional
from loguru import logger

import asyncpg
from app.data.configs.app_settings import settings

# --- Configuration ---
POOL_MIN_SIZE = settings.POOL_MIN_SIZE
POOL_MAX_SIZE = settings.POOL_MAX_SIZE
POOL_ACQUIRE_TIMEOUT = settings.POOL_ACQUIRE_TIMEOUT

# --- Database State ---
pool: Optional[asyncpg.Pool] = None
listener_connection: Optional[asyncpg.Connection] = None # <-- NEW: For our dedicated listener
_pool_lock = asyncio.Lock()

async def get_pool() -> asyncpg.Pool:
    """Returns the connection pool for handling API requests."""
    global pool
    if pool:
        return pool
    
    async with _pool_lock:
        if pool is None:
            logger.info("Creating database connection pool...")
            try:
                pool = await asyncpg.create_pool(
                    dsn=settings.DATABASE_URL,
                    min_size=POOL_MIN_SIZE,
                    max_size=POOL_MAX_SIZE,
                    timeout=POOL_ACQUIRE_TIMEOUT,
                )
                logger.success("Database connection pool created successfully.")
            except Exception as e:
                logger.critical("Could not create database pool", error=str(e))
                raise
    return pool

# --- NEW FUNCTION FOR THE LISTENER ---
async def create_dedicated_connection() -> asyncpg.Connection:
    """Creates a single, dedicated connection for long-lived tasks like LISTEN."""
    global listener_connection
    if listener_connection and not listener_connection.is_closed():
        return listener_connection
    
    logger.info("Creating dedicated database connection for listener...")
    try:
        listener_connection = await asyncpg.connect(dsn=settings.DATABASE_URL)
        logger.success("Dedicated listener connection created successfully.")
        return listener_connection
    except Exception as e:
        logger.critical("Could not create dedicated listener connection", error=str(e))
        raise

async def connect():
    """Initializes the main pool on startup."""
    await get_pool()

async def disconnect():
    """Closes all connections on shutdown."""
    global pool, listener_connection
    if pool:
        logger.info("Closing database connection pool...")
        await pool.close()
        pool = None
        logger.success("Database connection pool closed.")
    if listener_connection and not listener_connection.is_closed():
        logger.info("Closing dedicated listener connection...")
        await listener_connection.close()
        listener_connection = None
        logger.success("Dedicated listener connection closed.")