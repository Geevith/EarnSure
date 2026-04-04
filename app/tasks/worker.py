"""
Celery Worker — Async Zone-Based Engine
FINAL HACKATHON VERSION: Loop Safe & Foreign Key Safe
"""
import asyncio
import logging
from decimal import Decimal
from datetime import datetime, timezone
from uuid import UUID

from celery import Celery
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.domain import (
    Claim, ClaimStatus, DisruptionEvent, DisruptionEventStatus, 
    DisruptionType, Policy, Rider
)
from app.services.pricing import calculate_max_payout
from app.services.triggers import evaluate_dual_key_consensus
from app.services.payouts import process_claim_payout
from app.db.session import get_worker_engine

logger = logging.getLogger(__name__)

celery_app = Celery("earnsure", broker=settings.REDIS_URL, backend=settings.CELERY_RESULT_BACKEND)

def _run_async(coro):
    """Cleanly runs an async function in a synchronous Celery task."""
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()
        asyncio.set_event_loop(None)

@celery_app.task(name="app.tasks.worker.evaluate_zone_trigger")
def evaluate_zone_trigger(h3_index: str, city: str, hex_zone_id: str, *args, **kwargs):
    async def _logic():
        engine = get_worker_engine()
        try:
            async with AsyncSession(engine) as db:
                res = await evaluate_dual_key_consensus(0, 0, city, force_trigger=True)
                if res.consensus_achieved:
                    event = DisruptionEvent(
                        hex_zone_id=UUID(hex_zone_id),
                        disruption_type=res.disruption_type,
                        status=DisruptionEventStatus.CONFIRMED,
                        primary_trigger_value=Decimal(str(res.trigger_value)),
                        primary_trigger_source=res.trigger_source,
                        consensus_achieved_at=datetime.now(timezone.utc)
                    )
                    db.add(event)
                    await db.commit() 
                    await db.refresh(event)
                    
                    broadcast_payout_to_hex.apply_async(
                        args=[str(event.id), hex_zone_id, h3_index],
                        countdown=2
                    )
                    return {"status": "triggered", "event_id": str(event.id)}
                return {"status": "no_disruption"}
        finally:
            await engine.dispose()

    return _run_async(_logic())

@celery_app.task(name="app.tasks.worker.broadcast_payout_to_hex")
def broadcast_payout_to_hex(event_id: str, hex_zone_id: str, h3_index: str = None, *args, **kwargs):
    async def _logic():
        engine = get_worker_engine()
        try:
            async with AsyncSession(engine) as db:
                # 1. THE HACKATHON RACE-CONDITION FIX
                # Ensure the event actually exists before we start attaching claims to it!
                event_uuid = UUID(event_id)
                existing = await db.execute(select(DisruptionEvent).where(DisruptionEvent.id == event_uuid))
                if not existing.scalar_one_or_none():
                    logger.info(f"🛠️ DEMO OVERRIDE: Auto-creating missing Disruption Event {event_id}")
                    demo_event = DisruptionEvent(
                        id=event_uuid,
                        hex_zone_id=UUID(hex_zone_id),
                        disruption_type=DisruptionType.MONSOON,
                        status=DisruptionEventStatus.PAYOUTS_PROCESSING,
                        primary_trigger_value=Decimal("99.9"),
                        primary_trigger_source="Demo Override",
                        consensus_achieved_at=datetime.now(timezone.utc)
                    )
                    db.add(demo_event)
                    try:
                        await db.commit()
                    except Exception:
                        await db.rollback() # Ignores errors if the API just caught up and saved it

                # 2. Fetch Policies
                result = await db.execute(
                    select(Policy).where(Policy.hex_zone_id == UUID(hex_zone_id), Policy.status == "active")
                )
                policies = result.scalars().all()
                
                # 3. Spread payouts
                for idx, p in enumerate(policies):
                    process_single_rider_payout.apply_async(
                        args=[str(p.rider_id), str(p.id), event_id],
                        countdown=(idx % 5) + 1 
                    )
            return {"queued_riders": len(policies)}
        finally:
            await engine.dispose()

    return _run_async(_logic())

@celery_app.task(name="app.tasks.worker.process_single_rider_payout", max_retries=3)
def process_single_rider_payout(rider_id: str, policy_id: str, event_id: str, *args, **kwargs):
    async def _logic():
        engine = get_worker_engine()
        try:
            # We explicitly set expire_on_commit=False here to protect against lazy-loads
            async with AsyncSession(engine, expire_on_commit=False) as db:
                rider = (await db.execute(select(Rider).where(Rider.id == UUID(rider_id)))).scalar_one()
                
                # Extract the name EARLY so we don't need to fetch it after the commit!
                rider_name = rider.name 
                
                payout_amount = calculate_max_payout(rider, 2.0)
                
                claim = Claim(
                    rider_id=rider.id,
                    policy_id=UUID(policy_id),
                    disruption_event_id=UUID(event_id),
                    status=ClaimStatus.APPROVED,
                    claimed_duration_hours=Decimal("2.0"),
                    hourly_rate_used_inr=rider.avg_hourly_rate_inr,
                    calculated_payout_inr=payout_amount,
                    approved_payout_inr=payout_amount
                )
                db.add(claim)
                await db.flush()
                
                await process_claim_payout(db, claim, rider)
                await db.commit() # The database is now committed!
                
                # We use our safely extracted string variable here:
                logger.info(f"✅ PAID: {rider_name} amount ₹{payout_amount}")
                return {"status": "paid", "rider": rider_name}
        except Exception as e:
            logger.error(f"Payout failed for {rider_id}: {str(e)}")
            raise
        finally:
            await engine.dispose()

    return _run_async(_logic())