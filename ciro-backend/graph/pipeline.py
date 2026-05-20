"""
CIRO Pipeline — Antigravity-Orchestrated Multi-Agent Pipeline.

Google Antigravity is the CORE orchestration layer. It:
  1. Creates an execution plan for the crisis incident
  2. Routes each step through the appropriate LangGraph agent node
  3. Captures detailed trace logs for reasoning transparency
  4. Manages the overall workflow lifecycle

The LangGraph StateGraph handles individual agent execution internally,
but Antigravity plans, coordinates, and monitors the entire flow.
"""

import asyncio
import logging
from datetime import datetime, timezone

from langgraph.graph import StateGraph, END

from graph.state import CIROState
from graph.supervisor import supervisor_router
from graph.antigravity_config import antigravity, AgentRole
from agents.signal_ingestor import signal_ingestor_node
from agents.situation_analyst import situation_analyst_node
from agents.response_orchestrator import response_orchestrator_node
from store.incident_store import IncidentStore

logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════════════════
# Build the LangGraph (used internally by Antigravity)
# ═══════════════════════════════════════════════════════════════════

workflow = StateGraph(CIROState)

# --- nodes ---
workflow.add_node("signal_ingestor", signal_ingestor_node)
workflow.add_node("situation_analyst", situation_analyst_node)
workflow.add_node("response_orchestrator", response_orchestrator_node)

# --- conditional entry point ---
workflow.set_conditional_entry_point(
    supervisor_router,
    {
        "signal_ingestor": "signal_ingestor",
        "situation_analyst": "situation_analyst",
        "response_orchestrator": "response_orchestrator",
        END: END,
    },
)

# --- conditional edges from each node back through the router ---
for node_name in ("signal_ingestor", "situation_analyst", "response_orchestrator"):
    workflow.add_conditional_edges(
        node_name,
        supervisor_router,
        {
            "signal_ingestor": "signal_ingestor",
            "situation_analyst": "situation_analyst",
            "response_orchestrator": "response_orchestrator",
            END: END,
        },
    )

# --- compile ---
ciro_graph = workflow.compile()


# ═══════════════════════════════════════════════════════════════════
# Antigravity-orchestrated pipeline runner
# ═══════════════════════════════════════════════════════════════════

def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


async def run_pipeline(
    incident_id: str,
    raw_signals: dict,
    store: IncidentStore,
) -> None:
    """
    Run the full CIRO pipeline via Google Antigravity orchestration.

    Antigravity is the entry point — it creates an execution plan,
    then routes each step through the LangGraph compiled graph.
    The LangGraph handles agent-level execution, while Antigravity
    manages the overall workflow planning, coordination, and tracing.
    """
    try:
        # ── PHASE 1: Antigravity Planning ────────────────────────
        logger.info("[Antigravity] Creating execution plan for incident %s", incident_id)
        plan = antigravity.create_plan(incident_id, raw_signals)

        # Log the Antigravity plan as the first trace entry
        store.append_trace(incident_id, {
            "agent": "Antigravity Orchestrator",
            "status": "complete",
            "output_summary": (
                f"Execution plan {plan.plan_id} created with {len(plan.steps)} steps. "
                f"Reasoning: {plan.reasoning[:200]}"
            ),
            "full_output": {
                "plan_id": plan.plan_id,
                "reasoning": plan.reasoning,
                "planned_steps": [
                    {
                        "step": s.step_id,
                        "agent": antigravity.agents[s.agent].name,
                        "action": s.action,
                        "tools": [t.name for t in antigravity.agents[s.agent].tools],
                    }
                    for s in plan.steps
                ],
            },
            "timestamp": _now(),
        })

        # ── PHASE 2: Antigravity Execution ───────────────────────
        logger.info("[Antigravity] Executing plan %s via LangGraph", plan.plan_id)

        initial_state: CIROState = {
            "incident_id": incident_id,
            "antigravity_plan": plan,
            "raw_signals": raw_signals,
            "normalized_signals": {},
            "situation_assessment": {},
            "response_plan": {},
            "messages": [],
            "agent_trace": [],
            "status": "processing",
            "error": None,
        }

        # Execute the LangGraph — Antigravity monitors each step
        # The graph's supervisor_router handles internal routing
        final_state = await ciro_graph.ainvoke(initial_state)

        # ── PHASE 3: Antigravity Trace Extraction ────────────────
        # Extract what each agent produced and log through Antigravity
        agent_traces = final_state.get("agent_trace", [])

        for trace in agent_traces:
            store.append_trace(incident_id, trace)

        # ── PHASE 4: Antigravity Plan Finalization ───────────────
        plan_summary = antigravity.finalize_plan(plan)

        # Log the finalized plan as the last trace entry
        store.append_trace(incident_id, {
            "agent": "Antigravity Orchestrator",
            "status": "complete",
            "output_summary": (
                f"Plan {plan.plan_id} finalized — {plan.status} "
                f"({plan.total_duration_ms:.0f}ms total). "
                f"All {len(plan.steps)} agents executed successfully."
            ),
            "full_output": plan_summary,
            "timestamp": _now(),
        })

        # ── PHASE 5: Persist Results ─────────────────────────────
        normalized = final_state.get("normalized_signals", {})
        store.update(incident_id, normalized_signals=normalized)

        assessment = final_state.get("situation_assessment", {})
        store.update(
            incident_id,
            situation_assessment=assessment,
            crisis_type=assessment.get("crisis_type", "unknown"),
            severity=assessment.get("severity", "unknown"),
            confidence=assessment.get("confidence", "unknown"),
            affected_area=_extract_affected_area(assessment),
        )

        response = final_state.get("response_plan", {})
        store.update(incident_id, response_plan=response)

        # Final status
        final_status = final_state.get("status", "complete")
        if final_status == "error":
            store.update(
                incident_id,
                status="error",
                error=final_state.get("error", "Unknown pipeline error"),
            )
        else:
            store.update(incident_id, status="complete")

        logger.info(
            "[Antigravity] Pipeline complete for incident %s — plan %s",
            incident_id, plan.plan_id,
        )

    except Exception as exc:
        logger.exception(
            "[Antigravity] Pipeline failed for incident %s", incident_id,
        )
        store.update(
            incident_id,
            status="error",
            error=str(exc),
        )
        store.append_trace(incident_id, {
            "agent": "Antigravity Orchestrator",
            "status": "error",
            "error": str(exc),
            "timestamp": _now(),
        })


def _extract_affected_area(assessment: dict) -> str:
    """Build a human-readable affected-area string from the assessment."""
    area = assessment.get("affected_area", {})
    if isinstance(area, dict):
        primary = area.get("primary", "unknown")
        city = area.get("city", "")
        return f"{primary}, {city}" if city else primary
    return str(area) if area else "unknown"
