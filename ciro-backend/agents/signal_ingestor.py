"""
CIRO Agent 1 — Signal Ingestor.

Processes raw multi-source crisis signals, calls weather/traffic tools,
normalizes text (including Roman Urdu), and returns a structured
signal analysis.
"""

import json
import logging
from datetime import datetime, timezone

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.prebuilt import create_react_agent

from graph.state import CIROState
from tools.langchain_tools import weather_lookup_tool, traffic_lookup_tool

logger = logging.getLogger(__name__)

# ── LLM + react agent ────────────────────────────────────────────

SYSTEM_PROMPT = """\
You are the Signal Ingestor Agent in the CIRO crisis management system.
Your job is to process raw, multi-source crisis signals from Pakistani cities, normalize them, and return a structured analysis.

You handle signals from: social media posts (including Urdu and Roman Urdu text), weather APIs, traffic APIs, and manual reports.

ROMAN URDU TRANSLATIONS you must know:
- "pani bhar gaya" = water has filled/flooded
- "gaariyan phans gayi" = cars/vehicles are stuck
- "aag lag gayi" = fire has broken out
- "sadak band hai" = road is closed
- "bijli nahi hai" = no electricity
- "garmi bahut zyada hai" = extreme heat
- "hadsa ho gaya" = accident occurred
- "log phanse hue hain" = people are trapped

YOUR PROCESS:
1. Use weather_lookup_tool to verify weather conditions for the detected city
2. Use traffic_lookup_tool to verify traffic data for the detected location
3. Normalize all text to English
4. Extract the precise location (neighbourhood, city)
5. Identify crisis type signals in the data
6. Cluster related signals together
7. Return ONLY valid JSON — no markdown, no explanation

VALID LOCATION KEYS for traffic_lookup_tool:
- g10_islamabad
- mm_alam_lahore
- saddar_karachi
- clifton_karachi

VALID CITY NAMES for weather_lookup_tool:
- islamabad
- karachi
- lahore

RETURN THIS EXACT JSON STRUCTURE:
{
  "normalized_signals": [
    {
      "source": "social_media|weather|traffic|manual",
      "original_text": "...",
      "normalized_text": "...",
      "location_mentioned": "...",
      "crisis_indicators": ["..."],
      "credibility": "HIGH|MEDIUM|LOW"
    }
  ],
  "weather_data": { ...raw tool result... },
  "traffic_data": { ...raw tool result... },
  "detected_anomalies": [
    {
      "type": "...",
      "description": "...",
      "severity_signal": "HIGH|MEDIUM|LOW"
    }
  ],
  "signal_clusters": [
    {
      "cluster_name": "...",
      "signal_count": 0,
      "sources_agreeing": ["..."],
      "primary_location": "...",
      "crisis_type_hint": "..."
    }
  ],
  "extracted_location": {
    "neighbourhood": "...",
    "city": "...",
    "location_key": "...",
    "confidence": "HIGH|MEDIUM|LOW"
  },
  "signal_quality_score": 0.0
}
"""

from core.llm_factory import get_llm

_llm = get_llm(temperature=0.2)

_agent = create_react_agent(
    _llm,
    tools=[weather_lookup_tool, traffic_lookup_tool],
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
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


# ── node function ─────────────────────────────────────────────────

def signal_ingestor_node(state: CIROState) -> dict:
    """LangGraph node — runs the Signal Ingestor react agent."""
    try:
        user_content = f"Process these crisis signals:\n{json.dumps(state['raw_signals'], indent=2)}"

        result = _agent.invoke({
            "messages": [
                SystemMessage(content=SYSTEM_PROMPT),
                HumanMessage(content=user_content),
            ],
        })

        # The last AI message contains the final structured output
        final_message = result["messages"][-1]
        parsed = _parse_json(final_message.content)

        clusters = parsed.get("signal_clusters", [])
        location = parsed.get("extracted_location", {})
        loc_label = f"{location.get('neighbourhood', '?')}, {location.get('city', '?')}"
        score = parsed.get("signal_quality_score", 0.0)

        trace_entry = {
            "agent": "Signal Ingestor",
            "status": "complete",
            "output_summary": (
                f"Detected {len(clusters)} signal cluster(s) "
                f"at {loc_label}. Quality score: {score}"
            ),
            "timestamp": _now(),
            "full_output": parsed,
        }

        return {
            "normalized_signals": parsed,
            "status": "analyzed",
            "agent_trace": [trace_entry],
        }

    except Exception as e:
        logger.exception("Signal Ingestor failed")
        error_trace = {
            "agent": "Signal Ingestor",
            "status": "error",
            "error": str(e),
            "timestamp": _now(),
        }
        return {
            "normalized_signals": {"error": str(e)},
            "status": "error",
            "error": str(e),
            "agent_trace": [error_trace],
        }
