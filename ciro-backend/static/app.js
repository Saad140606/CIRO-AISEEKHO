// CIRO Web App Dashboard Client Script

// State variables
let map = null;
let currentEventSource = null;
let currentIncident = null;
let mapMarkers = [];
let mapLayers = [];

// API Host (auto-detect or fallback to localhost)
const API_HOST = window.location.origin;

// Scenario Locations
const SCENARIO_COORDS = {
    flooding_g10: { lat: 33.6844, lng: 72.9889, name: "G-10 Markaz, Islamabad", type: "flood" },
    heatwave_karachi: { lat: 24.8607, lng: 67.0011, name: "Saddar, Karachi", type: "heatwave" },
    accident_mm_alam: { lat: 31.5085, lng: 74.3516, name: "MM Alam Road, Lahore", type: "accident" },
    infra_failure_saddar: { lat: 24.8607, lng: 67.0011, name: "Saddar, Karachi", type: "infrastructure" }
};

document.addEventListener("DOMContentLoaded", () => {
    initTabs();
    initMap();
    initForms();
    loadDeveloperTraces();
    
    // Auto-refresh developer traces every 15 seconds
    setInterval(loadDeveloperTraces, 15000);
    
    document.getElementById("btn-refresh-traces").addEventListener("click", () => {
        loadDeveloperTraces();
    });
});

// ── TABS SYSTEM ──────────────────────────────────────────────────
function initTabs() {
    const tabButtons = document.querySelectorAll(".tab-btn");
    const tabContents = document.querySelectorAll(".tab-content");

    tabButtons.forEach(btn => {
        btn.addEventListener("click", () => {
            const targetTab = btn.getAttribute("data-tab");
            
            tabButtons.forEach(b => b.classList.remove("active"));
            tabContents.forEach(c => c.classList.remove("active"));
            
            btn.classList.add("active");
            document.getElementById(targetTab).classList.add("active");
            
            // Invalidate Leaflet map size when map tab is activated
            if (targetTab === "crisis-map" && map) {
                setTimeout(() => {
                    map.invalidateSize();
                }, 100);
            }
        });
    });
}

// ── LEAFLET MAP INITIALIZATION ─────────────────────────────────────
function initMap() {
    // Islamabad G-10 default center
    map = L.map("leaflet-map").setView([33.6844, 72.9889], 14);

    // Google Maps Standard Tile Layer (we apply CSS filter in style.css to make it dark mode)
    L.tileLayer("https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}", {
        maxZoom: 20,
        attribution: '&copy; Google Maps'
    }).addTo(map);

    // Setup map toggle buttons
    const btnBefore = document.getElementById("btn-map-before");
    const btnAfter = document.getElementById("btn-map-after");

    btnBefore.addEventListener("click", () => {
        btnBefore.classList.add("active");
        btnAfter.classList.remove("active");
        toggleMapLayerState("before");
    });

    btnAfter.addEventListener("click", () => {
        btnAfter.classList.add("active");
        btnBefore.classList.remove("active");
        toggleMapLayerState("after");
    });
}

function clearMap() {
    mapMarkers.forEach(m => map.removeLayer(m));
    mapLayers.forEach(l => map.removeLayer(l));
    mapMarkers = [];
    mapLayers = [];
}

function updateMapLayers(incident) {
    clearMap();
    
    const location = incident.location || {};
    const lat = location.latitude || 33.6844;
    const lng = location.longitude || 72.9889;
    const city = location.city || "Islamabad";
    const area = location.area || "G-10 Markaz";
    const crisisType = incident.crisis_type || "Urban Flooding";
    
    // Recenter map
    map.setView([lat, lng], 14.5);

    // Create custom pulsing rescue icon using divIcon
    const rescueIcon = L.divIcon({
        className: 'custom-div-icon',
        html: `<div style="background-color: #f39c12; width: 14px; height: 14px; border: 2px solid white; border-radius: 50%; box-shadow: 0 0 10px #f39c12;"></div>`,
        iconSize: [14, 14],
        iconAnchor: [7, 7]
    });

    // 1. Draw Crisis/Affected Zone Circle (Visible always)
    const crisisCircle = L.circle([lat, lng], {
        color: '#e74c3c',
        fillColor: '#e74c3c',
        fillOpacity: 0.15,
        radius: 600
    }).addTo(map);
    crisisCircle.bindPopup(`<b>Crisis Center</b><br>${crisisType} in ${area}, ${city}`);
    mapLayers.push(crisisCircle);

    // 2. Draw Flood overlay (specifically if it is a flood)
    if (crisisType.toLowerCase().includes("flood")) {
        const floodCircle = L.circle([lat + 0.001, lng - 0.002], {
            color: '#3498db',
            fillColor: '#3498db',
            fillOpacity: 0.2,
            radius: 400
        }).addTo(map);
        floodCircle.bindPopup("<b>Flooded Sector Area</b><br>Water Logging reported");
        mapLayers.push(floodCircle);
    }

    // 3. Draw Blocked and Rerouted paths (polylines)
    // Blocked route (Red, dashed)
    const blockedCoords = [
        [lat - 0.005, lng - 0.005],
        [lat, lng],
        [lat + 0.003, lng + 0.003]
    ];
    const blockedRoute = L.polyline(blockedCoords, {
        color: '#e74c3c',
        weight: 5,
        dashArray: '5, 10',
        opacity: 0.8
    });
    blockedRoute.bindPopup("<b>Main Route: Blocked</b><br>Vehicles stranded");
    mapLayers.push(blockedRoute);

    // Alternate route (Green, Solid)
    const altCoords = [
        [lat - 0.005, lng - 0.005],
        [lat - 0.003, lng + 0.005],
        [lat + 0.005, lng + 0.005],
        [lat + 0.003, lng + 0.003]
    ];
    const altRoute = L.polyline(altCoords, {
        color: '#2ecc71',
        weight: 5,
        opacity: 0.8
    });
    altRoute.bindPopup("<b>CIRO Alternate Route</b><br>Traffic diverted smoothly");
    mapLayers.push(altRoute);

    // 4. Place Emergency dispatch units (Markers)
    const units = [
        { offsetLat: 0.003, offsetLng: -0.004, title: "NDMA Rescue Unit 1", desc: "Coordinating drainage operations", eta: "6 mins" },
        { offsetLat: -0.002, offsetLng: 0.003, title: "Ambulance Team 3", desc: "Standby medical support", eta: "4 mins" },
        { offsetLat: 0.005, offsetLng: -0.001, title: "Traffic Police Wardens", desc: "Setting up road blockades and detours", eta: "3 mins" }
    ];

    units.forEach(u => {
        const marker = L.marker([lat + u.offsetLat, lng + u.offsetLng], { icon: rescueIcon });
        marker.bindPopup(`<b>${u.title}</b><br>${u.desc}<br>ETA: ${u.eta}`);
        mapMarkers.push(marker);
    });

    // Default layer state based on map toggle buttons
    const activeState = document.getElementById("btn-map-before").classList.contains("active") ? "before" : "after";
    toggleMapLayerState(activeState);
}

function toggleMapLayerState(state) {
    // Before: show blocked route, hide alternate route, hide rescue units
    // After: hide/dim blocked route, show alternate route, show rescue units
    mapLayers.forEach(layer => {
        if (layer instanceof L.Polyline && !(layer instanceof L.Polygon)) {
            const isBlocked = layer.options.color === '#e74c3c';
            if (state === "before") {
                if (isBlocked) {
                    map.addLayer(layer);
                    layer.setStyle({ opacity: 0.8 });
                } else {
                    map.removeLayer(layer);
                }
            } else {
                if (isBlocked) {
                    layer.setStyle({ opacity: 0.2 }); // Dim blocked route
                } else {
                    map.addLayer(layer); // Show alternate route
                }
            }
        }
    });

    mapMarkers.forEach(m => {
        if (state === "before") {
            map.removeLayer(m);
        } else {
            m.addTo(map);
        }
    });
}

// ── CUSTOM FORMS & TRIGGER API ──────────────────────────────────────
function initForms() {
    // Setup pre-built scenario buttons
    document.querySelectorAll(".scenario-btn").forEach(btn => {
        btn.addEventListener("click", () => {
            const scenarioId = btn.getAttribute("data-scenario");
            triggerScenario(scenarioId);
        });
    });

    // Setup Custom Signal form submit
    const form = document.getElementById("signal-form");
    form.addEventListener("submit", (e) => {
        e.preventDefault();
        
        const social = document.getElementById("social-posts").value.split("\n").filter(l => l.trim() !== "");
        const manual = document.getElementById("manual-reports").value.split("\n").filter(l => l.trim() !== "");
        const weather = document.getElementById("weather-override").value;
        const traffic = document.getElementById("traffic-override").value;

        triggerCustomSignal(social, manual, weather, traffic);
    });
}

function setProcessingState(isProcessing) {
    const statusBadge = document.getElementById("connection-status");
    const statusText = statusBadge.querySelector(".status-text");
    const submitBtn = document.querySelector(".submit-btn");
    const spinner = submitBtn.querySelector(".spinner");
    const btnTxt = submitBtn.querySelector(".btn-txt");
    const scenarioBtns = document.querySelectorAll(".scenario-btn");

    if (isProcessing) {
        statusBadge.className = "status-badge processing";
        statusText.textContent = "Orchestrating Pipeline...";
        submitBtn.disabled = true;
        spinner.classList.remove("hidden");
        btnTxt.textContent = "Processing Signal...";
        scenarioBtns.forEach(b => b.disabled = true);
    } else {
        statusBadge.className = "status-badge connected";
        statusText.textContent = "Response Dispatched";
        submitBtn.disabled = false;
        spinner.classList.add("hidden");
        btnTxt.textContent = "Launch Agentic Analysis";
        scenarioBtns.forEach(b => b.disabled = false);
    }
}

// Trigger Prebuilt Scenario
async function triggerScenario(scenarioId) {
    setProcessingState(true);
    resetDashboardViews();

    try {
        const response = await fetch(`${API_HOST}/api/simulate/scenario`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ scenario_id: scenarioId })
        });
        
        if (!response.ok) {
            throw new Error(`HTTP Error ${response.status}`);
        }
        
        const data = await response.json();
        const incidentId = data.incident_id;
        
        // Start streaming logs via SSE
        startSSEStream(incidentId);
        
    } catch (err) {
        alert(`Error triggering scenario: ${err.message}`);
        setProcessingState(false);
    }
}

// Trigger Custom Signal
async function triggerCustomSignal(social, manual, weather, traffic) {
    setProcessingState(true);
    resetDashboardViews();

    const requestBody = {
        social_posts: social
    };
    if (manual.length > 0) requestBody.manual_reports = manual;
    if (weather) requestBody.weather_override = weather;
    if (traffic) requestBody.traffic_override = traffic;

    try {
        const response = await fetch(`${API_HOST}/api/analyze`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            throw new Error(`HTTP Error ${response.status}`);
        }
        
        const data = await response.json();
        const incidentId = data.incident_id;
        
        startSSEStream(incidentId);
        
    } catch (err) {
        alert(`Error launching analysis: ${err.message}`);
        setProcessingState(false);
    }
}

// Reset views
function resetDashboardViews() {
    // Clear stream
    const logsContainer = document.getElementById("stream-logs");
    logsContainer.innerHTML = "";
    logsContainer.classList.add("hidden");
    document.getElementById("stream-empty").classList.add("hidden");
    
    // Reset Meta card
    const metaCard = document.getElementById("incident-meta");
    metaCard.classList.add("hidden");
    document.getElementById("meta-id").textContent = "N/A";
    const severityBadge = document.getElementById("meta-severity");
    severityBadge.className = "meta-badge";
    severityBadge.textContent = "PENDING";
    document.getElementById("meta-confidence").textContent = "N/A";
    
    const severityBanner = document.getElementById("severity-banner");
    severityBanner.className = "severity-banner hidden";
    severityBanner.innerHTML = "";

    // Clear Map
    clearMap();

    // Reset outcomes view
    document.getElementById("outcomes-data").classList.add("hidden");
    document.getElementById("outcomes-empty").classList.remove("hidden");
}

// ── SSE STREAMING AGENT LOGS ─────────────────────────────────────────
function startSSEStream(incidentId) {
    if (currentEventSource) {
        currentEventSource.close();
    }

    const logsContainer = document.getElementById("stream-logs");
    logsContainer.innerHTML = ""; // Clear log cards
    logsContainer.classList.remove("hidden");
    
    const metaCard = document.getElementById("incident-meta");
    metaCard.classList.remove("hidden");
    document.getElementById("meta-id").textContent = incidentId.substring(0, 8) + "...";

    let hasCompleted = false;
    let hasErrored = false;
    currentEventSource = new EventSource(`${API_HOST}/api/stream/${incidentId}`);

    function cleanupStream() {
        if (!currentEventSource) return;
        currentEventSource.close();
        currentEventSource = null;
        setProcessingState(false);
    }

    // Helper to fetch final state and update outcomes and maps
    async function fetchFinalIncidentState(id) {
        try {
            const response = await fetch(`${API_HOST}/api/incidents/${id}`);
            if (!response.ok) throw new Error(`HTTP Error ${response.status}`);
            const incident = await response.json();
            
            currentIncident = incident;
            updateOutcomesDashboard(incident);
            updateMapLayers(incident);
            
            // Switch to outcomes tab to "wow" the user!
            setTimeout(() => {
                const outcomesTabBtn = document.querySelector('[data-tab="outcomes"]');
                if (outcomesTabBtn) outcomesTabBtn.click();
            }, 1000);
        } catch (err) {
            console.error("Error fetching final incident state:", err);
        }
    }

    // 1. Initial creation event
    currentEventSource.addEventListener("incident_created", (event) => {
        try {
            const data = JSON.parse(event.data);
            console.log("SSE: Incident created", data);
            
            document.getElementById("stream-empty").classList.add("hidden");
            
            appendLogEntryCard({
                agent: "System",
                agent_name: "CIRO Ingestor",
                action: "Incident initialized successfully",
                content: `Created incident session ID: ${data.incident_id}\nStatus: Pipeline activated.`,
                timestamp: Date.now() / 1000
            });
        } catch (err) {
            console.error("Error parsing incident_created:", err);
        }
    });

    // 2. Real-time Multi-Agent Trace Updates
    currentEventSource.addEventListener("agent_update", (event) => {
        try {
            const data = JSON.parse(event.data);
            console.log("SSE: Agent update received", data);
            
            let statusAction = "Orchestrating logic...";
            if (data.status === "complete") {
                statusAction = "Step Execution Completed";
            } else if (data.status === "error") {
                statusAction = "Execution Error";
            }

            appendLogEntryCard({
                agent: data.agent || "Agent",
                agent_name: data.agent,
                action: statusAction,
                content: data.output_summary + (data.full_output && data.full_output.reasoning ? `\n\nReasoning Plan:\n${data.full_output.reasoning}` : ""),
                timestamp: data.timestamp || (Date.now() / 1000)
            });
        } catch (err) {
            console.error("Error parsing agent_update:", err);
        }
    });

    // 3. Raw Signal normalization complete
    currentEventSource.addEventListener("signal_processed", (event) => {
        try {
            const data = JSON.parse(event.data);
            console.log("SSE: Signals processed", data);
            
            appendLogEntryCard({
                agent: "System",
                agent_name: "Signal Ingestor Tool",
                action: "Multi-Source Signals Normalized",
                content: `Clustered signals: ${JSON.stringify(data.signal_clusters || data, null, 2)}`,
                timestamp: Date.now() / 1000
            });
        } catch (err) {
            console.error("Error parsing signal_processed:", err);
        }
    });

    // 4. Situation Assessment complete
    currentEventSource.addEventListener("situation_assessed", (event) => {
        try {
            const data = JSON.parse(event.data);
            console.log("SSE: Situation assessed", data);
            
            if (data.severity) {
                const sev = data.severity.toUpperCase();
                const severityBadge = document.getElementById("meta-severity");
                severityBadge.className = `meta-badge ${data.severity.toLowerCase()}`;
                severityBadge.textContent = sev;

                const severityBanner = document.getElementById("severity-banner");
                severityBanner.className = `severity-banner ${data.severity.toLowerCase()}`;
                severityBanner.innerHTML = `⚠️ <b>CRISIS LEVEL: ${sev}</b> — Coordinated response actions launched.`;
            }
            if (data.confidence) {
                const confVal = typeof data.confidence === "number" ? Math.round(data.confidence * 100) : parseInt(data.confidence);
                document.getElementById("meta-confidence").textContent = isNaN(confVal) ? data.confidence : `${confVal}%`;
            }

            appendLogEntryCard({
                agent: "Situation Analyst",
                agent_name: "Situation Analyst Agent",
                action: `Situation Assessed: ${data.crisis_type || 'Crisis'}`,
                content: `Severity: ${data.severity}\nConfidence: ${data.confidence}\nKey Findings: ${data.assessment_reasoning || 'No details provided.'}`,
                timestamp: Date.now() / 1000
            });
        } catch (err) {
            console.error("Error parsing situation_assessed:", err);
        }
    });

    // 5. Response plan orchestrated
    currentEventSource.addEventListener("response_complete", (event) => {
        try {
            const data = JSON.parse(event.data);
            console.log("SSE: Response completed", data);
            
            appendLogEntryCard({
                agent: "Response Orchestrator",
                agent_name: "Response Orchestrator Agent",
                action: "Emergency Response Plan Generated",
                content: `Response details:\n${JSON.stringify(data, null, 2)}`,
                timestamp: Date.now() / 1000
            });
            
            hasCompleted = true;
            fetchFinalIncidentState(incidentId);
        } catch (err) {
            console.error("Error parsing response_complete:", err);
        }
    });

    // 6. Specific error event
    currentEventSource.addEventListener("error", (event) => {
        try {
            let data;
            if (event.data) {
                try {
                    data = JSON.parse(event.data);
                } catch (parseErr) {
                    data = { error: event.data };
                }
            } else {
                data = { error: 'Unknown backend failure' };
            }

            console.error("SSE: Error event received", data);
            appendLogEntryCard({
                agent: "System",
                agent_name: "System Error Handler",
                action: "Pipeline Error Occurred",
                content: `Error: ${data.error || 'Unknown backend failure'}`,
                timestamp: Date.now() / 1000
            });
            hasErrored = true;

            fetchFinalIncidentState(incidentId).catch((fetchErr) => {
                console.error("Failed to fetch final incident state after error:", fetchErr);
            });
        } catch (err) {
            console.error("SSE error listener parsing failed:", err);
        }

        cleanupStream();
    });

    // 7. Explicit Done event (normal completion)
    currentEventSource.addEventListener("done", (event) => {
        console.log("SSE: Pipeline stream finished normally.");
        hasCompleted = true;
        cleanupStream();
        fetchFinalIncidentState(incidentId);
    });

    // Error handler for connection loss / transport failures
    currentEventSource.onerror = (err) => {
        console.warn("SSE stream state transition / connection dropped:", err);

        if (!currentEventSource || hasCompleted || hasErrored) {
            return;
        }

        // If the error event carries server-sent payload data, it is handled
        // by the dedicated addEventListener("error") callback above.
        if (err && typeof err.data !== "undefined" && err.data !== null) {
            return;
        }

        const readyState = currentEventSource.readyState;
        if (readyState !== EventSource.CLOSED) {
            return;
        }

        appendLogEntryCard({
            agent: "System",
            agent_name: "System Error Handler",
            action: "Pipeline Error Occurred",
            content: `Stream connection closed unexpectedly. Fetching latest incident state...`,
            timestamp: Date.now() / 1000
        });

        cleanupStream();

        hasCompleted = true;
        fetchFinalIncidentState(incidentId);
    };
}

function appendLogEntryCard(log) {
    const logsContainer = document.getElementById("stream-logs");
    
    const card = document.createElement("div");
    
    let agentClass = "system";
    const agentLower = (log.agent || "").toLowerCase();
    if (agentLower.includes("ingestor")) {
        agentClass = "ingestor";
    } else if (agentLower.includes("analyst")) {
        agentClass = "analyst";
    } else if (agentLower.includes("orchestrator")) {
        agentClass = "orchestrator";
    }
    card.className = `stream-card ${agentClass}`;
    
    const timestampValue = typeof log.timestamp === "string"
        ? new Date(log.timestamp)
        : new Date((log.timestamp || Date.now() / 1000) * 1000);
    const timeStr = isNaN(timestampValue.getTime())
        ? "Unknown time"
        : timestampValue.toLocaleTimeString();
    
    let contentHtml = "";
    if (log.content) {
        contentHtml = `<pre class="card-body">${escapeHTML(log.content)}</pre>`;
    }

    card.innerHTML = `
        <div class="card-header">
            <div class="card-role-info">
                <span class="avatar-dot"></span>
                <span class="agent-name">${escapeHTML(log.agent_name || log.agent)}</span>
            </div>
            <span class="card-timestamp">${timeStr}</span>
        </div>
        <div class="card-action">${escapeHTML(log.action || "Executing reasoning task...")}</div>
        ${contentHtml}
    `;
    
    logsContainer.appendChild(card);
    
    // Auto scroll container
    const rightPanel = document.querySelector(".right-panel");
    rightPanel.scrollTo({
        top: rightPanel.scrollHeight,
        behavior: 'smooth'
    });
}

function escapeHTML(str) {
    if (!str) return "";
    return str.replace(/[&<>'"]/g, 
        tag => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[tag] || tag)
    );
}

// ── OUTCOMES VISUALIZATION ──────────────────────────────────────────
function updateOutcomesDashboard(incident) {
    document.getElementById("outcomes-empty").classList.add("hidden");
    const outcomesData = document.getElementById("outcomes-data");
    outcomesData.classList.remove("hidden");

    const responsePlan = incident.response_plan || {};
    const beforeState = responsePlan.before_state || {};
    const afterState = responsePlan.after_state || {};

    const desc = document.getElementById("impact-description");
    desc.textContent = responsePlan.outcome_summary
        || `Response coordinated successfully for ${incident.crisis_type || 'this incident'}.`;

    const trafficBeforeRaw = beforeState.congestion_percent ?? 94;
    const trafficAfterRaw = afterState.congestion_percent ?? 38;
    const trafficBefore = typeof trafficBeforeRaw === "number" ? `${trafficBeforeRaw}%` : trafficBeforeRaw;
    const trafficAfter = typeof trafficAfterRaw === "number" ? `${trafficAfterRaw}%` : trafficAfterRaw;
    document.getElementById("metric-traffic-before").textContent = trafficBefore;
    document.getElementById("metric-traffic-after").textContent = trafficAfter;
    document.getElementById("metric-traffic-bar").style.width = trafficAfter;

    const teamsBefore = beforeState.emergency_teams_deployed != null ? `${beforeState.emergency_teams_deployed}` : "0";
    const teamsAfter = afterState.emergency_teams_deployed ?? responsePlan.emergency_teams_dispatched ?? "4";
    document.getElementById("metric-teams-before").textContent = teamsBefore;
    document.getElementById("metric-teams-after").textContent = `${teamsAfter}`;
    document.getElementById("metric-teams-bar").style.width = "100%";

    const alertsBefore = beforeState.citizens_alerted != null ? `${beforeState.citizens_alerted}` : "0";
    const alertsAfterRaw = afterState.citizens_alerted ?? responsePlan.citizens_alerted ?? "15,000";
    const alertsAfter = typeof alertsAfterRaw === "number" ? alertsAfterRaw.toLocaleString() : alertsAfterRaw;
    document.getElementById("metric-alerts-before").textContent = alertsBefore;
    document.getElementById("metric-alerts-after").textContent = alertsAfter;
    document.getElementById("metric-alerts-bar").style.width = "85%";

    const ticketsBefore = beforeState.incident_tickets != null ? `${beforeState.incident_tickets}` : "0";
    const ticketsAfterValue = afterState.incident_tickets ?? responsePlan.incident_tickets ?? (responsePlan.ticket_created ? 1 : 0);
    const ticketsAfter = `${ticketsAfterValue}`;
    document.getElementById("metric-tickets-before").textContent = ticketsBefore;
    document.getElementById("metric-tickets-after").textContent = ticketsAfter;
    document.getElementById("metric-tickets-bar").style.width = ticketsAfter === "1" ? "100%" : "50%";

    const timeline = document.getElementById("action-timeline");
    timeline.innerHTML = "";

    const events = [
        { time: "T+0:00", desc: "Crisis signal ingested from English/Roman Urdu inputs" },
        { time: "T+0:02", desc: "Signal Ingestor agent completed multi-signal semantic clustering" },
        { time: "T+0:05", desc: `Situation Analyst classified emergency: ${incident.crisis_type || 'unknown'} (Severity: ${incident.severity || 'unknown'})` },
        { time: "T+0:07", desc: `Response Orchestrator generated the first response plan and dispatch guidance.` },
        { time: "T+0:09", desc: `Alternate routes and alert messaging were prepared for affected areas.` },
        { time: "T+0:10", desc: `Crisis ticketing and escalation protocols were executed.` }
    ];

    events.forEach(ev => {
        const li = document.createElement("li");
        li.className = "timeline-event";
        li.innerHTML = `
            <div class="timeline-dot"></div>
            <span class="timeline-time">${ev.time}</span>
            <span class="timeline-desc">${ev.desc}</span>
        `;
        timeline.appendChild(li);
    });
}

// ── GOOGLE ANTIGRAVITY DEV TRACES ──────────────────────────────────
async function loadDeveloperTraces() {
    const terminal = document.getElementById("terminal-body");
    
    try {
        const response = await fetch(`${API_HOST}/api/antigravity/traces`);
        if (!response.ok) throw new Error("API Offline");
        const data = await response.json();
        
        if (data.status !== "success" || !data.traces || data.traces.length === 0) {
            terminal.innerHTML = `<div class="terminal-line system">[OK] Google Antigravity developer agent traces initialized. Waiting for background logs...</div>`;
            return;
        }

        // Clear
        terminal.innerHTML = "";

        data.traces.forEach(step => {
            const line = document.createElement("div");
            line.className = "terminal-step";

            const timeStr = step.created_at ? new Date(step.created_at).toLocaleTimeString() : "";
            const timeSpan = timeStr ? `<span class="term-time">${timeStr}</span>` : "";

            let sourceTag = "";
            let contentBody = "";

            if (step.source === "USER_EXPLICIT" || step.type === "USER_INPUT") {
                sourceTag = `<span class="term-tag tag-user">USER</span>`;
                contentBody = `<span class="terminal-line user">${escapeHTML(step.content)}</span>`;
            } else if (step.source === "MODEL") {
                sourceTag = `<span class="term-tag tag-model">AGENT</span>`;
                
                let thinkHtml = "";
                if (step.thinking) {
                    thinkHtml = `<div class="term-think">&gt; Thinking: ${escapeHTML(step.thinking)}</div>`;
                }

                let toolsHtml = "";
                if (step.tool_calls && step.tool_calls.length > 0) {
                    toolsHtml = step.tool_calls.map(tc => {
                        const args = tc.arguments ? JSON.stringify(tc.arguments) : "";
                        return `<div class="term-tool-call">⚙️ tool_call: ${escapeHTML(tc.toolAction || tc.ServerName + '/' + tc.ToolName)} (${escapeHTML(args)})</div>`;
                    }).join("");
                }

                let contentHtml = "";
                if (step.content) {
                    contentHtml = `<div class="terminal-line model">${escapeHTML(step.content)}</div>`;
                }

                contentBody = `
                    ${thinkHtml}
                    ${toolsHtml}
                    ${contentHtml}
                `;
            } else {
                sourceTag = `<span class="term-tag tag-system">SYSTEM</span>`;
                contentBody = `<span class="terminal-line system">${escapeHTML(step.content)}</span>`;
            }

            line.innerHTML = `
                ${timeSpan}
                ${sourceTag} Step #${step.step_index || 0}
                <div style="margin-top: 6px;">${contentBody}</div>
            `;

            terminal.appendChild(line);
        });

        // Scroll terminal to bottom
        terminal.scrollTop = terminal.scrollHeight;

    } catch (err) {
        terminal.innerHTML = `<div class="terminal-line danger">❌ Error fetching Google Antigravity developer traces: ${err.message}</div>`;
    }
}
