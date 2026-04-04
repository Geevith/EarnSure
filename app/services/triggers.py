"""
Dual-Key Consensus Oracle Engine (README §4.3)
"""
import asyncio
import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional
from decimal import Decimal

import httpx
from app.core.config import settings
from app.models.domain import DisruptionType

logger = logging.getLogger(__name__)

# --- Data Containers ---

@dataclass
class WeatherReading:
    rain_mm_per_hr: float
    temp_celsius: float
    condition: str
    source: str
    raw_response: dict
    fetched_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    @property
    def triggers_rain_threshold(self) -> bool:
        return self.rain_mm_per_hr >= settings.WEATHER_RAIN_THRESHOLD_MM

    @property
    def triggers_heat_threshold(self) -> bool:
        return self.temp_celsius >= settings.WEATHER_HEAT_THRESHOLD_C

    @property
    def disruption_type(self) -> Optional[DisruptionType]:
        if self.triggers_rain_threshold:
            return DisruptionType.MONSOON
        if self.triggers_heat_threshold:
            return DisruptionType.HEATWAVE
        return None

@dataclass
class NLPConfirmation:
    confidence: float
    label: str
    source_url: str
    snippet: str
    model_used: str
    raw_response: dict
    confirmed: bool = False

@dataclass
class ConsensusResult:
    primary_triggered: bool
    secondary_confirmed: bool
    consensus_achieved: bool
    disruption_type: Optional[DisruptionType]
    weather_reading: Optional[WeatherReading]
    nlp_confirmation: Optional[NLPConfirmation]
    trigger_value: float
    trigger_source: str

# --- Core Logic ---

async def fetch_weather_for_zone(lat: float, lng: float) -> WeatherReading:
    location = f"{lat:.5f},{lng:.5f}"
    url = f"{settings.WEATHER_API_BASE_URL}/{location}/today"
    params = {
        "unitGroup": "metric",
        "include": "current",
        "key": settings.WEATHER_API_KEY,
        "contentType": "json",
    }
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            resp = await client.get(url, params=params)
            resp.raise_for_status()
            data = resp.json()
            current = data.get("currentConditions", {})
            precip_mm = float(current.get("precip", 0) or 0)
            temp_c = float(current.get("temp", 0) or 0)
            now_ist_hour = max(datetime.now(timezone.utc).hour + 5, 1)
            rain_mm_per_hr = precip_mm / now_ist_hour
            return WeatherReading(rain_mm_per_hr, temp_c, current.get("conditions", "Unknown"), "visual_crossing", data)
        except Exception as exc:
            logger.error(f"Weather API error: {exc}")
            return WeatherReading(0.0, 30.0, "ERROR", "fallback", {})

async def confirm_disruption_via_nlp(city: str, disruption_type: DisruptionType) -> NLPConfirmation:
    # Auto-confirm for MVP demo
    return NLPConfirmation(0.95, "confirmed", "https://localnews.example.com", f"Severe {disruption_type.value} in {city}.", "bart-mnli", {}, True)

async def evaluate_dual_key_consensus(lat: float, lng: float, city: str, bypass_nlp: bool = False, force_trigger: bool = False) -> ConsensusResult:
    weather = await fetch_weather_for_zone(lat, lng)
    primary_triggered = weather.triggers_rain_threshold or weather.triggers_heat_threshold or force_trigger
    disruption_type = weather.disruption_type or (DisruptionType.MONSOON if force_trigger else None)

    if not primary_triggered:
        return ConsensusResult(False, False, False, None, weather, None, 0.0, "visual_crossing")

    if bypass_nlp or force_trigger:
        nlp = NLPConfirmation(1.0, "admin_bypass", "N/A", "Manual Demo Trigger", "bypass", {}, True)
    else:
        nlp = await confirm_disruption_via_nlp(city, disruption_type)

    return ConsensusResult(primary_triggered, nlp.confirmed, (primary_triggered and nlp.confirmed), disruption_type, weather, nlp, (weather.rain_mm_per_hr if not force_trigger else 28.5), "consensus_engine")

# --- The Missing Functions needed by webhooks.py ---

def evaluate_platform_outage_trigger(first_5xx_at: datetime, current_time: Optional[datetime] = None) -> bool:
    """Calculates if a platform outage has lasted > 45 minutes."""
    now = current_time or datetime.now(timezone.utc)
    duration_minutes = (now - first_5xx_at).total_seconds() / 60.0
    triggered = duration_minutes >= settings.PLATFORM_5XX_THRESHOLD_MINUTES
    logger.info(f"Platform outage check: {duration_minutes}min (Threshold: {settings.PLATFORM_5XX_THRESHOLD_MINUTES})")
    return triggered

async def check_traffic_gridlock(lat: float, lng: float) -> bool:
    """Placeholder for TomTom traffic check logic."""
    return False