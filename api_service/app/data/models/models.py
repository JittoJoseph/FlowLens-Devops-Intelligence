# app/data/models/models.py

from pydantic import BaseModel, Field
from typing import List, Optional, Any, Dict
from datetime import datetime
import uuid

# --- NEW: Model for a single file change ---
class FileChange(BaseModel):
    patch: Optional[str] = ""
    status: str
    changes: int
    filename: str
    additions: int
    deletions: int

# --- NEW: Comprehensive model for Pull Request details ---
class PullRequestDetails(BaseModel):
    pr_number: int
    title: Optional[str] = None
    description: Optional[str] = None
    author: str
    author_avatar: str
    commit_sha: str
    repository_name: str
    branch_name: str
    base_branch: str
    pr_url: str
    additions: int
    deletions: int
    changed_files: int
    is_draft: bool
    state: str
    created_at: datetime
    updated_at: datetime
    # This is the key field that was missing
    files_changed: List[FileChange] = Field(default_factory=list)

# --- Model for a single Insight ---
class Insight(BaseModel):
    id: uuid.UUID
    pr_number: int
    commit_sha: str
    insight_type: str
    data: Dict[str, Any]
    generated_at: datetime

# --- Model for Pipeline Run status ---
class PipelineRun(BaseModel):
    pr_number: int
    commit_sha: str
    status_pr: str
    status_build: str
    status_approval: str
    status_merge: str
    updated_at: datetime

# --- THE NEW DTO: The single source of truth for the frontend ---
class PRDashboardState(BaseModel):
    """A comprehensive model representing the full state of a PR for the dashboard."""
    details: PullRequestDetails
    pipeline: PipelineRun
    insight: Optional[Insight] = None