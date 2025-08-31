# api_service/app/data/database/core_db.py

import asyncio
from typing import Optional
from loguru import logger
import asyncpg
import ssl
from app.data.configs.app_settings import settings

# --- Configuration ---
POOL_MIN_SIZE = settings.POOL_MIN_SIZE
POOL_MAX_SIZE = settings.POOL_MAX_SIZE
POOL_ACQUIRE_TIMEOUT = settings.POOL_ACQUIRE_TIMEOUT

# --- Database State ---
pool: Optional[asyncpg.Pool] = None
_pool_lock = asyncio.Lock()

async def _set_query_timeout(connection):
    """Set a timeout for each query on a connection."""
    await connection.set_type_codec(
        'json',
        encoder=lambda d: d,
        decoder=lambda d: d,
        schema='pg_catalog'
    )
    # Set a 30-second timeout for every query
    await connection.execute("SET statement_timeout TO '30s'")

async def get_pool() -> asyncpg.Pool:
    """Returns the connection pool for handling API requests."""
    global pool
    if pool:
        return pool
    
    async with _pool_lock:
        if pool is None:
            logger.info("Creating database connection pool...")
            try:
                # Create a custom SSL context that doesn't verify the certificate
                ssl_context = ssl.create_default_context()
                ssl_context.check_hostname = False
                ssl_context.verify_mode = ssl.CERT_NONE

                pool = await asyncpg.create_pool(
                    dsn=settings.DATABASE_URL,
                    min_size=POOL_MIN_SIZE,
                    max_size=POOL_MAX_SIZE,
                    timeout=POOL_ACQUIRE_TIMEOUT,
                    ssl=ssl_context,
                    setup=_set_query_timeout,
                )
                logger.success("Database connection pool created successfully.")
            except Exception as e:
                logger.critical("Could not create database pool", error=str(e))
                raise
    return pool

async def connect():
    """Initializes the main pool on startup."""
    await get_pool()

async def disconnect():
    """Closes all connections in the pool on shutdown."""
    global pool
    if pool:
        logger.info("Closing database connection pool...")
        await pool.close()
        pool = None
        logger.success("Database connection pool closed.")