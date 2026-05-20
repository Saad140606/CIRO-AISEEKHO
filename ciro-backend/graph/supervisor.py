"""
CIRO Supervisor — conditional routing logic for the LangGraph pipeline.

Inspects the current state and decides which agent node to run next,
or whether to end the graph.
"""

from langgraph.graph import END
from graph.state import CIROState


def supervisor_router(state: CIROState) -> str:
    """Return the name of the next node, or END."""

    # On error, stop immediately
    if state.get("status") == "error":
        return END

    # Agent 1 hasn't run yet
    if not state.get("normalized_signals"):
        return "signal_ingestor"

    # Agent 2 hasn't run yet
    if not state.get("situation_assessment"):
        return "situation_analyst"

    # Agent 3 hasn't run yet
    if not state.get("response_plan"):
        return "response_orchestrator"

    # All agents done
    return END
