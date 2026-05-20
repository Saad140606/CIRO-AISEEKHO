"""
CIRO Historical Incident Data — simulated past crisis records.

Provides historical context for the Situation Analyst agent to
compare current crises with past events and estimate severity.
"""

from datetime import datetime, timezone


HISTORICAL_INCIDENTS: dict[str, list[dict]] = {
    "g10_islamabad": [
        {
            "date": "2024-07-15",
            "type": "urban_flooding",
            "severity": "HIGH",
            "response_time_min": 45,
            "people_affected": 2300,
            "vehicles_damaged": 89,
            "resolution_hours": 8,
            "summary": "Monsoon flash flooding submerged G-10 Markaz. 37 vehicles stranded on Fazl-e-Haq Road. NDMA deployed 3 teams.",
        },
        {
            "date": "2023-08-22",
            "type": "urban_flooding",
            "severity": "CRITICAL",
            "response_time_min": 60,
            "people_affected": 5100,
            "vehicles_damaged": 210,
            "resolution_hours": 14,
            "summary": "Record rainfall (78mm/hr) caused severe flooding across G-10 and G-9. Multiple rescues. CDA drainage system overwhelmed.",
        },
        {
            "date": "2024-09-03",
            "type": "urban_flooding",
            "severity": "MEDIUM",
            "response_time_min": 30,
            "people_affected": 800,
            "vehicles_damaged": 25,
            "resolution_hours": 4,
            "summary": "Moderate waterlogging after sustained rainfall. G-10/4 residential area affected. Drainage cleared within 4 hours.",
        },
        {
            "date": "2025-03-11",
            "type": "road_blockage",
            "severity": "MEDIUM",
            "response_time_min": 20,
            "people_affected": 1200,
            "vehicles_damaged": 0,
            "resolution_hours": 3,
            "summary": "Construction debris blocked main road near G-10 Markaz. Traffic diverted via G-9 for 3 hours.",
        },
    ],
    "saddar_karachi": [
        {
            "date": "2024-06-20",
            "type": "heatwave",
            "severity": "CRITICAL",
            "response_time_min": 90,
            "people_affected": 15000,
            "vehicles_damaged": 0,
            "resolution_hours": 72,
            "summary": "3-day heatwave peaked at 49C. 23 heat stroke fatalities. EDHI set up 45 cooling stations across Saddar.",
        },
        {
            "date": "2023-06-15",
            "type": "heatwave",
            "severity": "HIGH",
            "response_time_min": 120,
            "people_affected": 8000,
            "vehicles_damaged": 0,
            "resolution_hours": 48,
            "summary": "Sustained heat 44C for 48 hours. Hospital overflows in Civil Hospital Karachi. Power outages worsened situation.",
        },
        {
            "date": "2024-11-05",
            "type": "infrastructure_failure",
            "severity": "HIGH",
            "response_time_min": 35,
            "people_affected": 3200,
            "vehicles_damaged": 15,
            "resolution_hours": 18,
            "summary": "Major water main burst on MA Jinnah Road. 200m stretch subsided. KWSB repair took 18 hours.",
        },
        {
            "date": "2025-01-18",
            "type": "infrastructure_failure",
            "severity": "CRITICAL",
            "response_time_min": 25,
            "people_affected": 7500,
            "vehicles_damaged": 45,
            "resolution_hours": 36,
            "summary": "Gas pipeline rupture near Abdullah Haroon Road. 500m evacuation zone. Rangers deployed for crowd control.",
        },
    ],
    "mm_alam_lahore": [
        {
            "date": "2024-12-10",
            "type": "road_accident",
            "severity": "HIGH",
            "response_time_min": 15,
            "people_affected": 1800,
            "vehicles_damaged": 5,
            "resolution_hours": 4,
            "summary": "4-vehicle pile-up near Hussain Chowk end. 3 casualties. Rescue 1122 responded in 15 minutes.",
        },
        {
            "date": "2024-08-28",
            "type": "road_accident",
            "severity": "MEDIUM",
            "response_time_min": 12,
            "people_affected": 900,
            "vehicles_damaged": 3,
            "resolution_hours": 2,
            "summary": "Bus-car collision near Liberty Market junction. Minor injuries. Traffic diverted via Jail Road.",
        },
        {
            "date": "2023-11-20",
            "type": "road_accident",
            "severity": "CRITICAL",
            "response_time_min": 8,
            "people_affected": 4500,
            "vehicles_damaged": 12,
            "resolution_hours": 7,
            "summary": "Tanker overturned on MM Alam Road. Fuel spill hazard. Fire brigade, Rescue 1122, and Punjab Police responded.",
        },
    ],
    "clifton_karachi": [
        {
            "date": "2024-08-12",
            "type": "urban_flooding",
            "severity": "MEDIUM",
            "response_time_min": 50,
            "people_affected": 1500,
            "vehicles_damaged": 30,
            "resolution_hours": 6,
            "summary": "Coastal flooding after high tide plus rainfall. Sea View area waterlogged. KMC pumps deployed.",
        },
    ],
}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def get_historical_incidents(location_key: str, crisis_type: str) -> dict:
    """
    Return historical incidents for a location, optionally filtered by crisis type.
    """
    key = location_key.strip().lower()
    all_incidents = HISTORICAL_INCIDENTS.get(key, [])

    if crisis_type and crisis_type.lower() != "all":
        matched = [i for i in all_incidents if i["type"] == crisis_type.lower()]
    else:
        matched = all_incidents

    if not matched:
        return {
            "location_key": key,
            "crisis_type": crisis_type,
            "total_past_incidents": 0,
            "incidents": [],
            "risk_assessment": "LOW - No similar historical incidents on record.",
            "timestamp": _now(),
        }

    avg_response = sum(i["response_time_min"] for i in matched) / len(matched)
    avg_affected = sum(i["people_affected"] for i in matched) / len(matched)
    severities = [i["severity"] for i in matched]
    critical_count = severities.count("CRITICAL")
    high_count = severities.count("HIGH")

    if critical_count >= 2:
        risk = "VERY HIGH - Multiple CRITICAL incidents at this location. Expect severe impact."
    elif critical_count >= 1 or high_count >= 2:
        risk = "HIGH - Location has history of serious incidents. Rapid response recommended."
    elif high_count >= 1:
        risk = "MEDIUM - Some past high-severity events. Monitor closely."
    else:
        risk = "LOW - Historical incidents were minor."

    return {
        "location_key": key,
        "crisis_type": crisis_type,
        "total_past_incidents": len(matched),
        "incidents": matched,
        "average_response_time_min": round(avg_response, 1),
        "average_people_affected": round(avg_affected),
        "risk_assessment": risk,
        "recommendation": f"Based on {len(matched)} past {crisis_type} events, average response time was {avg_response:.0f} min affecting {avg_affected:.0f} people.",
        "timestamp": _now(),
    }
