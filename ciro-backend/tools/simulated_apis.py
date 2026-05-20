"""
CIRO Simulated APIs — data layer with real-API-first, mock-fallback.

`get_weather` tries the OpenWeatherMap live API when an
``OPENWEATHERMAP_API_KEY`` env var is set. On *any* failure it falls
back silently to the built-in mock data.

All other functions remain fully self-contained mock / simulation layers.
"""

import logging
import os
import random
from datetime import datetime, timezone

import httpx

logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════════════════
# OPENWEATHERMAP CONFIGURATION
# ═══════════════════════════════════════════════════════════════════

_OWM_BASE_URL = "https://api.openweathermap.org/data/2.5/weather"
_OWM_TIMEOUT = 5  # seconds


# ═══════════════════════════════════════════════════════════════════
# MOCK DATA
# ═══════════════════════════════════════════════════════════════════

WEATHER_DATA: dict[str, dict] = {
    "islamabad": {
        "temp_celsius": 34,
        "humidity_percent": 88,
        "rainfall_mm_last_hour": 45,
        "alert": "heavy_rain_warning",
        "alert_level": "HIGH",
    },
    "karachi": {
        "temp_celsius": 44,
        "humidity_percent": 82,
        "rainfall_mm_last_hour": 0,
        "alert": "heatwave_warning",
        "alert_level": "CRITICAL",
    },
    "lahore": {
        "temp_celsius": 39,
        "humidity_percent": 55,
        "rainfall_mm_last_hour": 0,
        "alert": "none",
        "alert_level": "LOW",
    },
}

TRAFFIC_DATA: dict[str, dict] = {
    "g10_islamabad": {
        "location_label": "G-10 Markaz, Islamabad",
        "congestion_percent": 94,
        "vehicles_stranded": 37,
        "incident_detected": True,
        "affected_roads": ["Fazl-e-Haq Road", "Islamabad Highway Slip"],
    },
    "mm_alam_lahore": {
        "location_label": "MM Alam Road, Lahore",
        "congestion_percent": 81,
        "vehicles_stranded": 12,
        "incident_detected": True,
        "affected_roads": ["MM Alam Road", "Gulberg III Main Boulevard"],
    },
    "saddar_karachi": {
        "location_label": "Saddar, Karachi",
        "congestion_percent": 88,
        "vehicles_stranded": 0,
        "incident_detected": True,
        "affected_roads": ["MA Jinnah Road", "Abdullah Haroon Road"],
    },
    "clifton_karachi": {
        "location_label": "Clifton, Karachi",
        "congestion_percent": 45,
        "vehicles_stranded": 0,
        "incident_detected": False,
        "affected_roads": [],
    },
}

ALTERNATE_ROUTES: dict[str, dict] = {
    "g10_islamabad": {
        "blocked_route": "G-10 Markaz → Fazl-e-Haq Road → Islamabad Highway",
        "alternate_1": "G-9 → Constitution Avenue → Blue Area (via Serena Hotel intersection)",
        "alternate_2": "G-11 → IJP Road → Peshawar Morr bypass",
        "alternate_3": "G-8 → Express Highway (eastbound)",
        "eta_saving_minutes": 22,
        "drivers_on_blocked_route": 847,
    },
    "mm_alam_lahore": {
        "blocked_route": "MM Alam Road main stretch",
        "alternate_1": "Hussain Chowk → Liberty Market → Jail Road",
        "alternate_2": "Kalma Chowk flyover → Ferozepur Road",
        "eta_saving_minutes": 14,
        "drivers_on_blocked_route": 430,
    },
    "saddar_karachi": {
        "blocked_route": "MA Jinnah Road through Saddar",
        "alternate_1": "Abdullah Haroon Road → Preedy Street → II Chundrigar Road",
        "alternate_2": "Depot Lines → Burns Road (northbound)",
        "eta_saving_minutes": 18,
        "drivers_on_blocked_route": 620,
    },
}

EMERGENCY_UNITS: dict[str, list[dict]] = {
    "islamabad": [
        {"name": "Rescue 1122 Unit 4", "type": "rescue", "eta_minutes": 7},
        {"name": "NDMA Rapid Response Team", "type": "disaster_management", "eta_minutes": 12},
        {"name": "CDA Emergency Services B", "type": "municipal", "eta_minutes": 9},
        {"name": "Islamabad Traffic Police QRF", "type": "traffic", "eta_minutes": 5},
    ],
    "karachi": [
        {"name": "EDHI Foundation Unit 12", "type": "rescue", "eta_minutes": 8},
        {"name": "KMC Emergency Response", "type": "municipal", "eta_minutes": 11},
        {"name": "Rangers Quick Reaction Force", "type": "security", "eta_minutes": 6},
        {"name": "PDMA Sindh Team", "type": "disaster_management", "eta_minutes": 15},
    ],
    "lahore": [
        {"name": "Rescue 1122 Unit 7", "type": "rescue", "eta_minutes": 6},
        {"name": "WASA Emergency Team", "type": "infrastructure", "eta_minutes": 10},
        {"name": "Punjab Police QRF", "type": "security", "eta_minutes": 8},
        {"name": "LDA Emergency Unit", "type": "municipal", "eta_minutes": 13},
    ],
}


# ═══════════════════════════════════════════════════════════════════
# OPENWEATHERMAP HELPERS
# ═══════════════════════════════════════════════════════════════════

def _owm_to_ciro_alert(weather_main: str, temp_celsius: float) -> tuple[str, str]:
    """
    Map an OpenWeatherMap ``weather[0].main`` condition + temperature
    to a CIRO ``(alert, alert_level)`` pair.
    """
    main_lower = weather_main.lower()

    # Rain / storm conditions
    if main_lower in ("thunderstorm",):
        return "thunderstorm_warning", "CRITICAL"
    if main_lower in ("rain", "drizzle"):
        return "heavy_rain_warning", "HIGH"

    # Extreme heat
    if temp_celsius >= 44:
        return "heatwave_warning", "CRITICAL"
    if temp_celsius >= 40:
        return "heatwave_warning", "HIGH"

    # Snow / unusual cold
    if main_lower == "snow":
        return "snow_warning", "HIGH"

    # Fog / haze
    if main_lower in ("fog", "mist", "haze", "smoke"):
        return "low_visibility_warning", "MEDIUM"

    return "none", "LOW"


def _fetch_owm(city: str) -> dict | None:
    """
    Call OpenWeatherMap Current Weather API.
    Returns a CIRO-shaped dict on success, or ``None`` on any failure.
    """
    api_key = os.getenv("OPENWEATHERMAP_API_KEY", "").strip()
    if not api_key:
        return None

    try:
        resp = httpx.get(
            _OWM_BASE_URL,
            params={
                "q": f"{city},PK",
                "appid": api_key,
                "units": "metric",
            },
            timeout=_OWM_TIMEOUT,
        )
        resp.raise_for_status()
        data = resp.json()

        temp = data["main"]["temp"]
        humidity = data["main"]["humidity"]
        # OWM rain is optional; key "1h" = mm in last hour
        rainfall = data.get("rain", {}).get("1h", 0)
        weather_main = data["weather"][0]["main"] if data.get("weather") else "Clear"

        alert, alert_level = _owm_to_ciro_alert(weather_main, temp)

        return {
            "temp_celsius": round(temp, 1),
            "humidity_percent": humidity,
            "rainfall_mm_last_hour": round(rainfall, 1),
            "alert": alert,
            "alert_level": alert_level,
            "source": "openweathermap_live",
            "owm_condition": weather_main,
        }

    except httpx.TimeoutException:
        logger.warning("OpenWeatherMap request timed out for '%s'", city)
    except httpx.HTTPStatusError as exc:
        logger.warning(
            "OpenWeatherMap HTTP %s for '%s': %s",
            exc.response.status_code, city, exc.response.text[:200],
        )
    except Exception as exc:
        logger.warning("OpenWeatherMap call failed for '%s': %s", city, exc)

    return None


# ═══════════════════════════════════════════════════════════════════
# LOOKUP HELPERS
# ═══════════════════════════════════════════════════════════════════

def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def get_weather(city: str) -> dict:
    """
    Return weather data for *city* (case-insensitive).

    Tries the live OpenWeatherMap API first; falls back to mock data
    if the API call fails or no API key is configured.
    """
    key = city.strip().lower()

    # ── try real API first ────────────────────────────────────────
    live = _fetch_owm(key)
    if live is not None:
        logger.info("Weather for '%s': live data from OpenWeatherMap", key)
        return {**live, "city": key, "timestamp": _now()}

    # ── fall back to mock ─────────────────────────────────────────
    if key in WEATHER_DATA:
        logger.info("Weather for '%s': using mock data (OWM unavailable)", key)
        return {**WEATHER_DATA[key], "city": key, "source": "mock", "timestamp": _now()}

    return {
        "city": key,
        "source": "mock",
        "error": f"No weather data available for '{city}'",
        "timestamp": _now(),
    }


def get_traffic(location_key: str) -> dict:
    """Return traffic data for *location_key*."""
    key = location_key.strip().lower()
    if key in TRAFFIC_DATA:
        return {**TRAFFIC_DATA[key], "location_key": key, "timestamp": _now()}
    return {
        "location_key": key,
        "error": f"No traffic data available for '{location_key}'",
        "timestamp": _now(),
    }


def get_alternate_routes(location_key: str) -> dict:
    """Return pre-computed alternate routes for *location_key*."""
    key = location_key.strip().lower()
    if key in ALTERNATE_ROUTES:
        return {**ALTERNATE_ROUTES[key], "location_key": key, "timestamp": _now()}
    return {
        "location_key": key,
        "error": f"No alternate routes available for '{location_key}'",
        "timestamp": _now(),
    }


def get_emergency_units(city: str) -> list[dict]:
    """Return available emergency units for *city*."""
    key = city.strip().lower()
    if key in EMERGENCY_UNITS:
        return [
            {**unit, "city": key, "timestamp": _now()}
            for unit in EMERGENCY_UNITS[key]
        ]
    return []


# ═══════════════════════════════════════════════════════════════════
# SIMULATION ACTIONS
# ═══════════════════════════════════════════════════════════════════

def simulate_route_update(location_key: str) -> dict:
    """Simulate pushing alternate routes to navigation apps."""
    key = location_key.strip().lower()
    route_info = ALTERNATE_ROUTES.get(key)

    if route_info is None:
        return {
            "action": "route_update",
            "status": "FAILED",
            "error": f"No route data for '{location_key}'",
            "timestamp": _now(),
        }

    alternates = [
        v for k, v in route_info.items() if k.startswith("alternate_")
    ]
    drivers = route_info.get("drivers_on_blocked_route", 0)

    return {
        "action": "route_update",
        "status": "EXECUTED",
        "blocked_route": route_info["blocked_route"],
        "alternate_routes": alternates,
        "drivers_notified": drivers,
        "notification_channels": [
            "Google Maps (simulated)",
            "Waze (simulated)",
            "CIRO Public Alert",
        ],
        "timestamp": _now(),
        "log": f"Route updated successfully. {drivers} drivers rerouted.",
    }


def simulate_emergency_dispatch(
    city: str, crisis_type: str, location: str
) -> dict:
    """Simulate dispatching emergency response units to a crisis."""
    units = get_emergency_units(city)
    dispatched = units[:2] if units else []
    min_eta = min((u["eta_minutes"] for u in dispatched), default=0)
    ticket_id = f"EMG-{random.randint(10000, 99999)}"

    return {
        "action": "emergency_dispatch",
        "status": "EXECUTED",
        "units_dispatched": dispatched,
        "incident_location": location,
        "crisis_type": crisis_type,
        "ticket_id": ticket_id,
        "total_eta_minutes": min_eta,
        "timestamp": _now(),
        "log": f"{len(dispatched)} units dispatched to {location}. ETA: {min_eta} minutes.",
    }


def simulate_send_alert(
    channel: str, area: str, message: str, crisis_type: str
) -> dict:
    """Simulate sending a public alert via the given channel."""
    recipients = random.randint(1500, 8000)

    return {
        "action": "public_alert",
        "status": "EXECUTED",
        "channel": channel,
        "target_area": area,
        "recipients_reached": recipients,
        "message_preview": message[:100],
        "crisis_type": crisis_type,
        "timestamp": _now(),
        "log": f"Alert sent to {recipients} recipients via {channel}.",
    }


def create_incident_ticket(
    crisis_type: str, severity: str, location: str, assessment: dict
) -> dict:
    """Create an official emergency incident ticket."""
    ticket_id = f"CIRO-{random.randint(1000, 9999)}"

    if severity == "CRITICAL":
        sla = 15
    elif severity == "HIGH":
        sla = 30
    else:
        sla = 60

    return {
        "action": "ticket_created",
        "status": "EXECUTED",
        "ticket_id": ticket_id,
        "crisis_type": crisis_type,
        "severity": severity,
        "location": location,
        "assigned_to": "Emergency Operations Center — Sector 3",
        "escalated_to": "NDMA National Ops Room" if severity == "CRITICAL" else None,
        "sla_minutes": sla,
        "timestamp": _now(),
        "log": "Incident ticket created and assigned.",
    }
