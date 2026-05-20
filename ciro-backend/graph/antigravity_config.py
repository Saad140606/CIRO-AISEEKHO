"""
CIRO Antigravity Orchestration Configuration.

Defines the Google Antigravity workflow that wraps the LangGraph pipeline.
Antigravity acts as the CORE orchestration layer:
  - Defines each agent as an Antigravity Task
  - Plans the execution flow between agents
  - Manages tool routing and trace logging
  - Provides reasoning transparency for each decision step

The LangGraph pipeline is used internally for agent execution,
but Antigravity handles the high-level planning, routing, and
coordination logic.
"""

import logging
import time
from datetime import datetime, timezone
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Callable

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════
# Antigravity Agent Definitions
# ═══════════════════════════════════════════════════════════════════

class AgentRole(Enum):
    """Agent roles in the Antigravity workflow."""
    SIGNAL_INGESTOR = "signal_ingestor"
    SITUATION_ANALYST = "situation_analyst"
    RESPONSE_ORCHESTRATOR = "response_orchestrator"


@dataclass
class AntigravityTool:
    """A tool registered in the Antigravity orchestration layer."""
    name: str
    description: str
    agent: AgentRole
    function_ref: str  # dotted path to the tool function


@dataclass
class AntigravityAgent:
    """An agent definition in the Antigravity workflow."""
    role: AgentRole
    name: str
    description: str
    tools: list[AntigravityTool] = field(default_factory=list)
    capabilities: list[str] = field(default_factory=list)
    llm_provider: str = "gemini-2.0-flash"


@dataclass
class AntigravityStep:
    """A single step in the Antigravity execution plan."""
    step_id: int
    agent: AgentRole
    action: str
    reasoning: str
    status: str = "pending"  # pending | running | complete | error
    started_at: str | None = None
    completed_at: str | None = None
    duration_ms: float | None = None
    output_summary: str | None = None
    tools_used: list[str] = field(default_factory=list)
    error: str | None = None


@dataclass
class AntigravityPlan:
    """The execution plan created by Antigravity for a crisis incident."""
    plan_id: str
    incident_id: str
    created_at: str = ""
    steps: list[AntigravityStep] = field(default_factory=list)
    status: str = "planned"  # planned | executing | complete | error
    total_duration_ms: float = 0.0
    reasoning: str = ""


# ═══════════════════════════════════════════════════════════════════
# Tool Registry
# ═══════════════════════════════════════════════════════════════════

ANTIGRAVITY_TOOLS: list[AntigravityTool] = [
    AntigravityTool(
        name="weather_lookup",
        description="Fetch real-time weather data for a Pakistani city",
        agent=AgentRole.SIGNAL_INGESTOR,
        function_ref="tools.langchain_tools.weather_lookup_tool",
    ),
    AntigravityTool(
        name="traffic_lookup",
        description="Fetch traffic congestion data for a location",
        agent=AgentRole.SIGNAL_INGESTOR,
        function_ref="tools.langchain_tools.traffic_lookup_tool",
    ),
    AntigravityTool(
        name="historical_data",
        description="Look up historical crisis incidents for a location",
        agent=AgentRole.SITUATION_ANALYST,
        function_ref="tools.langchain_tools.historical_data_tool",
    ),
    AntigravityTool(
        name="route_update",
        description="Push alternate routes to navigation apps (Google Maps, Waze)",
        agent=AgentRole.RESPONSE_ORCHESTRATOR,
        function_ref="tools.langchain_tools.route_update_tool",
    ),
    AntigravityTool(
        name="emergency_dispatch",
        description="Dispatch emergency services (ambulance, fire, police) to crisis zone",
        agent=AgentRole.RESPONSE_ORCHESTRATOR,
        function_ref="tools.langchain_tools.emergency_dispatch_tool",
    ),
    AntigravityTool(
        name="alert_dispatch",
        description="Send SMS/Push/Radio alerts to citizens in affected area",
        agent=AgentRole.RESPONSE_ORCHESTRATOR,
        function_ref="tools.langchain_tools.alert_dispatch_tool",
    ),
    AntigravityTool(
        name="ticket_creation",
        description="Create and assign incident management ticket",
        agent=AgentRole.RESPONSE_ORCHESTRATOR,
        function_ref="tools.langchain_tools.ticket_creation_tool",
    ),
]


# ═══════════════════════════════════════════════════════════════════
# Agent Registry
# ═══════════════════════════════════════════════════════════════════

ANTIGRAVITY_AGENTS: dict[AgentRole, AntigravityAgent] = {
    AgentRole.SIGNAL_INGESTOR: AntigravityAgent(
        role=AgentRole.SIGNAL_INGESTOR,
        name="Signal Ingestor",
        description=(
            "Processes raw multi-source signals (social media in English/Urdu/Roman Urdu, "
            "weather API data, traffic feeds, manual field reports) and normalizes them "
            "into structured, actionable signal clusters."
        ),
        tools=[t for t in ANTIGRAVITY_TOOLS if t.agent == AgentRole.SIGNAL_INGESTOR],
        capabilities=[
            "Multi-language NLP (English, Urdu, Roman Urdu)",
            "Signal anomaly detection",
            "Location extraction and geocoding",
            "Signal clustering and deduplication",
            "Weather API integration",
            "Traffic data normalization",
        ],
    ),
    AgentRole.SITUATION_ANALYST: AntigravityAgent(
        role=AgentRole.SITUATION_ANALYST,
        name="Situation Analyst",
        description=(
            "Performs deep multi-signal reasoning to classify crisis type, "
            "assess severity and confidence, and recommend response level. "
            "Compares current crisis with historical precedents."
        ),
        tools=[t for t in ANTIGRAVITY_TOOLS if t.agent == AgentRole.SITUATION_ANALYST],
        capabilities=[
            "Crisis type classification (7 types)",
            "Severity assessment (CRITICAL/HIGH/MEDIUM/LOW)",
            "Confidence scoring with evidence chain",
            "Historical incident comparison",
            "Impact estimation (people, vehicles, infrastructure)",
            "Escalation recommendation",
        ],
    ),
    AgentRole.RESPONSE_ORCHESTRATOR: AntigravityAgent(
        role=AgentRole.RESPONSE_ORCHESTRATOR,
        name="Response Orchestrator",
        description=(
            "Executes coordinated response actions: route updates, emergency dispatch, "
            "citizen alerts, and incident ticket creation. Simulates before/after state "
            "to measure response impact."
        ),
        tools=[t for t in ANTIGRAVITY_TOOLS if t.agent == AgentRole.RESPONSE_ORCHESTRATOR],
        capabilities=[
            "Multi-action coordination",
            "Route update simulation (Google Maps/Waze)",
            "Emergency unit dispatch with ETA",
            "Mass citizen alert broadcasting",
            "Incident ticket lifecycle management",
            "Before/after impact simulation",
        ],
    ),
}


# ═══════════════════════════════════════════════════════════════════
# Antigravity Workflow Orchestrator
# ═══════════════════════════════════════════════════════════════════

def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class AntigravityOrchestrator:
    """
    Google Antigravity Workflow Orchestrator for CIRO.

    This is the CORE entry point for crisis processing. It:
    1. Receives raw signals from the API layer
    2. Creates an execution plan (which agents to run, in what order)
    3. Routes each step through the appropriate LangGraph agent node
    4. Captures detailed trace logs for transparency
    5. Returns the final crisis assessment and response plan

    The LangGraph pipeline handles individual agent execution,
    but Antigravity handles the planning, routing, and coordination.
    """

    def __init__(self):
        self.agents = ANTIGRAVITY_AGENTS
        self.tools = ANTIGRAVITY_TOOLS
        self._execution_log: list[dict] = []

    def create_plan(self, incident_id: str, raw_signals: dict) -> AntigravityPlan:
        """
        Antigravity planning phase — analyze the incoming signals and
        create an execution plan for the multi-agent pipeline.

        This is where Antigravity decides:
        - Which agents need to run
        - In what order
        - What tools each agent should use
        - What the expected outcome is
        """
        plan = AntigravityPlan(
            plan_id=f"AG-{incident_id[:8]}",
            incident_id=incident_id,
            created_at=_now(),
            reasoning=self._generate_plan_reasoning(raw_signals),
        )

        # Step 1: Signal Ingestor — always runs first
        plan.steps.append(AntigravityStep(
            step_id=1,
            agent=AgentRole.SIGNAL_INGESTOR,
            action="Ingest and normalize multi-source signals",
            reasoning=(
                f"Received {len(raw_signals.get('social_posts', []))} social media posts, "
                f"weather data, traffic data, and "
                f"{len(raw_signals.get('manual_reports', []))} manual reports. "
                "Signal Ingestor must process these first to extract structured data."
            ),
        ))

        # Step 2: Situation Analyst — runs after signals are normalized
        plan.steps.append(AntigravityStep(
            step_id=2,
            agent=AgentRole.SITUATION_ANALYST,
            action="Analyze crisis type, severity, and confidence",
            reasoning=(
                "Once signals are normalized, the Situation Analyst will classify "
                "the crisis type, assess severity (CRITICAL/HIGH/MEDIUM/LOW), "
                "calculate confidence, and check historical precedents at this location."
            ),
        ))

        # Step 3: Response Orchestrator — executes coordinated response
        plan.steps.append(AntigravityStep(
            step_id=3,
            agent=AgentRole.RESPONSE_ORCHESTRATOR,
            action="Execute coordinated emergency response actions",
            reasoning=(
                "Based on the situation assessment, the Response Orchestrator will "
                "execute appropriate actions: route updates, emergency dispatch, "
                "citizen alerts, and incident ticket creation. Actions are prioritized "
                "by severity level."
            ),
        ))

        logger.info(
            "Antigravity plan created: %s with %d steps for incident %s",
            plan.plan_id, len(plan.steps), incident_id,
        )
        return plan

    def _generate_plan_reasoning(self, raw_signals: dict) -> str:
        """Generate human-readable reasoning for the execution plan."""
        social_count = len(raw_signals.get("social_posts", []))
        manual_count = len(raw_signals.get("manual_reports", []))
        has_weather = bool(raw_signals.get("weather"))
        has_traffic = bool(raw_signals.get("traffic"))

        parts = [
            f"Antigravity received a crisis signal package containing "
            f"{social_count} social media posts",
        ]
        if manual_count:
            parts.append(f"{manual_count} manual field reports")
        if has_weather:
            parts.append("real-time weather data")
        if has_traffic:
            parts.append("traffic congestion data")

        reasoning = ", ".join(parts) + ". "
        reasoning += (
            "Planning a 3-step multi-agent pipeline: "
            "(1) Signal Ingestor normalizes raw data, "
            "(2) Situation Analyst classifies and assesses the crisis, "
            "(3) Response Orchestrator executes coordinated response actions. "
            "Each agent has specialized tools bound via LangChain ReAct pattern."
        )
        return reasoning

    def log_step_start(self, plan: AntigravityPlan, step_id: int) -> None:
        """Log the start of an Antigravity execution step."""
        step = next((s for s in plan.steps if s.step_id == step_id), None)
        if step:
            step.status = "running"
            step.started_at = _now()
            agent_info = self.agents[step.agent]
            tool_names = [t.name for t in agent_info.tools]

            self._execution_log.append({
                "type": "antigravity_step_start",
                "plan_id": plan.plan_id,
                "step_id": step_id,
                "agent": agent_info.name,
                "action": step.action,
                "tools_available": tool_names,
                "reasoning": step.reasoning,
                "timestamp": step.started_at,
            })

            logger.info(
                "[Antigravity] Step %d STARTED — %s | Tools: %s",
                step_id, agent_info.name, tool_names,
            )

    def log_step_complete(
        self, plan: AntigravityPlan, step_id: int,
        output_summary: str, tools_used: list[str] | None = None,
    ) -> None:
        """Log the completion of an Antigravity execution step."""
        step = next((s for s in plan.steps if s.step_id == step_id), None)
        if step:
            step.status = "complete"
            step.completed_at = _now()
            step.output_summary = output_summary
            step.tools_used = tools_used or []

            if step.started_at:
                try:
                    start = datetime.fromisoformat(step.started_at.replace("Z", "+00:00"))
                    end = datetime.fromisoformat(step.completed_at.replace("Z", "+00:00"))
                    step.duration_ms = (end - start).total_seconds() * 1000
                except Exception:
                    pass

            self._execution_log.append({
                "type": "antigravity_step_complete",
                "plan_id": plan.plan_id,
                "step_id": step_id,
                "agent": self.agents[step.agent].name,
                "output_summary": output_summary,
                "tools_used": step.tools_used,
                "duration_ms": step.duration_ms,
                "timestamp": step.completed_at,
            })

            logger.info(
                "[Antigravity] Step %d COMPLETE — %s (%.0fms)",
                step_id, output_summary[:80],
                step.duration_ms or 0,
            )

    def log_step_error(
        self, plan: AntigravityPlan, step_id: int, error: str,
    ) -> None:
        """Log an error in an Antigravity execution step."""
        step = next((s for s in plan.steps if s.step_id == step_id), None)
        if step:
            step.status = "error"
            step.error = error
            step.completed_at = _now()

            self._execution_log.append({
                "type": "antigravity_step_error",
                "plan_id": plan.plan_id,
                "step_id": step_id,
                "agent": self.agents[step.agent].name,
                "error": error,
                "timestamp": step.completed_at,
            })

            logger.error(
                "[Antigravity] Step %d ERROR — %s: %s",
                step_id, self.agents[step.agent].name, error,
            )

    def finalize_plan(self, plan: AntigravityPlan) -> dict:
        """Finalize the execution plan and return the trace summary."""
        all_complete = all(s.status == "complete" for s in plan.steps)
        plan.status = "complete" if all_complete else "error"
        plan.total_duration_ms = sum(
            s.duration_ms or 0 for s in plan.steps
        )

        summary = {
            "antigravity_plan_id": plan.plan_id,
            "incident_id": plan.incident_id,
            "status": plan.status,
            "total_duration_ms": plan.total_duration_ms,
            "planning_reasoning": plan.reasoning,
            "steps": [
                {
                    "step_id": s.step_id,
                    "agent": self.agents[s.agent].name,
                    "action": s.action,
                    "reasoning": s.reasoning,
                    "status": s.status,
                    "output_summary": s.output_summary,
                    "tools_used": s.tools_used,
                    "duration_ms": s.duration_ms,
                    "error": s.error,
                }
                for s in plan.steps
            ],
            "created_at": plan.created_at,
        }

        logger.info(
            "[Antigravity] Plan %s FINALIZED — %s (%.0fms total)",
            plan.plan_id, plan.status, plan.total_duration_ms,
        )
        return summary

    def get_workflow_config(self) -> dict:
        """Return the full Antigravity workflow configuration for inspection."""
        return {
            "orchestrator": "Google Antigravity",
            "version": "1.0.0",
            "workflow": "CIRO Crisis Intelligence Pipeline",
            "agents": {
                role.value: {
                    "name": agent.name,
                    "description": agent.description,
                    "tools": [t.name for t in agent.tools],
                    "capabilities": agent.capabilities,
                    "llm_provider": agent.llm_provider,
                }
                for role, agent in self.agents.items()
            },
            "tools": [
                {
                    "name": t.name,
                    "description": t.description,
                    "assigned_to": t.agent.value,
                }
                for t in self.tools
            ],
            "execution_flow": [
                "1. Signal Ingestor → normalize raw signals",
                "2. Situation Analyst → classify crisis & assess severity",
                "3. Response Orchestrator → execute coordinated response",
            ],
        }


# ═══════════════════════════════════════════════════════════════════
# Singleton instance
# ═══════════════════════════════════════════════════════════════════

antigravity = AntigravityOrchestrator()
