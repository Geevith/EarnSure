"""
Razorpay Smart-Contract Payout Service (README §4.3)
"""
import logging
from datetime import datetime, timezone
from uuid import UUID, uuid4
import httpx
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.core.config import settings
from app.models.domain import Claim, ClaimStatus, PayoutStatus, PayoutTransaction, Rider

logger = logging.getLogger(__name__)

async def process_claim_payout(db: AsyncSession, claim: Claim, rider: Rider) -> PayoutTransaction:
    # 1. Idempotency Check
    existing = await db.execute(select(PayoutTransaction).where(PayoutTransaction.claim_id == claim.id))
    if existing.scalar_one_or_none():
        return existing.scalar_one()

    upi_id = rider.upi_id or f"{rider.phone}@upi"
    amount_inr = claim.approved_payout_inr or claim.calculated_payout_inr
    
    # 2. Record Transaction
    payout_tx = PayoutTransaction(
        claim_id=claim.id,
        rider_id=rider.id,
        amount_inr=amount_inr,
        amount_paise=int(amount_inr * 100),
        upi_id_used=upi_id,
        status=PayoutStatus.QUEUED
    )
    db.add(payout_tx)
    await db.flush()

    # 3. Simulate or Execute Razorpay Call
    try:
        # SIMULATION MODE for Hackathon safety
        if "rzp_test" not in settings.RAZORPAY_KEY_ID:
            logger.warning(f"💸 DEMO MODE: Simulating Razorpay Payout of ₹{amount_inr} to {upi_id}")
            payout_tx.status = PayoutStatus.SUCCESS
            payout_tx.razorpay_payout_id = f"pout_{uuid4().hex[:14]}"
            payout_tx.completed_at = datetime.now(timezone.utc)
            claim.status = ClaimStatus.PAID
        else:
            # Real Sandbox logic would go here
            payout_tx.status = PayoutStatus.SUCCESS # Simplified for demo
            claim.status = ClaimStatus.PAID
            
    except Exception as e:
        logger.error(f"Payout failed: {e}")
        payout_tx.status = PayoutStatus.FAILED
        claim.status = ClaimStatus.REJECTED

    return payout_tx