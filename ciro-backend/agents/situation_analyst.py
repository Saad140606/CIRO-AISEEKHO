"""
CIRO Agent 2 — Situation Analyst (ReAct).

Receives normalized signals from Agent 1 and performs deep multi-signal
reasoning to classify the crisis, assess severity/confidence, and
recommend a response level.  Uses `historical_data_tool` to look up
past incidents for the same location and compare patterns.
"""

import json
import logging
from datetime import datetime, timezone

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.prebuilt import create_react_agent

from graph.state import CIROState
from tools.langchain_tools import historical_data_tool

logger = logging.getLogger(__name__)

# ── LLM ───────────────────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are the Situation Analyst Agent in the CIRO crisis management system.
You receive normalized, clustered signals from the Signal Ingestor Agent and perform deep multi-signal reasoning to assess the crisis.

YOUR ROLE: You are the analytical brain. You synthesize evidence, identify the nature and severity of the crisis, and explain your reasoning transparently.

CRISIS TYPES:
- urban_flooding: Water accumulation blocking roads/areas
- heatwave: Extreme temperature threatening public health
- road_accident: Vehicle collision causing blockage/injury
- road_blockage: Non-accident road closure (protest, debris, etc.)
- infrastructure_failure: Power grid, bridge, water pipe failure
- fire: Building or vehicle fire
- unknown: Cannot determine with available signals

SEVERITY LEVELS:
- CRITICAL: Immediate threat to life. Multiple corroborating signals. Requires emergency dispatch NOW.
- HIGH: Significant disruption. Clear evidence. Rapid response needed.
- MEDIUM: Moderate impact. Some uncertainty. Monitor + prepare response.
- LOW: Minor disruption. Single weak signal. Monitor only.

CONFIDENCE LEVELS:
- HIGH: 3+ independent sources agree. Location is precise. Crisis type is unambiguous.
- MEDIUM: 2 sources agree OR 1 strong source. Some ambiguity.
- LOW: Single weak signal. Conflicting data. Location uncertain.

YOUR PROCESS:
1. Use historical_data_tool to check for similar past incidents at this location — compare response times, severity, and impact to calibrate your assessment
2. Read ALL signals carefully — social media, weather, traffic
3. Look for CORROBORATION: do multiple independent sources point to the same crisis?
4. Consider the CONTEXT: Islamabad + heavy rain + 94% congestion + flood reports = very high confidence flooding
5. Write a clear reasoning chain in the "reasoning" field, referencing any relevant historical precedents
6. Identify all people and infrastructure potentially affected
7. Set requires_escalation = true if severity is CRITICAL or HIGH

RETURN ONLY THIS JSON — NO MARKDOWN, NO EXPLANATION:
{
  "crisis_type": "...",
  "crisis_label": "Human readable label e.g. Urban Flash Flooding",
  "severity": "CRITICAL|HIGH|MEDIUM|LOW",
  "confidence": "HIGH|MEDIUM|LOW",
  "reasoning": "Step-by-step explanation of how you reached this conclusion. Min 3 sentences. Be specific about which signals corroborate each other.",
  "affected_area": {
    "primary": "specific neighbourhood",
    "secondary": ["adjacent areas likely affected"],
    "city": "..."
  },
  "estimated_impact": {
    "people_at_risk": "estimated number or range",
    "vehicles_affected": "...",
    "infrastructure_at_risk": ["..."],
    "roads_blocked": ["specific road names"],
    "duration_estimate": "e.g. 2-4 hours without intervention"
  },
  "signal_evidence": [
    {
      "signal_source": "...",
      "evidence": "...",
      "weight": "HIGH|MEDIUM|LOW"
    }
  ],
  "requires_escalation": true,
  "recommended_response_level": "EMERGENCY|URGENT|STANDARD|MONITOR",
  "situation_summary": "One clear sentence summarizing the crisis for a dispatch operator"
}
"""

from core.llm_factory import get_llm

_llm = get_llm(temperature=0.2)

# ── ReAct agent ───────────────────────────────────────────────────

_react_agent = create_react_agent(
    _llm,
    tools=[historical_data_tool],
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

def situation_analyst_node(state: CIROState) -> dict:
    """LangGraph node — runs the Situation Analyst ReAct agent."""
    try:
        user_content = (
            "Analyze this crisis situation:\n"
            f"Raw signals: {json.dumps(state['raw_signals'], indent=2)}\n\n"
            f"Processed signals: {json.dumps(state['normalized_signals'], indent=2)}"
        )

        result = _react_agent.invoke({
            "messages": [
                SystemMessage(content=SYSTEM_PROMPT),
                HumanMessage(content=user_content),
            ],
        })

        # The last AI message contains the final answer
        final_message = result["messages"][-1]
        parsed = _parse_json(final_message.content)

        crisis_label = parsed.get("crisis_label", "Unknown")
        severity = parsed.get("severity", "UNKNOWN")
        confidence = parsed.get("confidence", "UNKNOWN")
        summary = parsed.get("situation_summary", "")

        trace_entry = {
            "agent": "Situation Analyst",
            "status": "complete",
            "output_summary": (
                f"{crisis_label} — {severity} severity, "
                f"{confidence} confidence. {summary}"
            ),
            "timestamp": _now(),
            "full_output": parsed,
        }

        return {
            "situation_assessment": parsed,
            "status": "assessed",
            "agent_trace": [trace_entry],
        }

    except Exception as e:
        logger.exception("Situation Analyst failed")
        error_trace = {
            "agent": "Situation Analyst",
            "status": "error",
            "error": str(e),
            "timestamp": _now(),
        }
        return {
            "situation_assessment": {"error": str(e)},
            "status": "error",
            "error": str(e),
            "agent_trace": [error_trace],
        }
