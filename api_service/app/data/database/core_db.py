# api_service/app/data/database/core_db.py

from typing import Optional
import ssl
from loguru import logger
from databases import Database
from app.data.configs.app_settings import settings

database: Optional[Database] = None


def _create_ssl_context():
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE
    return ssl_context


def get_db() -> Database:
    global database
    if database is None:
        ssl_context = _create_ssl_context()
        database = Database(
            settings.DATABASE_URL,
            min_size=settings.POOL_MIN_SIZE,
            max_size=settings.POOL_MAX_SIZE,
            ssl=ssl_context,
            force_rollback=False,  # FIXED: Allow transactions to commit
            server_settings={'application_name': 'flowlens-api-service'}
        )
    return database


async def connect():
    db = get_db()
    if not db.is_connected:
        logger.info("Connecting main database pool...")
        try:
            await db.connect()
            logger.success("Main database pool connected.")
        except Exception as e:
            logger.critical(f"Could not connect main database pool: {str(e)}")
            raise


async def disconnect():
    db = get_db()
    if db.is_connected:
        logger.info("Closing main database pool...")
        await db.disconnect()
        logger.success("Main database pool closed.")