"""
LangChain @tool wrappers around the simulated APIs.

These tools are bound to LangChain agents so the LLM can invoke them
via the standard tool-calling interface.
"""

import json

from langchain_core.tools import tool

from tools.simulated_apis import (
    get_weather,
    get_traffic,
    simulate_route_update,
    simulate_emergency_dispatch,
    simulate_send_alert,
    create_incident_ticket,
)
from tools.historical_data import get_historical_incidents


@tool
def weather_lookup_tool(city: str) -> str:
    """Get current weather data and alerts for a Pakistani city.
    Use this to check if weather conditions confirm a crisis signal.
    Input: city name (islamabad, karachi, or lahore)"""
    result = get_weather(city)
    return json.dumps(result)


@tool
def traffic_lookup_tool(location_key: str) -> str:
    """Get live traffic data for a specific location.
    Use this to check congestion levels and stranded vehicles.
    Input: location key like 'g10_islamabad', 'mm_alam_lahore', 'saddar_karachi'"""
    result = get_traffic(location_key)
    return json.dumps(result)


@tool
def route_update_tool(location_key: str) -> str:
    """Simulate pushing alternate routes to navigation apps.
    Use this when a road is confirmed blocked and drivers need rerouting.
    Input: location key of the blocked area"""
    result = simulate_route_update(location_key)
    return json.dumps(result)


@tool
def emergency_dispatch_tool(city: str, crisis_type: str, location: str) -> str:
    """Simulate dispatching emergency response units to a crisis.
    Use this when situation severity is HIGH or CRITICAL.
    Input: city, crisis_type, exact location"""
    result = simulate_emergency_dispatch(city, crisis_type, location)
    return json.dumps(result)


@tool
def alert_dispatch_tool(channel: str, area: str, message: str, crisis_type: str) -> str:
    """Simulate sending a public alert via SMS, push notification, or radio broadcast.
    Input: channel (SMS/PushNotification/RadioBroadcast), area, message, crisis_type"""
    result = simulate_send_alert(channel, area, message, crisis_type)
    return json.dumps(result)


@tool
def ticket_creation_tool(crisis_type: str, severity: str, location: str) -> str:
    """Create an official emergency incident ticket in the system.
    Always call this for HIGH and CRITICAL severity incidents.
    Input: crisis_type, severity, location"""
    result = create_incident_ticket(crisis_type, severity, location, {})
    return json.dumps(result)


@tool
def historical_data_tool(location_key: str, crisis_type: str) -> str:
    """Look up historical crisis incidents for a location to compare with current crisis.
    Use this to check if similar events have occurred before and assess risk.
    Input: location_key (e.g. 'g10_islamabad', 'saddar_karachi', 'mm_alam_lahore'), crisis_type (e.g. 'urban_flooding', 'heatwave', 'road_accident', 'infrastructure_failure', or 'all')"""
    result = get_historical_incidents(location_key, crisis_type)
    return json.dumps(result)


ALL_TOOLS = [
    weather_lookup_tool,
    traffic_lookup_tool,
    route_update_tool,
    emergency_dispatch_tool,
    alert_dispatch_tool,
    ticket_creation_tool,
    historical_data_tool,
]
