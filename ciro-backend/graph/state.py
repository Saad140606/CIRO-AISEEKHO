"""
CIRO LangGraph state definition.

This TypedDict is the single state object that flows through every
node in the multi-agent pipeline.
"""

from typing import TypedDict, Annotated
from langchain_core.messages import BaseMessage
import operator


class CIROState(TypedDict):
    incident_id: str
    raw_signals: dict
    normalized_signals: dict          # filled by Signal Ingestor (Agent 1)
    situation_assessment: dict        # filled by Situation Analyst (Agent 2)
    response_plan: dict               # filled by Response Orchestrator (Agent 3)
    messages: Annotated[list[BaseMessage], operator.add]
    agent_trace: Annotated[list[dict], operator.add]
    status: str
    error: str | None
