"""
EarnSure Dynamic Pricing & Payout Engine (README §4.1 & §6.3)
"""
from decimal import Decimal
from app.models.domain import Rider, HexZone

def calculate_weekly_premium(rider: Rider, zone: HexZone) -> dict:
    """
    Implements README §4.1: AI-Powered Risk Assessment
    Formula: premium = base_rate + (disruption_prob * zone_risk * historical_claims_factor)
    """
    base_rate = Decimal("50.00")
    disruption_prob = Decimal("0.65") # Mocked output from XGBoost model
    
    # Calculate premium
    risk_addition = disruption_prob * zone.zone_risk_score * rider.historical_claims_factor
    total_premium = base_rate + (risk_addition * Decimal("100")) # Scaled for INR
    
    # Apply Streak Discount (README §4.1: 15% discount after 4 weeks)
    streak_discount_applied = False
    if rider.consecutive_streak_weeks >= 4:
        total_premium = total_premium * Decimal("0.85")
        streak_discount_applied = True
        
    return {
        "total_premium": total_premium.quantize(Decimal("0.01")),
        "base_rate": base_rate,
        "disruption_prob": disruption_prob,
        "streak_discount_applied": streak_discount_applied
    }

def calculate_max_payout(rider: Rider, duration_hours: float) -> Decimal:
    """
    Calculates parametric payout based on lost earning hours.
    Rule (README §6.3): Capped at 80% of rider's historical hourly rate.
    """
    hourly_rate = rider.avg_hourly_rate_inr
    total = Decimal(str(duration_hours)) * hourly_rate * Decimal("0.80")
    return total.quantize(Decimal("0.01"))

def update_historical_claims_factor(current_factor: Decimal, claim_approved: bool) -> Decimal:
    """
    Adjusts the risk factor for future premiums based on claim history.
    """
    if claim_approved:
        new_factor = current_factor * Decimal("1.05")
    else:
        new_factor = current_factor * Decimal("0.98")
        
    return max(Decimal("1.0000"), min(new_factor, Decimal("3.0000")))