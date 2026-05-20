"""
CIRO In-Memory Incident Store.

Thread-safe, module-level singleton that holds all incident data
throughout the lifetime of the backend process.
"""

from datetime import datetime, timezone
import threading


class IncidentStore:
    """In-memory incident store backed by a plain dict with a lock."""

    def __init__(self) -> None:
        self._data: dict[str, dict] = {}
        self._lock = threading.Lock()

    # ------------------------------------------------------------------
    # Write operations
    # ------------------------------------------------------------------

    def create(self, incident_id: str, raw_signals: dict) -> None:
        """Create a new incident entry with status='processing'."""
        with self._lock:
            self._data[incident_id] = {
                "incident_id": incident_id,
                "raw_signals": raw_signals,
                "normalized_signals": {},
                "situation_assessment": {},
                "response_plan": {},
                "agent_trace": [],
                "crisis_type": "unknown",
                "severity": "unknown",
                "confidence": "unknown",
                "affected_area": "unknown",
                "status": "processing",
                "error": None,
                "created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
            }

    def update(self, incident_id: str, **kwargs) -> None:
        """Merge *kwargs* into the incident dict."""
        with self._lock:
            if incident_id in self._data:
                self._data[incident_id].update(kwargs)

    def append_trace(self, incident_id: str, trace_entry: dict) -> None:
        """Append a single trace entry to the agent_trace list."""
        with self._lock:
            if incident_id in self._data:
                self._data[incident_id]["agent_trace"].append(trace_entry)

    # ------------------------------------------------------------------
    # Read operations
    # ------------------------------------------------------------------

    def get(self, incident_id: str) -> dict | None:
        """Return the full incident dict, or None if not found."""
        with self._lock:
            entry = self._data.get(incident_id)
            return dict(entry) if entry else None

    def list_all(self) -> list[dict]:
        """Return summary-only dicts for every incident."""
        summary_keys = (
            "incident_id",
            "crisis_type",
            "severity",
            "confidence",
            "affected_area",
            "status",
            "created_at",
        )
        with self._lock:
            return [
                {k: inc.get(k, "") for k in summary_keys}
                for inc in self._data.values()
            ]

    def get_trace(self, incident_id: str) -> list[dict] | None:
        """Return the agent_trace list, or None if incident not found."""
        with self._lock:
            entry = self._data.get(incident_id)
            if entry is None:
                return None
            return list(entry["agent_trace"])


# ---------- module-level singleton ----------
incident_store = IncidentStore()
