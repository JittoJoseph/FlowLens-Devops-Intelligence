# api_service/app/data/database/core_db.py

from typing import Optional
import ssl
from loguru import logger
from databases import Database
from app.data.configs.app_settings import settings

database: Optional[Database] = None
listener_db: Optional[Database] = None


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
            force_rollback=True,
            server_settings={'application_name': 'flowlens-api-service'}
        )
    return database


def get_listener_db() -> Database:
    global listener_db
    if listener_db is None:
        ssl_context = _create_ssl_context()
        listener_db = Database(
            settings.LISTENER_DATABASE_URL,
            min_size=1,
            max_size=1,
            ssl=ssl_context,
            force_rollback=True,
            server_settings={'application_name': 'flowlens-api-listener'}
        )
    return listener_db


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

    ldb = get_listener_db()
    if not ldb.is_connected:
        logger.info("Connecting dedicated DB listener...")
        try:
            await ldb.connect()
            logger.success("Dedicated DB listener connected.")
        except Exception as e:
            logger.critical(f"Could not connect dedicated DB listener: {str(e)}")
            raise


async def disconnect():
    db = get_db()
    if db.is_connected:
        logger.info("Closing main database pool...")
        await db.disconnect()
        logger.success("Main database pool closed.")
    
    ldb = get_listener_db()
    if ldb.is_connected:
        logger.info("Closing dedicated DB listener connection...")
        await ldb.disconnect()
        logger.success("Dedicated DB listener connection closed.")