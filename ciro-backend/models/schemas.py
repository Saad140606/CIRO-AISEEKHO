"""
CIRO Pydantic v2 models for request/response validation.
"""

from typing import Literal
from pydantic import BaseModel, Field


class AnalyzeRequest(BaseModel):
    """Request body for the /api/analyze endpoint."""
    social_posts: list[str] = Field(default_factory=list)
    weather_override: dict | None = None
    traffic_override: dict | None = None
    manual_reports: list[str] = Field(default_factory=list)


class ScenarioRequest(BaseModel):
    """Request body for the /api/simulate/scenario endpoint."""
    scenario: Literal[
        "flooding_g10",
        "heatwave_karachi",
        "accident_mm_alam",
        "infra_failure_saddar",
    ]


class IncidentSummary(BaseModel):
    """Summary view of an incident for list endpoints."""
    incident_id: str
    crisis_type: str
    severity: str
    confidence: str
    affected_area: str
    status: str
    created_at: str


class IncidentDetail(IncidentSummary):
    """Full detail view of an incident including all agent outputs."""
    normalized_signals: dict = Field(default_factory=dict)
    situation_assessment: dict = Field(default_factory=dict)
    response_plan: dict = Field(default_factory=dict)
    agent_trace: list[dict] = Field(default_factory=list)


class AnalyzeResponse(BaseModel):
    """Response returned immediately when a pipeline is launched."""
    incident_id: str
    status: str = "processing"
