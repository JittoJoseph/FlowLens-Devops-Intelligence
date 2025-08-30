from fastapi import APIRouter, Depends, HTTPException, status
from loguru import logger

router = APIRouter(prefix="/api", tags=["API"])

@router.post("/prs")
async def get_all_prs():
    pass