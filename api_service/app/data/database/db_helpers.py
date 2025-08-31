"""
Database helper functions for interacting with the asyncpg connection pool.
This module provides a simplified, consistent API for common database operations,
with integrated logging and robust error handling.
"""

from typing import Any, Dict, List, Optional
import asyncpg
from loguru import logger
from app.data.database.core_db import get_pool

# --- Custom Exception ---

class DatabaseError(Exception):
    """Custom exception for database operation failures."""
    pass


# --- Helper Functions ---

def quote_table(name: str) -> str:
    """Ensures table names with special characters or hyphens are quoted."""
    return f'"{name}"'

async def select(
    table: str,
    where: Optional[Dict[str, Any]] = None,
    select_fields: str = "*",
    order_by: Optional[str] = None,
    desc: bool = False,
    limit: Optional[int] = None,
    retry_on_connection_error: bool = True
) -> List[Dict[str, Any]]:
    """
    Returns a list of rows (as dicts) with logging and error handling.
    Includes a retry mechanism for connection errors.
    """
    pool = await get_pool()
    table_quoted = quote_table(table)
    
    query_parts = [f"SELECT {select_fields} FROM {table_quoted}"]
    values = []

    if where:
        conditions = []
        for i, (key, val) in enumerate(where.items(), 1):
            conditions.append(f'"{key}" = ${i}') # Quote column names for safety
            values.append(val)
        query_parts.append("WHERE " + " AND ".join(conditions))

    if order_by:
        query_parts.append(f"ORDER BY \"{order_by}\" {'DESC' if desc else 'ASC'}")
    
    if limit is not None:
        query_parts.append(f"LIMIT {limit}")
    
    query = " ".join(query_parts)
    logger.debug(f"Executing SELECT: {query} with values: {values}")

    try:
        async with pool.acquire() as connection:
            rows: List[asyncpg.Record] = await connection.fetch(query, *values)
        return [dict(row) for row in rows]
    except asyncpg.PostgresError as e:
        # Specific check for connection errors
        if "connection is closed" in str(e) or "connection was closed" in str(e):
            if retry_on_connection_error:
                logger.warning(f"Connection error for table '{table}', retrying once. Error: {e}")
                # Retry the operation once
                return await select(table, where, select_fields, order_by, desc, limit, retry_on_connection_error=False)
        
        logger.error(f"Database SELECT failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to select from {table}: {e}") from e


async def select_one(
    table: str,
    where: Optional[Dict[str, Any]] = None,
    select_fields: str = "*"
) -> Optional[Dict[str, Any]]:
    """Returns a single row (as a dict) or None, with logging and error handling."""
    pool = await get_pool()
    table_quoted = quote_table(table)

    query_parts = [f"SELECT {select_fields} FROM {table_quoted}"]
    values = []

    if where:
        conditions = []
        for i, (key, val) in enumerate(where.items(), 1):
            conditions.append(f'"{key}" = ${i}')
            values.append(val)
        query_parts.append("WHERE " + " AND ".join(conditions))
    
    query_parts.append("LIMIT 1")
    query = " ".join(query_parts)
    logger.debug(f"Executing SELECT_ONE: {query} with values: {values}")

    try:
        async with pool.acquire() as connection:
            row: Optional[asyncpg.Record] = await connection.fetchrow(query, *values)
        return dict(row) if row else None
    except asyncpg.PostgresError as e:
        logger.error(f"Database SELECT_ONE failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to select one from {table}: {e}") from e


async def insert(table: str, data: Dict[str, Any]):
    """Inserts a single row with logging and error handling."""
    pool = await get_pool()
    table_quoted = quote_table(table)

    columns = ", ".join(f'"{k}"' for k in data.keys())
    placeholders = ", ".join(f"${i}" for i in range(1, len(data) + 1))
    values = list(data.values())
    
    query = f"INSERT INTO {table_quoted} ({columns}) VALUES ({placeholders})"
    logger.debug(f"Executing INSERT: {query} with values: {values}")

    try:
        async with pool.acquire() as connection:
            await connection.execute(query, *values)
    except asyncpg.PostgresError as e:
        logger.error(f"Database INSERT failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to insert into {table}: {e}") from e


async def update(table: str, data: Dict[str, Any], where: Dict[str, Any]):
    """Updates rows with logging and error handling."""
    pool = await get_pool()
    table_quoted = quote_table(table)

    set_clauses = [f'"{key}" = ${i+1}' for i, key in enumerate(data.keys())]
    start_idx = len(data) + 1
    where_clauses = [f'"{key}" = ${i+start_idx}' for i, key in enumerate(where.keys())]
    
    query = f"UPDATE {table_quoted} SET {', '.join(set_clauses)} WHERE {' AND '.join(where_clauses)}"
    values = list(data.values()) + list(where.values())
    logger.debug(f"Executing UPDATE: {query} with values: {values}")

    try:
        async with pool.acquire() as connection:
            await connection.execute(query, *values)
    except asyncpg.PostgresError as e:
        logger.error(f"Database UPDATE failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to update {table}: {e}") from e


async def upsert(table: str, data: Dict[str, Any], conflict_keys: List[str]):
    """Performs an UPSERT with logging and error handling."""
    pool = await get_pool()
    table_quoted = quote_table(table)

    columns = ", ".join(f'"{k}"' for k in data.keys())
    placeholders = ", ".join(f"${i}" for i in range(1, len(data) + 1))
    values = list(data.values())

    update_columns = [col for col in data.keys() if col not in conflict_keys]
    update_clause = ", ".join(f'"{col}" = EXCLUDED."{col}"' for col in update_columns)
    conflict_clause = ", ".join(f'"{k}"' for k in conflict_keys)

    query = (
        f"INSERT INTO {table_quoted} ({columns}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_clause}) DO UPDATE SET {update_clause}"
    )
    logger.debug(f"Executing UPSERT: {query} with values: {values}")

    try:
        async with pool.acquire() as connection:
            await connection.execute(query, *values)
    except asyncpg.PostgresError as e:
        logger.error(f"Database UPSERT failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to upsert into {table}: {e}") from e


async def batch_upsert(table: str, data_list: List[Dict[str, Any]], conflict_keys: List[str]):
    """Performs a batch UPSERT with logging and error handling."""
    if not data_list:
        return

    pool = await get_pool()
    table_quoted = quote_table(table)
    columns = list(data_list[0].keys())
    
    fields_clause = ", ".join(f'"{k}"' for k in columns)
    placeholders = ", ".join(f"${i}" for i in range(1, len(columns) + 1))
    
    update_columns = [col for col in columns if col not in conflict_keys]
    update_clause = ", ".join(f'"{col}" = EXCLUDED."{col}"' for col in update_columns)
    conflict_clause = ", ".join(f'"{k}"' for k in conflict_keys)

    query = (
        f"INSERT INTO {table_quoted} ({fields_clause}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_clause}) DO UPDATE SET {update_clause}"
    )
    
    values_to_execute = [[item.get(col) for col in columns] for item in data_list]
    logger.debug(f"Executing BATCH_UPSERT on table '{table}' with {len(values_to_execute)} records.")

    try:
        async with pool.acquire() as connection:
            await connection.executemany(query, values_to_execute)
    except asyncpg.PostgresError as e:
        logger.error(f"Database BATCH_UPSERT failed for table '{table}'. Error: {e}")
        raise DatabaseError(f"Failed to batch upsert into {table}: {e}") from e


async def delete(table: str, where: Dict[str, Any]):
    """Deletes rows with logging and error handling."""
    pool = await get_pool()
    table_quoted = quote_table(table)

    conditions = []
    values = []
    for i, (key, val) in enumerate(where.items(), 1):
        conditions.append(f'"{key}" = ${i}')
        values.append(val)

    query = f"DELETE FROM {table_quoted} WHERE {' AND '.join(conditions)}"
    logger.debug(f"Executing DELETE: {query} with values: {values}")

    try:
        async with pool.acquire() as connection:
            await connection.execute(query, *values)
    except asyncpg.PostgresError as e:
        logger.error(f"Database DELETE failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to delete from {table}: {e}") from e