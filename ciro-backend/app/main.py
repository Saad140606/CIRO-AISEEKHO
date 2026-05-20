"""
CIRO Backend — FastAPI application.

Crisis Intelligence & Response Orchestrator.
Multi-agent AI system that detects urban crises from multi-source
signals and coordinates simulated emergency responses.
"""

import asyncio
import json
import logging
import time
import os
import glob
from contextlib import asynccontextmanager
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from sse_starlette.sse import EventSourceResponse

from models.schemas import (
    AnalyzeRequest,
    AnalyzeResponse,
    ScenarioRequest,
)
from store.incident_store import incident_store
from tools.simulated_apis import get_weather, get_traffic
from graph.pipeline import run_pipeline
from graph.antigravity_config import antigravity

# ── bootstrap ─────────────────────────────────────────────────────

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
logger = logging.getLogger("ciro")


# ── lifespan ──────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    config = antigravity.get_workflow_config()
    agent_count = len(config["agents"])
    tool_count = len(config["tools"])
    logger.info(
        "CIRO Backend started. Google Antigravity orchestrator active. "
        "%d agents registered, %d tools bound. "
        "LangGraph pipeline compiled successfully.",
        agent_count, tool_count,
    )
    yield
    logger.info("CIRO Backend shutting down.")


# ── app ───────────────────────────────────────────────────────────

app = FastAPI(
    title="CIRO — Crisis Intelligence & Response Orchestrator",
    version="1.0.0",
    description=(
        "Multi-agent AI backend that detects urban crises from "
        "multi-source signals and coordinates simulated emergency responses."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure static folder exists and mount it
os.makedirs("static", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def root_redirect():
    """Redirect root to the static web application dashboard."""
    return RedirectResponse(url="/static/index.html")



# ═══════════════════════════════════════════════════════════════════
# PRE-BUILT SCENARIO DATA
# ═══════════════════════════════════════════════════════════════════

SCENARIOS: dict[str, dict] = {
    "flooding_g10": {
        "social_posts": [
            "G-10 mein pani bhar gaya hai, gaariyan phans gayi hain",
            "Flash flood at G-10 Markaz for the past 30 minutes, please send help",
            "Islamabad G-10 road completely under water, avoid this area",
        ],
        "weather": get_weather("islamabad"),
        "traffic": get_traffic("g10_islamabad"),
        "manual_reports": [
            "CDA field report: water level 2.5ft on Fazl-e-Haq Road",
            "37 vehicles confirmed stranded near G-10 Markaz",
        ],
    },
    "heatwave_karachi": {
        "social_posts": [
            "Karachi ki garmi mein log behosh ho rahe hain Saddar mein",
            "Multiple heat stroke cases reported near Karachi Saddar",
            "Temperature feels like 50 degrees, hospitals filling up",
        ],
        "weather": get_weather("karachi"),
        "traffic": get_traffic("saddar_karachi"),
        "manual_reports": [
            "EDHI: 8 heat exhaustion cases in last 2 hours, Saddar area",
            "Karachi Electric reports power outages in 3 feeders",
        ],
    },
    "accident_mm_alam": {
        "social_posts": [
            "Bara hadsa MM Alam Road par, 3 gaariyan takra gayi hain",
            "Serious accident on MM Alam Road Lahore, avoid the area",
            "MM Alam Road blocked both sides due to accident",
        ],
        "weather": get_weather("lahore"),
        "traffic": get_traffic("mm_alam_lahore"),
        "manual_reports": [
            "Punjab Police report: 3-vehicle collision at MM Alam Road",
            "Traffic Police report: road blocked, casualties unclear",
        ],
    },
    "infra_failure_saddar": {
        "social_posts": [
            "Abdullah Haroon Road mein gutter phoot gaya bada wala",
            "Huge sinkhole appeared on MA Jinnah Road near Saddar",
            "Karachi water main burst, road collapsing near Saddar",
        ],
        "weather": get_weather("karachi"),
        "traffic": get_traffic("saddar_karachi"),
        "manual_reports": [
            "KW&SB report: main water pipe burst, 24 inch diameter",
            "KMC: road surface instability detected, sinkhole risk",
        ],
    },
}


# ═══════════════════════════════════════════════════════════════════
# ENDPOINTS
# ═══════════════════════════════════════════════════════════════════

# ── POST /api/analyze ─────────────────────────────────────────────

@app.post("/api/analyze", response_model=AnalyzeResponse)
async def analyze(request: AnalyzeRequest):
    """Launch the CIRO pipeline on user-provided signals."""
    incident_id = str(uuid4())

    raw_signals = {
        "social_posts": request.social_posts,
        "weather": request.weather_override or get_weather("islamabad"),
        "traffic": request.traffic_override or get_traffic("g10_islamabad"),
        "manual_reports": request.manual_reports,
    }

    incident_store.create(incident_id, raw_signals)
    asyncio.create_task(run_pipeline(incident_id, raw_signals, incident_store))

    return AnalyzeResponse(incident_id=incident_id, status="processing")


# ── POST /api/simulate/scenario ──────────────────────────────────

@app.post("/api/simulate/scenario", response_model=AnalyzeResponse)
async def simulate_scenario(request: ScenarioRequest):
    """Launch the CIRO pipeline on a pre-built scenario."""
    incident_id = str(uuid4())
    raw_signals = SCENARIOS[request.scenario]

    incident_store.create(incident_id, raw_signals)
    asyncio.create_task(run_pipeline(incident_id, raw_signals, incident_store))

    return AnalyzeResponse(incident_id=incident_id, status="processing")


# ── GET /api/stream/{incident_id} ────────────────────────────────

@app.get("/api/stream/{incident_id}")
async def stream_incident(incident_id: str):
    """SSE stream of real-time pipeline updates for an incident."""

    incident = incident_store.get(incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")

    async def event_generator():
        last_trace_index = 0
        sent_signals = False
        sent_assessment = False
        sent_response = False
        start = time.time()
        timeout = 120  # seconds

        # Initial event
        yield {
            "event": "incident_created",
            "data": json.dumps({
                "incident_id": incident_id,
                "status": "processing",
            }),
        }

        heartbeat_counter = 0

        while True:
            if time.time() - start > timeout:
                yield {
                    "event": "timeout",
                    "data": json.dumps({"message": "Stream timed out after 120 seconds"}),
                }
                break

            current = incident_store.get(incident_id)
            if current is None:
                break

            # --- agent_update: emit new trace entries ---
            traces = incident_store.get_trace(incident_id) or []
            while last_trace_index < len(traces):
                yield {
                    "event": "agent_update",
                    "data": json.dumps(traces[last_trace_index]),
                }
                last_trace_index += 1

            # --- signal_processed ---
            if not sent_signals and current.get("normalized_signals"):
                yield {
                    "event": "signal_processed",
                    "data": json.dumps(current["normalized_signals"]),
                }
                sent_signals = True

            # --- situation_assessed ---
            if not sent_assessment and current.get("situation_assessment"):
                yield {
                    "event": "situation_assessed",
                    "data": json.dumps(current["situation_assessment"]),
                }
                sent_assessment = True

            # --- response_complete ---
            if not sent_response and current.get("status") == "complete" and current.get("response_plan"):
                yield {
                    "event": "response_complete",
                    "data": json.dumps(current["response_plan"]),
                }
                sent_response = True

            # --- error ---
            if current.get("status") == "error":
                yield {
                    "event": "error",
                    "data": json.dumps({"error": current.get("error", "Unknown error")}),
                }
                break

            # --- done ---
            if current.get("status") in ("complete",) and sent_response:
                break

            # --- heartbeat every ~3 seconds (3 / 0.8 ≈ 4 iterations) ---
            heartbeat_counter += 1
            if heartbeat_counter % 4 == 0:
                yield {
                    "event": "heartbeat",
                    "data": json.dumps({"ts": time.time()}),
                }

            await asyncio.sleep(0.8)

    return EventSourceResponse(event_generator())


# ── GET /api/incidents ────────────────────────────────────────────

@app.get("/api/incidents")
async def list_incidents():
    """Return summary list of all incidents."""
    return incident_store.list_all()


# ── GET /api/incidents/{incident_id} ──────────────────────────────

@app.get("/api/incidents/{incident_id}")
async def get_incident(incident_id: str):
    """Return full detail for a single incident."""
    incident = incident_store.get(incident_id)
    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


# ── GET /api/incidents/{incident_id}/trace ────────────────────────

@app.get("/api/incidents/{incident_id}/trace")
async def get_incident_trace(incident_id: str):
    """Return the agent trace for a single incident."""
    trace = incident_store.get_trace(incident_id)
    if trace is None:
        raise HTTPException(status_code=404, detail="Incident not found")
    return trace


# ── GET /api/antigravity/config ───────────────────────────────────

@app.get("/api/antigravity/config")
async def get_antigravity_config():
    """Return the full Antigravity workflow configuration."""
    return antigravity.get_workflow_config()


def get_latest_antigravity_trace_file() -> str | None:
    # Try finding it in user's home directory
    base_dir = os.path.expanduser(r"~\.gemini\antigravity\brain")
    if not os.path.exists(base_dir):
        # Fallback to absolute path
        base_dir = r"C:\Users\ALVI TECH\.gemini\antigravity\brain"
        if not os.path.exists(base_dir):
            return None
    
    # Search for transcript.jsonl recursively
    pattern = os.path.join(base_dir, "**", ".system_generated", "logs", "transcript.jsonl")
    files = glob.glob(pattern, recursive=True)
    if not files:
        return None
    # Return the most recently updated transcript
    return max(files, key=os.path.getmtime)


def parse_antigravity_traces() -> list[dict]:
    trace_file = get_latest_antigravity_trace_file()
    if not trace_file:
        return []
    
    traces = []
    try:
        with open(trace_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    data = json.loads(line)
                    # Limit size of large fields in API response to keep UI performant
                    content = data.get("content") or ""
                    if content and len(content) > 1000:
                        data["content"] = content[:1000] + "... (truncated)"
                    
                    thinking = data.get("thinking") or ""
                    if thinking and len(thinking) > 1000:
                        data["thinking"] = thinking[:1000] + "... (truncated)"
                    
                    traces.append(data)
                except Exception:
                    pass
    except Exception as e:
        logger.error(f"Error parsing Antigravity traces: {e}")
    return traces


# ── GET /api/antigravity/traces ───────────────────────────────────

@app.get("/api/antigravity/traces")
async def get_antigravity_traces():
    """Return the real Google Antigravity developer traces from the actual platform."""
    traces = parse_antigravity_traces()
    return {
        "status": "success",
        "count": len(traces),
        "trace_file": get_latest_antigravity_trace_file(),
        "traces": traces
    }



# ── GET /api/health ───────────────────────────────────────────────

@app.get("/api/health")
async def health():
    """Health check."""
    return {
        "status": "ok",
        "service": "CIRO Backend",
        "version": "1.0.0",
        "orchestrator": "Google Antigravity",
    }


# ═══════════════════════════════════════════════════════════════════
# Entrypoint
# ═══════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
