"""
Policy endpoints:
  POST /policies/quote          — Get dynamic premium quote for a zone
  POST /policies/purchase       — Buy weekly policy (validates device + creates policy)
  GET  /policies/active/{rider} — Check active policy and live disruption status
  GET  /policies/{policy_id}    — Retrieve specific policy
  GET  /policies/rider/{rider}  — List all policies for a rider
"""

import logging
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

import h3 as h3lib
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import get_current_rider
from app.db.session import get_db
from app.models.domain import (
    ClaimStatus,
    DeviceFingerprint,
    DisruptionEvent,
    DisruptionEventStatus,
    FraudRiskLevel,
    HexZone,
    Policy,
    PolicyStatus,
    Rider,
    RiderStatus,
)
from app.schemas.api import (
    ActivePolicyCheckResponse,
    PolicyListResponse,
    PolicyPurchaseRequest,
    PolicyResponse,
    RiderRiskProfileResponse,
    SuccessResponse,
    ZoneLookupRequest,
    ZoneLookupResponse,
)
from app.services.pricing import calculate_max_payout, calculate_weekly_premium

router = APIRouter(prefix="/policies", tags=["Policies"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _get_or_create_hex_zone(db: AsyncSession, h3_index: str) -> HexZone:
    """Fetches an existing HexZone or scaffolds a new one from H3 metadata."""
    result = await db.execute(
        select(HexZone).where(HexZone.h3_index == h3_index)
    )
    zone = result.scalar_one_or_none()
    if zone:
        return zone

    # Auto-create zone scaffold (production: zones pre-seeded via migration)
    lat, lng = h3lib.cell_to_latlng(h3_index)
    from geoalchemy2.elements import WKTElement
    centroid_wkt = f"POINT({lng} {lat})"

    zone = HexZone(
        h3_index=h3_index,
        city="unknown",
        zone_risk_score=Decimal("0.500"),
        monsoon_risk=Decimal("0.500"),
        heat_risk=Decimal("0.500"),
        traffic_risk=Decimal("0.500"),
        centroid=WKTElement(centroid_wkt, srid=4326),
    )
    db.add(zone)
    await db.flush()
    return zone


def _analyse_device_fingerprint(payload) -> tuple[FraudRiskLevel, Decimal, dict]:
    """
    Edge-AI Zero-Trust Fusion (README §4.2 / §6.2).
    Analyses device physics payload submitted from Flutter SDK.
    Returns (fraud_risk_level, fraud_score, signals_dict).

    Detection signals:
      1. Flat sensor (dead 0Hz vibration → GPS spoofer)
      2. GPS accuracy too perfect (< GPS_ACCURACY_SPOOF_THRESHOLD_M)
      3. AC charging while supposedly stranded outdoors
      4. BSSID farm detection (deferred to clustering task — flagged here if known)
    """
    from app.core.config import settings

    signals = {}
    score = 0.0

    # Signal 1: Flat accelerometer (spoofing farm)
    flat = payload.accelerometer_magnitude_hz < settings.VIBRATION_FLAT_THRESHOLD_HZ
    signals["is_flat_sensor"] = flat
    if flat:
        score += 0.40

    # Signal 2: Suspiciously perfect GPS lock
    gps_spoofed = (
        payload.gps_accuracy_meters is not None
        and payload.gps_accuracy_meters < settings.GPS_ACCURACY_SPOOF_THRESHOLD_M
        and not payload.gyroscope_active
    )
    signals["is_gps_spoofed"] = gps_spoofed
    if gps_spoofed:
        score += 0.35

    # Signal 3: AC charging anomaly (wall outlet while claiming to be outdoors in flood)
    ac_anomaly = (
        payload.is_charging
        and payload.charging_type == "ac"
        and payload.battery_level_pct >= 95
    )
    signals["is_ac_charging_anomaly"] = ac_anomaly
    if ac_anomaly:
        score += 0.20

    # Signal 4: No gyroscope activity (stationary spoofing device)
    if not payload.gyroscope_active and flat:
        score += 0.05

    signals["fraud_score"] = round(score, 4)
    signals["is_bssid_farm"] = False  # Resolved later by clustering task

    score_decimal = Decimal(str(round(score, 4)))

    if score >= 0.60:
        risk = FraudRiskLevel.HIGH
    elif score >= 0.30:
        risk = FraudRiskLevel.MEDIUM
    else:
        risk = FraudRiskLevel.LOW

    return risk, score_decimal, signals


# ---------------------------------------------------------------------------
# Zone Lookup
# ---------------------------------------------------------------------------

@router.post("/zone-lookup", response_model=ZoneLookupResponse)
async def zone_lookup(
    body: ZoneLookupRequest,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_rider),
):
    """Resolve lat/lng to H3 index and return zone risk + premium estimate."""
    h3_index = h3lib.latlng_to_cell(body.lat, body.lng, resolution=8)

    zone = await _get_or_create_hex_zone(db, h3_index)

    # Minimal rider proxy for quote (no streak, baseline claims factor)
    from app.models.domain import Platform
    dummy_rider = Rider(
        id=UUID("00000000-0000-0000-0000-000000000000"),
        phone="0000000000",
        name="Quote",
        platform=Platform.ZOMATO,
        city=zone.city or "unknown",
        historical_claims_factor=Decimal("1.0"),
        avg_hourly_rate_inr=Decimal("200.00"),
        consecutive_streak_weeks=0,
    )
    pricing = calculate_weekly_premium(dummy_rider, zone)

    from app.schemas.api import HexZoneResponse
    return ZoneLookupResponse(
        h3_index=h3_index,
        zone=HexZoneResponse.model_validate(zone),
        weekly_premium_estimate_inr=pricing.weekly_premium_inr,
    )


# ---------------------------------------------------------------------------
# Premium Quote (rider-personalised)
# ---------------------------------------------------------------------------

@router.get("/quote/{rider_id}", response_model=RiderRiskProfileResponse)
async def get_premium_quote(
    rider_id: UUID,
    h3_index: str,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_rider),
):
    """Returns personalised premium quote for a rider in a specific H3 zone."""
    rider_result = await db.execute(select(Rider).where(Rider.id == rider_id))
    rider = rider_result.scalar_one_or_none()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")

    zone = await _get_or_create_hex_zone(db, h3_index)
    pricing = calculate_weekly_premium(rider, zone)

    return RiderRiskProfileResponse(
        rider_id=rider_id,
        risk_score=pricing.risk_score_composite,
        weekly_premium_inr=pricing.weekly_premium_inr,
        disruption_probability=pricing.disruption_probability,
        zone_risk=pricing.zone_risk,
        historical_claims_factor=pricing.historical_claims_factor,
        streak_discount_applied=pricing.streak_discount_applied,
        streak_discount_pct=pricing.streak_discount_pct * 100,
        calculation_breakdown=pricing.breakdown,
    )


# ---------------------------------------------------------------------------
# Purchase Policy
# ---------------------------------------------------------------------------

@router.post("/purchase", response_model=PolicyResponse, status_code=status.HTTP_201_CREATED)
async def purchase_policy(
    body: PolicyPurchaseRequest,
    db: AsyncSession = Depends(get_db),
    current_user: dict = Depends(get_current_rider),
):
    """
    Buy a weekly parametric insurance policy.

    Flow:
      1. Validate rider exists and is active
      2. Analyse device fingerprint (Edge-AI fraud gate)
      3. Block HIGH fraud risk at purchase (prevents fraud farm enrollments)
      4. Check for existing active policy (no overlapping policies)
      5. Calculate premium via XGBoost engine
      6. Create Policy + DeviceFingerprint records
      7. Increment HexZone.active_policy_count
    """
    # 1. Load rider
    rider_result = await db.execute(select(Rider).where(Rider.id == body.rider_id))
    rider = rider_result.scalar_one_or_none()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")
    if rider.status not in (RiderStatus.ACTIVE,):
        raise HTTPException(
            status_code=403,
            detail=f"Rider account status '{rider.status.value}' does not permit policy purchase",
        )

    # 2. Analyse device fingerprint
    fraud_risk, fraud_score, fraud_signals = _analyse_device_fingerprint(body.device_fingerprint)

    # 3. Hard block HIGH risk at purchase time
    if fraud_risk == FraudRiskLevel.HIGH:
        logger.warning("Policy purchase blocked — HIGH fraud risk rider=%s", body.rider_id)
        raise HTTPException(
            status_code=403,
            detail="Policy purchase declined. Please contact support.",
        )

    # Persist device fingerprint
    fp = DeviceFingerprint(
        rider_id=body.rider_id,
        device_id=body.device_fingerprint.device_id,
        device_model=body.device_fingerprint.device_model,
        os_version=body.device_fingerprint.os_version,
        app_version=body.device_fingerprint.app_version,
        gps_lat=Decimal(str(body.device_fingerprint.gps_lat)),
        gps_lng=Decimal(str(body.device_fingerprint.gps_lng)),
        gps_accuracy_meters=Decimal(str(body.device_fingerprint.gps_accuracy_meters)),
        gps_speed_mps=Decimal(str(body.device_fingerprint.gps_speed_mps)) if body.device_fingerprint.gps_speed_mps else None,
        accelerometer_magnitude_hz=Decimal(str(body.device_fingerprint.accelerometer_magnitude_hz)),
        gyroscope_active=body.device_fingerprint.gyroscope_active,
        is_charging=body.device_fingerprint.is_charging,
        battery_level_pct=body.device_fingerprint.battery_level_pct,
        charging_type=body.device_fingerprint.charging_type,
        cell_tower_id=body.device_fingerprint.cell_tower_id,
        wifi_bssid=body.device_fingerprint.wifi_bssid,
        wifi_ssid=body.device_fingerprint.wifi_ssid,
        is_gps_spoofed=fraud_signals["is_gps_spoofed"],
        is_flat_sensor=fraud_signals["is_flat_sensor"],
        is_ac_charging_anomaly=fraud_signals["is_ac_charging_anomaly"],
        is_bssid_farm=False,
        fraud_risk_level=fraud_risk,
        fraud_score=fraud_score,
    )
    db.add(fp)
    await db.flush()

    # 4. Check for existing active policy in same zone
    now = datetime.now(timezone.utc)
    existing_policy_result = await db.execute(
        select(Policy).where(
            and_(
                Policy.rider_id == body.rider_id,
                Policy.status == PolicyStatus.ACTIVE,
                Policy.end_date >= now,
            )
        )
    )
    existing_policy = existing_policy_result.scalar_one_or_none()
    if existing_policy:
        raise HTTPException(
            status_code=409,
            detail=f"Active policy already exists (id: {existing_policy.id}). "
                   "Cancel or let it expire before purchasing a new one.",
        )

    # 5. Get/create zone and calculate premium
    zone = await _get_or_create_hex_zone(db, body.h3_index)
    if body.rider_id and rider.city != "unknown":
        zone.city = rider.city

    pricing = calculate_weekly_premium(rider, zone)
    max_payout = calculate_max_payout(rider, settings_duration_hours())

    # 6. Create Policy
    start = now
    end = now + timedelta(days=7)
    policy = Policy(
        rider_id=body.rider_id,
        hex_zone_id=zone.id,
        platform=body.platform,
        start_date=start,
        end_date=end,
        weekly_premium_inr=pricing.weekly_premium_inr,
        max_payout_inr=max_payout,
        status=PolicyStatus.ACTIVE,
        base_rate_used=pricing.base_rate,
        disruption_prob_used=Decimal(str(pricing.disruption_probability)),
        zone_risk_used=Decimal(str(pricing.zone_risk)),
        historical_claims_factor_used=pricing.historical_claims_factor,
        streak_discount_applied=pricing.streak_discount_applied,
    )
    db.add(policy)

    # Update UPI if provided
    if body.upi_id:
        rider.upi_id = body.upi_id

    # 7. Increment zone active policy count
    zone.active_policy_count += 1

    # Update streak
    rider.consecutive_streak_weeks += 1

    await db.flush()
    await db.refresh(policy)

    logger.info(
        "Policy purchased: rider=%s zone=%s premium=₹%s",
        body.rider_id, body.h3_index, pricing.weekly_premium_inr,
    )
    return PolicyResponse.model_validate(policy)


def settings_duration_hours() -> float:
    from app.core.config import settings
    return settings.DISRUPTION_WINDOW_HOURS


# ---------------------------------------------------------------------------
# Active Policy Check
# ---------------------------------------------------------------------------

@router.get("/active/{rider_id}", response_model=ActivePolicyCheckResponse)
async def check_active_policy(
    rider_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_rider),
):
    """
    Called by Flutter SDK on app open to show 'Insurance Active: ₹98/week'.
    Also returns live disruption status for the rider's zone.
    """
    now = datetime.now(timezone.utc)
    policy_result = await db.execute(
        select(Policy)
        .options(selectinload(Policy.hex_zone))
        .where(
            and_(
                Policy.rider_id == rider_id,
                Policy.status == PolicyStatus.ACTIVE,
                Policy.end_date >= now,
            )
        )
        .order_by(Policy.start_date.desc())
        .limit(1)
    )
    policy = policy_result.scalar_one_or_none()

    if not policy:
        return ActivePolicyCheckResponse(
            rider_id=rider_id,
            has_active_policy=False,
            policy=None,
            current_disruption_active=False,
            disruption_event_id=None,
        )

    # Check live disruption in this zone
    disruption_result = await db.execute(
        select(DisruptionEvent)
        .where(
            and_(
                DisruptionEvent.hex_zone_id == policy.hex_zone_id,
                DisruptionEvent.status.in_([
                    DisruptionEventStatus.CONFIRMED,
                    DisruptionEventStatus.PAYOUTS_PROCESSING,
                ]),
            )
        )
        .order_by(DisruptionEvent.created_at.desc())
        .limit(1)
    )
    active_event = disruption_result.scalar_one_or_none()

    return ActivePolicyCheckResponse(
        rider_id=rider_id,
        has_active_policy=True,
        policy=PolicyResponse.model_validate(policy),
        current_disruption_active=active_event is not None,
        disruption_event_id=active_event.id if active_event else None,
    )


# ---------------------------------------------------------------------------
# Retrieve / List
# ---------------------------------------------------------------------------

@router.get("/{policy_id}", response_model=PolicyResponse)
async def get_policy(
    policy_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_rider),
):
    result = await db.execute(select(Policy).where(Policy.id == policy_id))
    policy = result.scalar_one_or_none()
    if not policy:
        raise HTTPException(status_code=404, detail="Policy not found")
    return PolicyResponse.model_validate(policy)


@router.get("/rider/{rider_id}", response_model=PolicyListResponse)
async def list_rider_policies(
    rider_id: UUID,
    limit: int = 20,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(get_current_rider),
):
    result = await db.execute(
        select(Policy)
        .where(Policy.rider_id == rider_id)
        .order_by(Policy.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    policies = result.scalars().all()
    return PolicyListResponse(
        items=[PolicyResponse.model_validate(p) for p in policies],
        total=len(policies),
    )