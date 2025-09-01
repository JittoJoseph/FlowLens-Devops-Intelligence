"""
Database helper functions for interacting with the `databases` library.
This module provides a simplified, consistent API for common database operations,
with integrated logging and robust error handling.
"""

from typing import Any, Dict, List, Optional
import asyncpg
from loguru import logger
from app.data.database.core_db import get_db

# --- Custom Exception ---

class DatabaseError(Exception):
    """Custom exception for database operation failures."""
    pass


# --- Helper Functions ---

def quote_identifier(name: str) -> str:
    """Ensures identifiers (table or column names) are properly quoted."""
    return f'"{name}"'

async def select(
    table: str,
    where: Optional[Dict[str, Any]] = None,
    select_fields: str = "*",
    order_by: Optional[str] = None,
    desc: bool = False,
    limit: Optional[int] = None,
) -> List[Dict[str, Any]]:
    """
    Returns a list of rows (as dicts) with logging and error handling.
    """
    db = get_db()
    table_quoted = quote_identifier(table)
    
    query_parts = [f"SELECT {select_fields} FROM {table_quoted}"]
    values = {}

    if where:
        conditions = []
        for key, val in where.items():
            conditions.append(f'{quote_identifier(key)} = :{key}')
            values[key] = val
        query_parts.append("WHERE " + " AND ".join(conditions))

    if order_by:
        query_parts.append(f"ORDER BY {quote_identifier(order_by)} {'DESC' if desc else 'ASC'}")
    
    if limit is not None:
        query_parts.append(f"LIMIT :limit")
        values["limit"] = limit
    
    query = " ".join(query_parts)
    logger.debug(f"Executing SELECT: {query} with values: {values}")

    try:
        rows = await db.fetch_all(query, values)
        return [dict(row) for row in rows]
    except asyncpg.PostgresError as e:
        logger.error(f"Database SELECT failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to select from {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during SELECT on table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while selecting from {table}: {e}") from e


async def select_one(
    table: str,
    where: Optional[Dict[str, Any]] = None,
    select_fields: str = "*"
) -> Optional[Dict[str, Any]]:
    """Returns a single row (as a dict) or None, with logging and error handling."""
    db = get_db()
    table_quoted = quote_identifier(table)

    query_parts = [f"SELECT {select_fields} FROM {table_quoted}"]
    values = {}

    if where:
        conditions = []
        for key, val in where.items():
            conditions.append(f'{quote_identifier(key)} = :{key}')
            values[key] = val
        query_parts.append("WHERE " + " AND ".join(conditions))
    
    query_parts.append("LIMIT 1")
    query = " ".join(query_parts)
    logger.debug(f"Executing SELECT_ONE: {query} with values: {values}")

    try:
        row = await db.fetch_one(query, values)
        return dict(row) if row else None
    except asyncpg.PostgresError as e:
        logger.error(f"Database SELECT_ONE failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to select one from {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during SELECT_ONE on table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while selecting one from {table}: {e}") from e


async def insert(table: str, data: Dict[str, Any]) -> Dict[str, Any]:
    """Inserts a single row with logging and error handling, returning the inserted row."""
    db = get_db()
    table_quoted = quote_identifier(table)

    columns = ", ".join(quote_identifier(k) for k in data.keys())
    placeholders = ", ".join(f":{k}" for k in data.keys())
    
    query = f"INSERT INTO {table_quoted} ({columns}) VALUES ({placeholders}) RETURNING *"
    logger.debug(f"Executing INSERT: {query} with values: {data}")

    try:
        result = await db.fetch_one(query, data)
        return dict(result)
    except asyncpg.PostgresError as e:
        logger.error(f"Database INSERT failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to insert into {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during INSERT on table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while inserting into {table}: {e}") from e


async def update(table: str, data: Dict[str, Any], where: Dict[str, Any]):
    """Updates rows with logging and error handling."""
    db = get_db()
    table_quoted = quote_identifier(table)

    set_clauses = [f'{quote_identifier(key)} = :d_{key}' for key in data.keys()]
    where_clauses = [f'{quote_identifier(key)} = :w_{key}' for key in where.keys()]
    
    values = {f"d_{k}": v for k, v in data.items()}
    values.update({f"w_{k}": v for k, v in where.items()})

    query = f"UPDATE {table_quoted} SET {', '.join(set_clauses)} WHERE {' AND '.join(where_clauses)}"
    logger.debug(f"Executing UPDATE: {query} with values: {values}")

    try:
        await db.execute(query, values)
    except asyncpg.PostgresError as e:
        logger.error(f"Database UPDATE failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to update {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during UPDATE on table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while updating {table}: {e}") from e


async def upsert(table: str, data: Dict[str, Any], conflict_keys: List[str]):
    """Performs an UPSERT with logging and error handling."""
    db = get_db()
    table_quoted = quote_identifier(table)

    columns = ", ".join(quote_identifier(k) for k in data.keys())
    placeholders = ", ".join(f":{k}" for k in data.keys())

    update_columns = [col for col in data.keys() if col not in conflict_keys]
    update_clause = ", ".join(f'{quote_identifier(col)} = EXCLUDED.{quote_identifier(col)}' for col in update_columns)
    conflict_clause = ", ".join(quote_identifier(k) for k in conflict_keys)

    query = (
        f"INSERT INTO {table_quoted} ({columns}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_clause}) DO UPDATE SET {update_clause}"
    )
    logger.debug(f"Executing UPSERT: {query} with values: {data}")

    try:
        await db.execute(query, data)
    except asyncpg.PostgresError as e:
        logger.error(f"Database UPSERT failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to upsert into {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during UPSERT on table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while upserting into {table}: {e}") from e


async def batch_upsert(table: str, data_list: List[Dict[str, Any]], conflict_keys: List[str]):
    """Performs a batch UPSERT with logging and error handling."""
    if not data_list:
        return

    db = get_db()
    table_quoted = quote_identifier(table)
    columns = list(data_list[0].keys())
    
    fields_clause = ", ".join(quote_identifier(k) for k in columns)
    
    update_columns = [col for col in columns if col not in conflict_keys]
    update_clause = ", ".join(f'{quote_identifier(col)} = EXCLUDED.{quote_identifier(col)}' for col in update_columns)
    conflict_clause = ", ".join(quote_identifier(k) for k in conflict_keys)

    # Note: The query string for executemany with 'databases' and asyncpg
    # should use the native asyncpg parameter style ($1, $2, etc.).
    # We construct the query string once.
    placeholders = ", ".join(f"${i+1}" for i, _ in enumerate(columns))
    query = (
        f"INSERT INTO {table_quoted} ({fields_clause}) VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_clause}) DO UPDATE SET {update_clause}"
    )
    
    # For executemany, we need a list of lists, where the order of values
    # in the inner list matches the order of columns in the query.
    values_to_execute = [[item.get(col) for col in columns] for item in data_list]
    logger.debug(f"Executing BATCH_UPSERT on table '{table}' with {len(values_to_execute)} records.")

    try:
        # Use a transaction for batch operations to ensure atomicity
        async with db.transaction():
            await db.execute_many(query=query, values=values_to_execute)
    except asyncpg.PostgresError as e:
        logger.error(f"Database BATCH_UPSERT failed for table '{table}'. Error: {e}")
        raise DatabaseError(f"Failed to batch upsert into {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during BATCH_UPSERT on table '{table}'. Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while batch upserting into {table}: {e}") from e


async def delete(table: str, where: Dict[str, Any]):
    """Deletes rows with logging and error handling."""
    db = get_db()
    table_quoted = quote_identifier(table)

    conditions = []
    values = {}
    for key, val in where.items():
        conditions.append(f'{quote_identifier(key)} = :{key}')
        values[key] = val

    query = f"DELETE FROM {table_quoted} WHERE {' AND '.join(conditions)}"
    logger.debug(f"Executing DELETE: {query} with values: {values}")

    try:
        await db.execute(query, values)
    except asyncpg.PostgresError as e:
        logger.error(f"Database DELETE failed for table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"Failed to delete from {table}: {e}") from e
    except Exception as e:
        logger.error(f"An unexpected error occurred during DELETE on table '{table}'. Query: {query}, Error: {e}")
        raise DatabaseError(f"An unexpected error occurred while deleting from {table}: {e}") from e