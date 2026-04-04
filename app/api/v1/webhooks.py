"""
Webhook handlers for Zomato and Swiggy platform dispatch events.

Logic (README §4.1):
  - Monitor for HTTP 5xx status codes from dispatch systems
  - If 5xx sustained > 45 minutes → Platform Outage DisruptionEvent
  - HMAC signature validation on every incoming webhook

Redis caching tracks first-5xx timestamp per platform per city.
"""

import hashlib
import hmac
import json
import logging
from datetime import datetime, timezone
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import verify_internal_api_key
from app.db.session import get_db
from app.models.domain import (
    DisruptionEvent,
    DisruptionEventStatus,
    DisruptionType,
    HexZone,
    Platform,
)
from app.schemas.api import (
    SwiggyWebhookPayload,
    WebhookAckResponse,
    ZomatoWebhookPayload,
)
from app.services.triggers import evaluate_platform_outage_trigger

router = APIRouter(prefix="/webhooks", tags=["Webhooks"])
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Redis client for outage duration tracking
# ---------------------------------------------------------------------------
import redis as redis_lib

_redis = redis_lib.Redis.from_url(settings.REDIS_URL, decode_responses=True)

OUTAGE_KEY_PREFIX = "platform_outage"
OUTAGE_TTL_SECONDS = 7200  # 2 hours


def _outage_redis_key(platform: str, city: str) -> str:
    return f"{OUTAGE_KEY_PREFIX}:{platform}:{city.lower().replace(' ', '_')}"


def _record_first_5xx(platform: str, city: str) -> datetime:
    """
    Records the first 5xx timestamp in Redis if not already set.
    Returns the original first-seen timestamp.
    """
    key = _outage_redis_key(platform, city)
    existing = _redis.get(key)
    if existing:
        return datetime.fromisoformat(existing)
    now = datetime.now(timezone.utc)
    _redis.setex(key, OUTAGE_TTL_SECONDS, now.isoformat())
    return now


def _clear_outage_record(platform: str, city: str) -> None:
    key = _outage_redis_key(platform, city)
    _redis.delete(key)


# ---------------------------------------------------------------------------
# HMAC signature validator
# ---------------------------------------------------------------------------

def _validate_hmac(
    raw_body: bytes,
    signature_header: str,
    secret: str,
    platform_name: str,
) -> None:
    """Raises 401 if HMAC signature does not match."""
    if not signature_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Missing {platform_name} webhook signature header",
        )
    expected = hmac.new(
        secret.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()
    received = signature_header.replace("sha256=", "")
    if not hmac.compare_digest(expected, received):
        logger.warning("%s webhook HMAC mismatch", platform_name)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Webhook signature validation failed",
        )


# ---------------------------------------------------------------------------
# Shared outage processing logic
# ---------------------------------------------------------------------------

async def _process_platform_5xx(
    db: AsyncSession,
    platform: Platform,
    city: str,
    h3_index: str | None,
    http_status_code: int,
    occurred_at: datetime,
) -> WebhookAckResponse:
    """
    Core platform outage logic shared between Zomato and Swiggy handlers.

    1. Record first-5xx timestamp in Redis
    2. Check if outage duration exceeds threshold (45 min)
    3. If triggered: create DisruptionEvent (platform_outage), queue payouts
    4. Return ack with duration and trigger status
    """
    first_seen = _record_first_5xx(platform.value, city)
    duration_minutes = (datetime.now(timezone.utc) - first_seen).total_seconds() / 60.0
    triggered = evaluate_platform_outage_trigger(first_seen)

    logger.info(
        "Platform 5xx: platform=%s city=%s status=%d duration=%.1f min triggered=%s",
        platform.value, city, http_status_code, duration_minutes, triggered,
    )

    if not triggered:
        return WebhookAckResponse(
            received=True,
            outage_duration_minutes=duration_minutes,
            payout_triggered=False,
        )

    # Resolve H3 zone for city centroid if h3_index not provided
    zone_h3 = h3_index
    if not zone_h3:
        zone_result = await db.execute(
            select(HexZone)
            .where(HexZone.city.ilike(city))
            .order_by(HexZone.active_policy_count.desc())
            .limit(1)
        )
        zone = zone_result.scalar_one_or_none()
        zone_h3 = zone.h3_index if zone else None

    if not zone_h3:
        logger.warning("Cannot create disruption event — no H3 zone found for city=%s", city)
        return WebhookAckResponse(
            received=True,
            outage_duration_minutes=duration_minutes,
            payout_triggered=False,
        )

    # Idempotency: check for recent platform outage event in this zone
    from datetime import timedelta
    cutoff = datetime.now(timezone.utc) - timedelta(hours=settings.DUPLICATE_CLAIM_WINDOW_HOURS)
    existing = await db.execute(
        select(DisruptionEvent).where(
            and_(
                DisruptionEvent.disruption_type == DisruptionType.PLATFORM_OUTAGE,
                DisruptionEvent.webhook_platform == platform,
                DisruptionEvent.created_at >= cutoff,
                DisruptionEvent.status.in_([
                    DisruptionEventStatus.CONFIRMED,
                    DisruptionEventStatus.PAYOUTS_PROCESSING,
                ]),
            )
        )
    )
    if existing.scalar_one_or_none():
        logger.info("Duplicate platform outage event suppressed for %s / %s", platform.value, city)
        return WebhookAckResponse(
            received=True,
            outage_duration_minutes=duration_minutes,
            payout_triggered=False,
        )

    # Fetch zone record for hex_zone_id FK
    zone_rec_result = await db.execute(
        select(HexZone).where(HexZone.h3_index == zone_h3)
    )
    zone_rec = zone_rec_result.scalar_one_or_none()
    if not zone_rec:
        return WebhookAckResponse(
            received=True,
            outage_duration_minutes=duration_minutes,
            payout_triggered=False,
        )

    # Create DisruptionEvent
    now = datetime.now(timezone.utc)
    event = DisruptionEvent(
        hex_zone_id=zone_rec.id,
        disruption_type=DisruptionType.PLATFORM_OUTAGE,
        status=DisruptionEventStatus.CONFIRMED,
        primary_trigger_value=None,
        primary_trigger_source=f"{platform.value}_webhook",
        primary_triggered_at=first_seen,
        secondary_nlp_confidence=None,
        secondary_triggered_at=None,
        consensus_achieved_at=now,
        webhook_platform=platform,
        webhook_first_5xx_at=first_seen,
        raw_weather_payload=None,
        raw_nlp_payload={
            "outage_duration_minutes": duration_minutes,
            "http_status_code": http_status_code,
        },
    )
    db.add(event)
    await db.flush()
    await db.refresh(event)

    # Dispatch Celery broadcast
    from app.tasks.worker import broadcast_payout_to_hex
    broadcast_payout_to_hex.apply_async(
        args=[str(event.id), str(zone_rec.id), zone_h3],
        countdown=3,
    )

    # Clear Redis outage record to avoid re-triggering
    _clear_outage_record(platform.value, city)

    logger.info(
        "Platform outage DisruptionEvent created: %s platform=%s city=%s",
        event.id, platform.value, city,
    )

    return WebhookAckResponse(
        received=True,
        event_id=event.id,
        outage_duration_minutes=duration_minutes,
        payout_triggered=True,
    )


# ---------------------------------------------------------------------------
# Zomato Webhook Handler
# ---------------------------------------------------------------------------

@router.post("/zomato", response_model=WebhookAckResponse)
async def zomato_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_zomato_signature: str = Header(default="", alias="X-Zomato-Signature"),
):
    """
    Receives Zomato dispatch webhook events.
    Validates HMAC-SHA256 signature before processing.
    """
    raw_body = await request.body()
    _validate_hmac(raw_body, x_zomato_signature, settings.WEBHOOK_SECRET_ZOMATO, "Zomato")

    try:
        payload = ZomatoWebhookPayload.model_validate_json(raw_body)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Invalid payload: {exc}")

    # Only process 5xx dispatch errors
    if not (500 <= payload.http_status_code <= 599):
        return WebhookAckResponse(received=True, payout_triggered=False)

    city = payload.city or "unknown"
    return await _process_platform_5xx(
        db=db,
        platform=Platform.ZOMATO,
        city=city,
        h3_index=payload.zone_h3_index,
        http_status_code=payload.http_status_code,
        occurred_at=payload.timestamp,
    )


# ---------------------------------------------------------------------------
# Swiggy Webhook Handler
# ---------------------------------------------------------------------------

@router.post("/swiggy", response_model=WebhookAckResponse)
async def swiggy_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_swiggy_signature: str = Header(default="", alias="X-Swiggy-Signature"),
):
    """
    Receives Swiggy dispatch webhook events.
    """
    raw_body = await request.body()
    _validate_hmac(raw_body, x_swiggy_signature, settings.WEBHOOK_SECRET_SWIGGY, "Swiggy")

    try:
        payload = SwiggyWebhookPayload.model_validate_json(raw_body)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Invalid payload: {exc}")

    if not (500 <= payload.status_code <= 599):
        return WebhookAckResponse(received=True, payout_triggered=False)

    # Resolve H3 from lat/lng if available
    h3_index = None
    if payload.location_lat and payload.location_lng:
        import h3 as h3lib
        h3_index = h3lib.latlng_to_cell(
            payload.location_lat, payload.location_lng, resolution=8
        )

    city = "unknown"
    if payload.location_lat and payload.location_lng:
        # Reverse geocode to city using H3 — in production use Google Maps Geocoding
        # For now, derive from closest active HexZone
        result = await db.execute(
            select(HexZone)
            .where(HexZone.h3_index == h3_index)
            .limit(1)
        )
        zone = result.scalar_one_or_none()
        city = zone.city if zone else "unknown"

    return await _process_platform_5xx(
        db=db,
        platform=Platform.SWIGGY,
        city=city,
        h3_index=h3_index,
        http_status_code=payload.status_code,
        occurred_at=payload.occurred_at,
    )


# ---------------------------------------------------------------------------
# Razorpay Payout Webhook (status updates)
# ---------------------------------------------------------------------------

@router.post("/razorpay/payout-status", response_model=WebhookAckResponse)
async def razorpay_payout_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_razorpay_signature: str = Header(default="", alias="X-Razorpay-Signature"),
):
    """
    Receives Razorpay payout status webhooks.
    Updates PayoutTransaction and Claim status accordingly.
    """
    from app.models.domain import PayoutTransaction, PayoutStatus, Claim, ClaimStatus
    from sqlalchemy import update

    raw_body = await request.body()

    # Validate Razorpay webhook signature (uses webhook secret, not API secret)
    _validate_hmac(
        raw_body,
        x_razorpay_signature,
        settings.RAZORPAY_KEY_SECRET,
        "Razorpay",
    )

    data = json.loads(raw_body)
    event = data.get("event", "")
    payload = data.get("payload", {}).get("payout", {}).get("entity", {})
    razorpay_payout_id = payload.get("id")

    if not razorpay_payout_id:
        return WebhookAckResponse(received=True, payout_triggered=False)

    result = await db.execute(
        select(PayoutTransaction)
        .options(selectinload_payout(PayoutTransaction.claim))
        .where(PayoutTransaction.razorpay_payout_id == razorpay_payout_id)
    )

    from sqlalchemy.orm import selectinload as selectinload_payout_orm
    result2 = await db.execute(
        select(PayoutTransaction)
        .options(selectinload_payout_orm(PayoutTransaction.claim))
        .where(PayoutTransaction.razorpay_payout_id == razorpay_payout_id)
    )
    payout_tx = result2.scalar_one_or_none()

    if not payout_tx:
        logger.warning("Razorpay webhook for unknown payout_id: %s", razorpay_payout_id)
        return WebhookAckResponse(received=True, payout_triggered=False)

    if event == "payout.processed":
        payout_tx.status = PayoutStatus.SUCCESS
        payout_tx.completed_at = datetime.now(timezone.utc)
        if payout_tx.claim:
            payout_tx.claim.status = ClaimStatus.PAID
    elif event in ("payout.failed", "payout.reversed"):
        payout_tx.status = PayoutStatus.FAILED
        payout_tx.failure_reason = payload.get("failure_reason", event)
        if payout_tx.claim:
            payout_tx.claim.status = ClaimStatus.REJECTED

    payout_tx.raw_response = payload

    logger.info(
        "Razorpay webhook processed: payout_id=%s event=%s",
        razorpay_payout_id, event,
    )
    return WebhookAckResponse(received=True, payout_triggered=False)