"""
CIRO Agent 3 — Response Orchestrator.

Receives a fully analysed crisis situation and executes a prioritised
action plan by calling route-update, emergency-dispatch, alert, and
ticket-creation tools.
"""

import json
import logging
from datetime import datetime, timezone

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.prebuilt import create_react_agent

from graph.antigravity_config import AgentRole, antigravity
from graph.state import CIROState
from tools.langchain_tools import (
    route_update_tool,
    emergency_dispatch_tool,
    alert_dispatch_tool,
    ticket_creation_tool,
)

logger = logging.getLogger(__name__)

# ── LLM + react agent ────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are the Response Orchestrator Agent in the CIRO crisis management system. You receive a fully analyzed crisis situation and must:
1. Generate a prioritized action plan
2. Execute each action by calling the appropriate tools
3. Report the simulated outcomes

YOU MUST ALWAYS call tools — do not just list actions. Actually invoke the tools and collect their results.

DECISION RULES (follow strictly):

For urban_flooding:
- ALWAYS call route_update_tool for the blocked location
- If severity is HIGH or CRITICAL: call emergency_dispatch_tool
- ALWAYS call alert_dispatch_tool with channel="SMS"
- ALWAYS call ticket_creation_tool

For heatwave:
- Call alert_dispatch_tool with channel="RadioBroadcast" (warn citizens to stay indoors)
- If CRITICAL: call emergency_dispatch_tool (medical standby)
- Call ticket_creation_tool

For road_accident:
- ALWAYS call emergency_dispatch_tool first (highest priority)
- Call route_update_tool
- Call alert_dispatch_tool with channel="PushNotification"
- Call ticket_creation_tool

For infrastructure_failure:
- Call emergency_dispatch_tool
- Call alert_dispatch_tool with channel="SMS"
- Call ticket_creation_tool
- Do NOT call route_update_tool unless roads are affected

LOCATION KEY MAPPING (use these exactly):
- G-10, Islamabad → location_key: "g10_islamabad"
- MM Alam Road, Lahore → location_key: "mm_alam_lahore"
- Saddar, Karachi → location_key: "saddar_karachi"

After calling all tools, compile results and return this JSON:

{
  "action_plan": [
    {
      "action_id": "ACT-001",
      "type": "route_update|emergency_dispatch|public_alert|ticket",
      "priority": "IMMEDIATE|HIGH|NORMAL",
      "description": "...",
      "target": "...",
      "rationale": "Why this action for this crisis"
    }
  ],
  "simulation_results": [
    {
      "action_id": "ACT-001",
      "tool_used": "...",
      "status": "EXECUTED|FAILED",
      "outcome": "...",
      "timestamp": "...",
      "log": "..."
    }
  ],
  "before_state": {
    "congestion_percent": 0,
    "emergency_teams_deployed": 0,
    "citizens_alerted": 0,
    "incident_tickets": 0,
    "roads_operational": "..."
  },
  "after_state": {
    "congestion_percent": 0,
    "emergency_teams_deployed": 0,
    "citizens_alerted": 0,
    "incident_tickets": 1,
    "roads_operational": "...",
    "estimated_recovery_time": "..."
  },
  "outcome_summary": "Concise summary of what was done and the simulated impact. Include specific numbers."
}

IMPORTANT: The before_state must reflect actual values from the situation assessment (e.g. congestion from traffic data). The after_state must show realistic improvement:
- congestion drops by 40-55% after route update
- emergency_teams_deployed = number of units dispatched
- citizens_alerted = sum of all alert recipients
"""

from core.llm_factory import get_llm

_llm = get_llm(temperature=0.2)

_agent = create_react_agent(
    _llm,
    tools=[
        route_update_tool,
        emergency_dispatch_tool,
        alert_dispatch_tool,
        ticket_creation_tool,
    ],
)


# ── helpers ───────────────────────────────────────────────────────

def _parse_json(text) -> dict:
    """Strip optional markdown fences and parse JSON."""
    # Some LLM providers return content as a list of blocks instead of a str
    if isinstance(text, list):
        text = "".join(
            part if isinstance(part, str) else part.get("text", "")
            for part in text
        )
    text = text.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    return json.loads(text.strip())


def _now() -> str:
    return datetime.now().isoformat().replace("+00:00", "Z")


# ── node function ─────────────────────────────────────────────────

def response_orchestrator_node(state: CIROState) -> dict:
    """LangGraph node — runs the Response Orchestrator react agent."""
    plan = state.get("antigravity_plan")
    if plan:
        antigravity.log_step_start(plan, 3)
    try:
        assessment = state.get("situation_assessment", {})

        user_content = (
            "Execute the response plan for this crisis:\n\n"
            f"Situation Assessment:\n{json.dumps(assessment, indent=2)}\n\n"
            f"Raw Signals:\n{json.dumps(state.get('raw_signals', {}), indent=2)}\n\n"
            f"Normalized Signals:\n{json.dumps(state.get('normalized_signals', {}), indent=2)}"
        )

        result = _agent.invoke({
            "messages": [
                SystemMessage(content=SYSTEM_PROMPT),
                HumanMessage(content=user_content),
            ],
        })

        # Extract final AI message
        final_message = result["messages"][-1]
        parsed = _parse_json(final_message.content)

        outcome = parsed.get("outcome_summary", "Response plan executed.")

        trace_entry = {
            "agent": "Response Orchestrator",
            "status": "complete",
            "output_summary": outcome,
            "timestamp": _now(),
            "full_output": parsed,
        }

        if plan:
            antigravity.log_step_complete(
                plan,
                3,
                trace_entry["output_summary"],
                tools_used=[
                    "route_update",
                    "emergency_dispatch",
                    "alert_dispatch",
                    "ticket_creation",
                ],
            )

        return {
            "response_plan": parsed,
            "status": "complete",
            "agent_trace": [trace_entry],
        }

    except Exception as e:
        logger.exception("Response Orchestrator failed")
        error_trace = {
            "agent": "Response Orchestrator",
            "status": "error",
            "error": str(e),
            "timestamp": _now(),
        }
        if plan:
            antigravity.log_step_error(plan, 3, str(e))
        return {
            "response_plan": {"error": str(e)},
            "status": "error",
            "error": str(e),
            "agent_trace": [error_trace],
        }
