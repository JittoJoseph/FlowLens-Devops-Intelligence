# app/data/models/schemas.py

from pydantic import BaseModel
from typing import List, Optional, Any
from datetime import datetime
from uuid import UUID

# A base model for common fields
class Base(BaseModel):
    id: UUID
    created_at: datetime
    updated_at: datetime

class HistoryItem(BaseModel):
    at: datetime
    meta: Optional[dict[str, Any]] = None
    state: Optional[str] = None
    field: Optional[str] = None
    value: Optional[str] = None

class Insight(Base):
    repo_id: UUID
    pr_number: int
    commit_sha: Optional[str] = None
    author: Optional[str] = None
    avatar_url: Optional[str] = None
    risk_level: Optional[str] = None
    summary: Optional[str] = None
    recommendation: Optional[str] = None

class PipelineRun(Base):
    repo_id: UUID
    pr_number: int
    commit_sha: Optional[str] = None
    author: Optional[str] = None
    avatar_url: Optional[str] = None
    title: Optional[str] = None
    status_pr: str = 'pending'
    status_build: str = 'pending'
    status_approval: str = 'pending'
    status_merge: str = 'pending'
    history: List[HistoryItem] = []

class PullRequest(Base):
    repo_id: UUID
    pr_number: int
    title: str
    description: Optional[str] = None
    author: str
    author_avatar: Optional[str] = None
    commit_sha: str
    branch_name: Optional[str] = None
    base_branch: Optional[str] = None
    pr_url: Optional[str] = None
    additions: int = 0
    deletions: int = 0
    changed_files: int = 0
    state: str = 'open'
    history: List[HistoryItem] = []
    files_changed: Optional[List[dict[str, Any]]] = [] # For AI analysis

class Repository(Base):
    github_id: int
    name: str
    full_name: str
    description: Optional[str] = None
    owner: str
    html_url: Optional[str] = None
    language: Optional[str] = None
    stars: int = 0
    forks: int = 0
    open_prs: int = 0
    total_prs: int = 0

# --- Composite Model for Rich API/WebSocket Payloads ---
# This is what the frontend really wants: a single object with everything.
class FullPullRequestDetails(BaseModel):
    pull_request: PullRequest
    pipeline: Optional[PipelineRun] = None
    insights: List[Insight] = []