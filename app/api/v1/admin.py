"""
Admin endpoints (require admin JWT):

  POST /admin/trigger/manual       — Fire a test disruption event in any H3 zone
  GET  /admin/zones/stats          — Zone-level loss ratio and payout dashboard
  GET  /admin/system/health        — Platform-wide KPIs
  POST /admin/riders/{id}/suspend  — Suspend a rider (fraud enforcement)
  GET  /admin/claims/pending       — List claims awaiting manual review
  POST /admin/claims/{id}/review   — Approve or reject a flagged claim
"""

import logging
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import require_admin
from app.db.session import get_db
from app.models.domain import (
    Claim,
    ClaimStatus,
    DisruptionEvent,
    DisruptionEventStatus,
    DisruptionType,
    FraudRiskLevel,
    HexZone,
    PayoutTransaction,
    PayoutStatus,
    Policy,
    PolicyStatus,
    Rider,
    RiderStatus,
)
from app.schemas.api import (
    ClaimListResponse,
    ClaimResponse,
    ManualTriggerRequest,
    ManualTriggerResponse,
    RiderResponse,
    SuccessResponse,
    SystemHealthResponse,
    ZoneStatsResponse,
)
from app.services.pricing import calculate_max_payout
from app.services.triggers import evaluate_dual_key_consensus

router = APIRouter(prefix="/admin", tags=["Admin"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Manual Trigger (README §5.3 MVP Demo Flow)
# ---------------------------------------------------------------------------

@router.post(
    "/trigger/manual",
    response_model=ManualTriggerResponse,
    status_code=status.HTTP_201_CREATED,
)
async def manual_trigger(
    body: ManualTriggerRequest,
    db: AsyncSession = Depends(get_db),
    admin: dict = Depends(require_admin),
):
    """
    Admin: manually fire a disruption event in a specific H3 zone.
    Used for the 3-minute MVP demo flow (README §5.3):
    'Admin toggles Chennai Monsoon Hex → Flutter Edge AI verifies → Payout processed.'

    With bypass_nlp_confirmation=True, skips the NLP secondary key.
    """
    import h3 as h3lib

    # Resolve zone
    zone_result = await db.execute(
        select(HexZone).where(HexZone.h3_index == body.h3_index)
    )
    zone = zone_result.scalar_one_or_none()
    if not zone:
        raise HTTPException(
            status_code=404,
            detail=f"HexZone {body.h3_index} not found. Seed it first or use /policies/zone-lookup.",
        )

    # Idempotency check
    cutoff = datetime.now(timezone.utc) - timedelta(hours=6)
    dup_result = await db.execute(
        select(DisruptionEvent).where(
            and_(
                DisruptionEvent.hex_zone_id == zone.id,
                DisruptionEvent.disruption_type == body.disruption_type,
                DisruptionEvent.created_at >= cutoff,
                DisruptionEvent.status.in_([
                    DisruptionEventStatus.CONFIRMED,
                    DisruptionEventStatus.PAYOUTS_PROCESSING,
                    DisruptionEventStatus.PAYOUTS_COMPLETE,
                ]),
            )
        )
    )
    if dup_result.scalar_one_or_none():
        raise HTTPException(
            status_code=409,
            detail="A disruption event of this type was already triggered in this zone within 6 hours.",
        )

    # Count eligible riders + estimate payout
    now = datetime.now(timezone.utc)
    eligible_result = await db.execute(
        select(func.count(Policy.id)).where(
            and_(
                Policy.hex_zone_id == zone.id,
                Policy.status == PolicyStatus.ACTIVE,
                Policy.start_date <= now,
                Policy.end_date >= now,
            )
        )
    )
    eligible_count = eligible_result.scalar() or 0

    # Estimate payout using zone average
    from app.core.config import settings
    avg_hourly = Decimal("200.00")
    estimated_per_rider = (
        avg_hourly
        * Decimal(str(settings.DISRUPTION_WINDOW_HOURS))
        * Decimal(str(settings.MAX_PAYOUT_PERCENTAGE_OF_HOURLY_RATE))
    )
    estimated_total = estimated_per_rider * Decimal(str(eligible_count))

    # Create DisruptionEvent
    event = DisruptionEvent(
        hex_zone_id=zone.id,
        disruption_type=body.disruption_type,
        status=DisruptionEventStatus.CONFIRMED,
        primary_trigger_value=Decimal(str(body.trigger_value)),
        primary_trigger_source="admin_manual_trigger",
        primary_triggered_at=now,
        secondary_nlp_confidence=Decimal("1.0") if body.bypass_nlp_confirmation else None,
        secondary_triggered_at=now if body.bypass_nlp_confirmation else None,
        consensus_achieved_at=now,
        total_riders_affected=eligible_count,
    )
    if body.admin_note:
        event.raw_nlp_payload = {"admin_note": body.admin_note}
    db.add(event)

    # Mark zone active
    zone.is_active_disruption = True
    await db.flush()
    await db.refresh(event)

    # Dispatch Celery broadcast
    from app.tasks.worker import broadcast_payout_to_hex
    broadcast_payout_to_hex.apply_async(
        args=[str(event.id), str(zone.id), body.h3_index],
        countdown=2,
    )

    logger.info(
        "Admin manual trigger: admin=%s zone=%s type=%s riders=%d",
        admin.get("sub"), body.h3_index, body.disruption_type, eligible_count,
    )

    return ManualTriggerResponse(
        disruption_event_id=event.id,
        h3_index=body.h3_index,
        disruption_type=body.disruption_type,
        status=DisruptionEventStatus.CONFIRMED,
        riders_queued_for_payout=eligible_count,
        estimated_total_payout_inr=estimated_total,
    )


# ---------------------------------------------------------------------------
# Zone Statistics (Loss Ratio Dashboard)
# ---------------------------------------------------------------------------

@router.get("/zones/stats", response_model=list[ZoneStatsResponse])
async def get_zone_stats(
    city: str | None = Query(None),
    limit: int = Query(50, le=200),
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_admin),
):
    """
    Returns per-zone KPIs: active policies, claims, payout totals, loss ratio.
    README §5.3 targets: 92% automation rate, 38% loss ratio.
    """
    week_start = datetime.now(timezone.utc) - timedelta(days=7)

    zone_query = select(HexZone)
    if city:
        zone_query = zone_query.where(HexZone.city.ilike(f"%{city}%"))
    zone_query = zone_query.limit(limit)

    zones_result = await db.execute(zone_query)
    zones = zones_result.scalars().all()

    stats = []
    for zone in zones:
        # Claims paid this week
        claims_result = await db.execute(
            select(
                func.count(Claim.id).label("total_claims"),
                func.coalesce(func.sum(Claim.approved_payout_inr), 0).label("total_payout"),
            ).where(
                and_(
                    Claim.policy_id.in_(
                        select(Policy.id).where(Policy.hex_zone_id == zone.id)
                    ),
                    Claim.created_at >= week_start,
                    Claim.status.in_([ClaimStatus.PAID, ClaimStatus.APPROVED]),
                )
            )
        )
        claims_row = claims_result.first()
        total_claims = claims_row.total_claims if claims_row else 0
        total_payout_inr = Decimal(str(claims_row.total_payout)) if claims_row else Decimal("0")

        # Premiums collected this week
        premiums_result = await db.execute(
            select(func.coalesce(func.sum(Policy.weekly_premium_inr), 0)).where(
                and_(
                    Policy.hex_zone_id == zone.id,
                    Policy.created_at >= week_start,
                )
            )
        )
        total_premiums = Decimal(str(premiums_result.scalar() or 0))

        loss_ratio = float(
            total_payout_inr / total_premiums if total_premiums > 0 else Decimal("0")
        )

        stats.append(
            ZoneStatsResponse(
                h3_index=zone.h3_index,
                city=zone.city,
                active_policies=zone.active_policy_count,
                total_claims_this_week=total_claims,
                total_payout_this_week_inr=total_payout_inr,
                loss_ratio=round(loss_ratio, 4),
                active_disruption=zone.is_active_disruption,
                zone_risk_score=zone.zone_risk_score,
            )
        )

    return stats


# ---------------------------------------------------------------------------
# System Health
# ---------------------------------------------------------------------------

@router.get("/system/health", response_model=SystemHealthResponse)
async def system_health(
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_admin),
):
    """Platform-wide KPIs. Target: 92% automation, 38% loss ratio."""
    week_start = datetime.now(timezone.utc) - timedelta(days=7)
    now = datetime.now(timezone.utc)

    total_riders = (await db.execute(select(func.count(Rider.id)))).scalar() or 0
    total_active_policies = (
        await db.execute(
            select(func.count(Policy.id)).where(
                and_(Policy.status == PolicyStatus.ACTIVE, Policy.end_date >= now)
            )
        )
    ).scalar() or 0
    active_disruption_zones = (
        await db.execute(
            select(func.count(HexZone.id)).where(HexZone.is_active_disruption == True)
        )
    ).scalar() or 0
    claims_pending = (
        await db.execute(
            select(func.count(Claim.id)).where(
                Claim.status.in_([ClaimStatus.PENDING, ClaimStatus.FLAGGED])
            )
        )
    ).scalar() or 0
    payouts_queued = (
        await db.execute(
            select(func.count(PayoutTransaction.id)).where(
                PayoutTransaction.status.in_([PayoutStatus.QUEUED, PayoutStatus.PROCESSING])
            )
        )
    ).scalar() or 0

    # Weekly financials
    premiums_result = await db.execute(
        select(func.coalesce(func.sum(Policy.weekly_premium_inr), 0)).where(
            Policy.created_at >= week_start
        )
    )
    weekly_premiums = Decimal(str(premiums_result.scalar() or 0))

    payouts_result = await db.execute(
        select(func.coalesce(func.sum(Claim.approved_payout_inr), 0)).where(
            and_(
                Claim.created_at >= week_start,
                Claim.status == ClaimStatus.PAID,
            )
        )
    )
    weekly_payouts = Decimal(str(payouts_result.scalar() or 0))

    # Automation rate: claims auto-approved / total claims (excluding PENDING/FLAGGED)
    total_claims = (
        await db.execute(
            select(func.count(Claim.id)).where(Claim.created_at >= week_start)
        )
    ).scalar() or 0
    manual_review_claims = (
        await db.execute(
            select(func.count(Claim.id)).where(
                and_(
                    Claim.created_at >= week_start,
                    Claim.status == ClaimStatus.FLAGGED,
                )
            )
        )
    ).scalar() or 0

    automation_rate = (
        ((total_claims - manual_review_claims) / total_claims * 100)
        if total_claims > 0
        else 100.0
    )
    loss_ratio = float(
        weekly_payouts / weekly_premiums if weekly_premiums > 0 else Decimal("0")
    )

    return SystemHealthResponse(
        total_active_policies=total_active_policies,
        total_riders=total_riders,
        active_disruption_zones=active_disruption_zones,
        claims_pending=claims_pending,
        payouts_queued=payouts_queued,
        automation_rate_pct=round(automation_rate, 2),
        overall_loss_ratio=round(loss_ratio, 4),
        weekly_premium_revenue_inr=weekly_premiums,
        weekly_payout_total_inr=weekly_payouts,
    )


# ---------------------------------------------------------------------------
# Rider Suspension (Fraud Enforcement)
# ---------------------------------------------------------------------------

@router.post("/riders/{rider_id}/suspend", response_model=SuccessResponse)
async def suspend_rider(
    rider_id: UUID,
    reason: str = Query(..., min_length=10),
    db: AsyncSession = Depends(get_db),
    admin: dict = Depends(require_admin),
):
    """Suspend a rider account. Cancels active policies. Blocks future claims."""
    rider_result = await db.execute(select(Rider).where(Rider.id == rider_id))
    rider = rider_result.scalar_one_or_none()
    if not rider:
        raise HTTPException(status_code=404, detail="Rider not found")

    rider.status = RiderStatus.SUSPENDED
    rider.trust_score = Decimal("0.00")

    # Cancel all active policies
    await db.execute(
        update(Policy)
        .where(
            and_(
                Policy.rider_id == rider_id,
                Policy.status == PolicyStatus.ACTIVE,
            )
        )
        .values(status=PolicyStatus.CANCELLED)
    )

    logger.warning(
        "Rider suspended: rider=%s by admin=%s reason=%s",
        rider_id, admin.get("sub"), reason,
    )
    return SuccessResponse(
        message=f"Rider {rider_id} suspended.",
        data={"reason": reason},
    )


# ---------------------------------------------------------------------------
# Pending Claims Review
# ---------------------------------------------------------------------------

@router.get("/claims/pending", response_model=ClaimListResponse)
async def list_pending_claims(
    limit: int = Query(50, le=200),
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: dict = Depends(require_admin),
):
    """Lists FLAGGED and PENDING claims for manual adjudication."""
    result = await db.execute(
        select(Claim)
        .where(Claim.status.in_([ClaimStatus.FLAGGED, ClaimStatus.PENDING]))
        .order_by(Claim.created_at.asc())
        .limit(limit)
        .offset(offset)
    )
    claims = result.scalars().all()

    total_paid = sum(
        (c.approved_payout_inr or Decimal("0")) for c in claims
        if c.status == ClaimStatus.PAID
    )

    return ClaimListResponse(
        items=[ClaimResponse.model_validate(c) for c in claims],
        total=len(claims),
        total_paid_inr=total_paid,
    )


@router.post("/claims/{claim_id}/review", response_model=ClaimResponse)
async def review_claim(
    claim_id: UUID,
    approve: bool = Query(..., description="True to approve, False to reject"),
    note: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
    admin: dict = Depends(require_admin),
):
    """
    Manually approve or reject a flagged claim.
    Approved claims trigger a Razorpay payout.
    """
    result = await db.execute(
        select(Claim)
        .options(selectinload(Claim.rider))
        .where(Claim.id == claim_id)
    )
    claim = result.scalar_one_or_none()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")

    if claim.status not in (ClaimStatus.FLAGGED, ClaimStatus.PENDING):
        raise HTTPException(
            status_code=409,
            detail=f"Claim is in status '{claim.status.value}' and cannot be reviewed.",
        )

    claim.admin_notes = note
    claim.processed_at = datetime.now(timezone.utc)

    if approve:
        claim.status = ClaimStatus.APPROVED
        # Dispatch payout
        from app.services.payouts import process_claim_payout
        await process_claim_payout(db, claim, claim.rider)
    else:
        claim.status = ClaimStatus.REJECTED
        claim.rejection_reason = note or "Rejected by admin after manual review"

    logger.info(
        "Claim reviewed: claim=%s approved=%s admin=%s",
        claim_id, approve, admin.get("sub"),
    )
    return ClaimResponse.model_validate(claim)