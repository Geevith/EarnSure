"""
EarnSure Master Seeder V3
Multi-city zones, dynamic payouts, advanced Edge-AI fraud reasons, 
and 30-day Time-Series historical data for beautiful Analytics graphs.
"""

import asyncio
import random
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from app.db.base import Base

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import sessionmaker

from app.db.session import engine
from app.models.domain import (
    Claim, ClaimStatus, DisruptionEvent, DisruptionEventStatus, DisruptionType,
    FraudRiskLevel, HexZone, Platform, Policy, PolicyStatus, Rider, RiderStatus
)

SessionLocal = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

def utcnow():
    return datetime.now(timezone.utc)

# Multi-City Scaling
ZONES = [
    {"city": "Chennai", "index": "8861892523fffff", "district": "Adyar", "risk": "0.850"},
    {"city": "Bangalore", "index": "8860145b53fffff", "district": "Koramangala", "risk": "0.920"},
    {"city": "Mumbai", "index": "8860145b55fffff", "district": "Bandra", "risk": "0.750"},
    {"city": "Delhi", "index": "8860145b57fffff", "district": "Connaught", "risk": "0.600"},
    {"city": "Hyderabad", "index": "8860145b59fffff", "district": "Hitec City", "risk": "0.880"},
]

FIRST_NAMES = ["Rahul", "Priya", "Amit", "Karthik", "Sneha", "Vikram", "Suresh", "Arun", "Deepa", "Manoj", "Aisha", "Rohan"]
LAST_NAMES = ["Kumar", "Sharma", "Singh", "Rajan", "Iyer", "Nair", "Menon", "Reddy", "Patel", "Das", "Bose"]

FRAUD_REASONS = [
    "Edge-AI: Flat sensors detected. Device physically stationary.",
    "Edge-AI: GPS spoofing mock-location signature detected.",
    "Edge-AI: WiFi BSSID overlap (Fraud farm cluster detected).",
    "Edge-AI: AC Power anomaly. Charging via wall outlet during active flood.",
    "Edge-AI: Impossible travel speed > 120km/h."
]

async def seed_database():
    print("🏗️ Ensuring database tables exist before seeding...")
    async with engine.begin() as conn:
        # This forces SQLAlchemy to create the tables if they don't exist!
        await conn.run_sync(Base.metadata.create_all)
    print("🧹 Cleaning old business data (Keeping Admin safe)...")
    try:
        async with engine.begin() as conn:
            await conn.execute(text("TRUNCATE TABLE claim, payout_transaction, disruption_event, policy, device_fingerprint, rider, hex_zone CASCADE;"))
    except Exception:
        print("⚠️ Fresh database detected. Skipping truncate...")
    print("🌱 Starting EarnSure Database Seed V3 (Time-Series Enabled)...")
    async with SessionLocal() as session:
        
        # 1. Create Hex Zones
        print("📍 Creating Multi-City Hex Zones...")
        zones = []
        for z in ZONES:
            zone = HexZone(
                h3_index=z["index"],
                city=z["city"],
                district=z["district"],
                zone_risk_score=Decimal(z["risk"]),
                monsoon_risk=Decimal("0.800"),
                heat_risk=Decimal("0.500"),
                traffic_risk=Decimal("0.700"),
                active_policy_count=30
            )
            session.add(zone)
            zones.append(zone)
        await session.flush()

        # 2. Create Riders & Policies
        print("🛵 Creating 150 Riders with Dynamic Pricing...")
        riders = []
        policies = []
        now = utcnow()
        
        for i in range(150):
            rider = Rider(
                phone=f"+9198{random.randint(10000000, 99999999)}",
                name=f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}",
                platform=random.choice([Platform.SWIGGY, Platform.ZOMATO]),
                city=zones[i % 5].city,
                avg_hourly_rate_inr=Decimal(str(random.randint(120, 350))),
                trust_score=Decimal(str(round(random.uniform(2.0, 9.9), 2))),
                status=RiderStatus.ACTIVE,
                is_verified=True,
                consecutive_streak_weeks=random.randint(0, 8)
            )
            session.add(rider)
            riders.append(rider)
        await session.flush()

        for idx, rider in enumerate(riders):
            assigned_zone = zones[idx % 5]
            base_rate = Decimal("50.00")
            risk_premium = base_rate * assigned_zone.zone_risk_score
            discount = Decimal("0.85") if rider.consecutive_streak_weeks >= 4 else Decimal("1.00")
            final_premium = (base_rate + risk_premium) * discount

            policy = Policy(
                rider_id=rider.id,
                hex_zone_id=assigned_zone.id,
                # CRITICAL: Start policies 40 days ago so historical claims are valid
                start_date=now - timedelta(days=40),
                end_date=now + timedelta(days=30),
                weekly_premium_inr=round(final_premium, 2),
                max_payout_inr=rider.avg_hourly_rate_inr * Decimal("8.0"),
                platform=rider.platform,
                status=PolicyStatus.ACTIVE,
                base_rate_used=base_rate,
                disruption_prob_used=Decimal("0.6500"),
                zone_risk_used=assigned_zone.zone_risk_score,
                historical_claims_factor_used=Decimal("1.0000"),
                streak_discount_applied=(rider.consecutive_streak_weeks >= 4)
            )
            session.add(policy)
            policies.append((rider, policy, assigned_zone))
        await session.flush()

        # 3. Generating 30 Days of Historical Data (The Graph Fix!)
        print("📈 Generating 30-day historical data for analytics...")
        base_date = now - timedelta(days=30)
        
        for day_offset in range(30):
            current_date = base_date + timedelta(days=day_offset)
            
            # Trend multiplier makes the graph go UP over the 30 days
            trend_multiplier = 1 + (day_offset * 0.08) 
            
            # 1 to 2 random disruptions per historical day
            daily_events = random.randint(1, 2)
            for _ in range(daily_events):
                hist_zone = random.choice(zones)
                
                hist_event = DisruptionEvent(
                    hex_zone_id=hist_zone.id,
                    disruption_type=DisruptionType.TRAFFIC_GRIDLOCK,
                    status=DisruptionEventStatus.PAYOUTS_PROCESSING,
                    primary_trigger_value=Decimal(str(round(random.uniform(5.0, 9.9), 1))),
                    primary_trigger_source="Historical DB",
                    primary_triggered_at=current_date,
                    secondary_nlp_confidence=Decimal("0.9500"),
                    secondary_nlp_source_url="https://twitter.com/historical",
                    secondary_nlp_snippet="Historical disruption recorded.",
                    consensus_achieved_at=current_date + timedelta(minutes=45),
                    total_riders_affected=0,
                    total_payout_inr=Decimal("0")
                )
                session.add(hist_event)
                await session.flush()
                
                hist_policies = [p for p in policies if p[2].id == hist_zone.id]
                
                # Number of claims grows as the month goes on
                affected_count = int(len(hist_policies) * random.uniform(0.1, 0.4) * trend_multiplier)
                affected_count = min(affected_count, len(hist_policies))
                affected_policies = random.sample(hist_policies, affected_count)
                
                hist_total_payout = Decimal("0")
                for rider, policy, _ in affected_policies:
                    claimed_hours = Decimal(str(round(random.uniform(1.0, 4.0), 2)))
                    calculated_payout = rider.avg_hourly_rate_inr * claimed_hours
                    
                    # 85% of historical claims are approved to make payout graphs look good
                    is_approved = random.random() > 0.15 
                    if is_approved:
                        status = ClaimStatus.APPROVED
                        fraud_level = FraudRiskLevel.LOW
                        reason = None
                        app_payout = calculated_payout
                        hist_total_payout += app_payout
                    else:
                        status = ClaimStatus.REJECTED
                        fraud_level = FraudRiskLevel.HIGH
                        reason = random.choice(FRAUD_REASONS)
                        app_payout = Decimal("0")
                    
                    claim = Claim(
                        rider_id=rider.id,
                        policy_id=policy.id,
                        disruption_event_id=hist_event.id,
                        status=status,
                        fraud_risk_level=fraud_level,
                        claimed_duration_hours=claimed_hours,
                        hourly_rate_used_inr=rider.avg_hourly_rate_inr,
                        calculated_payout_inr=calculated_payout,
                        approved_payout_inr=app_payout,
                        rejection_reason=reason,
                        created_at=current_date + timedelta(minutes=random.randint(10, 120))
                    )
                    session.add(claim)
                
                hist_event.total_riders_affected = affected_count
                hist_event.total_payout_inr = hist_total_payout

        await session.flush()

        # 4. Create "LIVE" Disruption Event (For Demo Purposes)
        print("🚦 Triggering LIVE Bangalore Traffic Gridlock (Today's Demo)...")
        blr_zone = zones[1]
        live_event = DisruptionEvent(
            hex_zone_id=blr_zone.id,
            disruption_type=DisruptionType.TRAFFIC_GRIDLOCK,
            status=DisruptionEventStatus.PAYOUTS_PROCESSING,
            primary_trigger_value=Decimal("8.2"),
            primary_trigger_source="TomTom API",
            primary_triggered_at=now - timedelta(hours=2),
            secondary_nlp_confidence=Decimal("0.9600"),
            secondary_nlp_source_url="https://twitter.com/blr_traffic/status/123",
            secondary_nlp_snippet="Massive gridlock at Koramangala Sony World signal due to waterlogging.",
            consensus_achieved_at=now - timedelta(minutes=90),
            total_riders_affected=30,
            total_payout_inr=Decimal("0")
        )
        session.add(live_event)
        await session.flush()

        # Generate "PENDING/FLAGGED" claims for the Live Dashboard
        blr_policies = [p for p in policies if p[2].id == blr_zone.id]
        live_total_payout = Decimal("0")
        
        for i, (rider, policy, _) in enumerate(blr_policies):
            claimed_hours = Decimal(str(round(random.uniform(1.0, 4.0), 2)))
            calculated_payout = rider.avg_hourly_rate_inr * claimed_hours
            
            # Workflow Routing based on Trust Score
            if rider.trust_score >= 8.0:
                status = ClaimStatus.APPROVED
                fraud_level = FraudRiskLevel.LOW
                reason = None
                app_payout = calculated_payout
            elif rider.trust_score >= 6.0:
                status = ClaimStatus.PENDING
                fraud_level = FraudRiskLevel.LOW
                reason = None
                app_payout = Decimal("0")
            elif rider.trust_score >= 4.0:
                status = ClaimStatus.FLAGGED
                fraud_level = FraudRiskLevel.MEDIUM
                reason = "Suspicious sensor clustering. Request 1 delivery to unlock funds."
                app_payout = Decimal("0")
            else:
                status = ClaimStatus.REJECTED
                fraud_level = FraudRiskLevel.HIGH
                reason = random.choice(FRAUD_REASONS)
                app_payout = Decimal("0")

            if status == ClaimStatus.APPROVED:
                live_total_payout += app_payout

            claim = Claim(
                rider_id=rider.id,
                policy_id=policy.id,
                disruption_event_id=live_event.id,
                status=status,
                fraud_risk_level=fraud_level,
                claimed_duration_hours=claimed_hours,
                hourly_rate_used_inr=rider.avg_hourly_rate_inr,
                calculated_payout_inr=calculated_payout,
                approved_payout_inr=app_payout,
                rejection_reason=reason,
                created_at=now - timedelta(minutes=random.randint(10, 80))
            )
            session.add(claim)
            
        live_event.total_payout_inr = live_total_payout
        await session.commit()
        print("✅ V3 Seed Complete! Analytics graphs are now beautiful and production-ready.")

if __name__ == "__main__":
    asyncio.run(seed_database())