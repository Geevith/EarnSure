"""
Pydantic V2 schemas for all API request/response contracts.
Organized by domain: Rider, Zone, Policy, Claim, Disruption, Webhook, Admin.
"""

from datetime import datetime
from decimal import Decimal
from typing import Any, Optional
from uuid import UUID

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

from app.models.domain import (
    ClaimStatus,
    DisruptionEventStatus,
    DisruptionType,
    FraudRiskLevel,
    PayoutStatus,
    Platform,
    PolicyStatus,
    RiderStatus,
)


# ---------------------------------------------------------------------------
# Shared base: ORM-mode enabled for all read schemas
# ---------------------------------------------------------------------------
class ORMBase(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Generic envelope
# ---------------------------------------------------------------------------
class SuccessResponse(BaseModel):
    success: bool = True
    message: str
    data: Optional[Any] = None


class ErrorResponse(BaseModel):
    success: bool = False
    error: str
    detail: Optional[Any] = None


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_seconds: int


class RiderLoginRequest(BaseModel):
    phone: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    otp: str = Field(..., min_length=4, max_length=8)


# ---------------------------------------------------------------------------
# Rider
# ---------------------------------------------------------------------------
class RiderCreateRequest(BaseModel):
    phone: str = Field(..., pattern=r"^\+?[0-9]{10,15}$")
    name: str = Field(..., min_length=2, max_length=120)
    platform: Platform
    city: str = Field(..., min_length=2, max_length=60)
    upi_id: Optional[str] = Field(None, max_length=100)

    @field_validator("upi_id")
    @classmethod
    def validate_upi(cls, v: Optional[str]) -> Optional[str]:
        if v and "@" not in v:
            raise ValueError("UPI ID must contain '@' (e.g. rider@upi)")
        return v


class RiderUpdateRequest(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=120)
    upi_id: Optional[str] = Field(None, max_length=100)
    bank_account_number: Optional[str] = Field(None, max_length=30)
    bank_ifsc: Optional[str] = Field(None, min_length=11, max_length=11)


class RiderResponse(ORMBase):
    id: UUID
    phone: str
    name: str
    platform: Platform
    city: str
    upi_id: Optional[str]
    trust_score: Decimal
    status: RiderStatus
    is_verified: bool
    consecutive_streak_weeks: int
    avg_hourly_rate_inr: Decimal
    historical_claims_factor: Decimal
    created_at: datetime


class RiderRiskProfileResponse(BaseModel):
    rider_id: UUID
    risk_score: float = Field(..., description="0.0–10.0 composite risk score")
    weekly_premium_inr: Decimal
    disruption_probability: float
    zone_risk: float
    historical_claims_factor: Decimal
    streak_discount_applied: bool
    streak_discount_pct: float
    calculation_breakdown: dict[str, Any]


# ---------------------------------------------------------------------------
# Hex Zones
# ---------------------------------------------------------------------------
class HexZoneResponse(ORMBase):
    id: UUID
    h3_index: str
    city: str
    district: Optional[str]
    zone_risk_score: Decimal
    monsoon_risk: Decimal
    heat_risk: Decimal
    traffic_risk: Decimal
    active_policy_count: int
    is_active_disruption: bool


class ZoneLookupRequest(BaseModel):
    lat: float = Field(..., ge=-90.0, le=90.0)
    lng: float = Field(..., ge=-180.0, le=180.0)


class ZoneLookupResponse(BaseModel):
    h3_index: str
    zone: Optional[HexZoneResponse]
    weekly_premium_estimate_inr: Optional[Decimal]


# ---------------------------------------------------------------------------
# Device Fingerprint (sent from Flutter Edge-AI layer)
# ---------------------------------------------------------------------------
class DeviceFingerprintPayload(BaseModel):
    """
    Submitted by the Flutter SDK before any claim is processed.
    Physics values computed on-device by tflite_flutter + sensors_plus.
    """
    device_id: str = Field(..., min_length=8, max_length=120)
    device_model: Optional[str] = None
    os_version: Optional[str] = None
    app_version: Optional[str] = None

    # GPS
    gps_lat: float = Field(..., ge=-90.0, le=90.0)
    gps_lng: float = Field(..., ge=-180.0, le=180.0)
    gps_accuracy_meters: float = Field(..., ge=0.0)
    gps_altitude_m: Optional[float] = None
    gps_speed_mps: Optional[float] = Field(None, ge=0.0)

    # Physics sensors
    accelerometer_magnitude_hz: float = Field(
        ..., ge=0.0,
        description="Std-dev of accelerometer magnitude over 5s window. "
                    "<0.5 Hz = dead flat = spoofing signal."
    )
    gyroscope_active: bool
    is_charging: bool
    battery_level_pct: int = Field(..., ge=0, le=100)
    charging_type: str = Field(
        ..., pattern=r"^(usb|ac|wireless|none)$"
    )

    # Network
    cell_tower_id: Optional[str] = None
    cell_mcc: Optional[str] = None
    cell_mnc: Optional[str] = None
    wifi_bssid: Optional[str] = None
    wifi_ssid: Optional[str] = None


class DeviceFingerprintResponse(ORMBase):
    id: UUID
    device_id: str
    is_gps_spoofed: bool
    is_flat_sensor: bool
    is_ac_charging_anomaly: bool
    is_bssid_farm: bool
    fraud_risk_level: FraudRiskLevel
    fraud_score: Decimal
    captured_at: datetime


# ---------------------------------------------------------------------------
# Policy
# ---------------------------------------------------------------------------
class PolicyPurchaseRequest(BaseModel):
    rider_id: UUID
    h3_index: str = Field(
        ..., min_length=10, max_length=20,
        description="H3 cell index for the zone the rider operates in."
    )
    platform: Platform
    device_fingerprint: DeviceFingerprintPayload

    # Optional override for UPI at purchase time
    upi_id: Optional[str] = None


class PolicyResponse(ORMBase):
    id: UUID
    rider_id: UUID
    platform: Platform
    status: PolicyStatus
    start_date: datetime
    end_date: datetime
    weekly_premium_inr: Decimal
    max_payout_inr: Decimal
    streak_discount_applied: bool
    razorpay_order_id: Optional[str]
    created_at: datetime


class PolicyListResponse(BaseModel):
    items: list[PolicyResponse]
    total: int


class ActivePolicyCheckResponse(BaseModel):
    rider_id: UUID
    has_active_policy: bool
    policy: Optional[PolicyResponse]
    current_disruption_active: bool
    disruption_event_id: Optional[UUID]


# ---------------------------------------------------------------------------
# Claims
# ---------------------------------------------------------------------------
class ClaimSubmitRequest(BaseModel):
    """
    Riders never submit claims manually — claims are auto-triggered by
    DisruptionEvents. This schema is used only for the rare manual-override
    flow (admin-initiated) and integration tests.
    """
    rider_id: UUID
    policy_id: UUID
    disruption_event_id: UUID
    device_fingerprint: DeviceFingerprintPayload
    claimed_duration_hours: Decimal = Field(
        ..., gt=Decimal("0"), le=Decimal("4"),
        description="Hours of income lost. Capped at 4 by the system."
    )


class ClaimResponse(ORMBase):
    id: UUID
    rider_id: UUID
    policy_id: UUID
    disruption_event_id: UUID
    status: ClaimStatus
    fraud_risk_level: FraudRiskLevel
    claimed_duration_hours: Decimal
    calculated_payout_inr: Decimal
    approved_payout_inr: Optional[Decimal]
    rejection_reason: Optional[str]
    created_at: datetime
    processed_at: Optional[datetime]


class ClaimListResponse(BaseModel):
    items: list[ClaimResponse]
    total: int
    total_paid_inr: Decimal


# ---------------------------------------------------------------------------
# Disruption Events
# ---------------------------------------------------------------------------
class DisruptionEventResponse(ORMBase):
    id: UUID
    hex_zone_id: UUID
    disruption_type: DisruptionType
    status: DisruptionEventStatus
    primary_trigger_value: Optional[Decimal]
    primary_trigger_source: Optional[str]
    primary_triggered_at: Optional[datetime]
    secondary_nlp_confidence: Optional[Decimal]
    consensus_achieved_at: Optional[datetime]
    total_riders_affected: int
    total_payout_inr: Decimal
    created_at: datetime


class ManualTriggerRequest(BaseModel):
    """Admin endpoint: manually fire a disruption event for testing."""
    h3_index: str = Field(..., min_length=10, max_length=20)
    disruption_type: DisruptionType
    trigger_value: float = Field(
        ..., description="e.g. 27.4 for mm/hr rain, 46.0 for °C temp"
    )
    bypass_nlp_confirmation: bool = Field(
        default=False,
        description="Set True in sandbox to skip NLP secondary key check."
    )
    admin_note: Optional[str] = None


class ManualTriggerResponse(BaseModel):
    disruption_event_id: UUID
    h3_index: str
    disruption_type: DisruptionType
    status: DisruptionEventStatus
    riders_queued_for_payout: int
    estimated_total_payout_inr: Decimal


# ---------------------------------------------------------------------------
# Webhooks (Zomato / Swiggy Dispatch)
# ---------------------------------------------------------------------------
class ZomatoWebhookPayload(BaseModel):
    """
    Represents a Zomato dispatch webhook event.
    EarnSure monitors for 5xx status codes sustained > 45 minutes.
    """
    event_type: str = Field(
        ..., description="e.g. dispatch.order_failed, dispatch.server_error"
    )
    platform: Platform = Platform.ZOMATO
    http_status_code: int
    rider_id_external: Optional[str] = None
    city: Optional[str] = None
    zone_h3_index: Optional[str] = None
    timestamp: datetime
    request_id: Optional[str] = None
    raw_payload: Optional[dict[str, Any]] = None

    @field_validator("http_status_code")
    @classmethod
    def must_be_5xx(cls, v: int) -> int:
        if not (500 <= v <= 599):
            raise ValueError("Webhook handler only processes 5xx status codes")
        return v


class SwiggyWebhookPayload(BaseModel):
    event: str
    platform: Platform = Platform.SWIGGY
    status_code: int
    rider_phone: Optional[str] = None
    location_lat: Optional[float] = None
    location_lng: Optional[float] = None
    occurred_at: datetime
    trace_id: Optional[str] = None


class WebhookAckResponse(BaseModel):
    received: bool = True
    event_id: Optional[UUID] = None
    outage_duration_minutes: Optional[float] = None
    payout_triggered: bool = False


# ---------------------------------------------------------------------------
# Payout Transactions
# ---------------------------------------------------------------------------
class PayoutTransactionResponse(ORMBase):
    id: UUID
    claim_id: UUID
    amount_inr: Decimal
    payout_mode: str
    upi_id_used: Optional[str]
    razorpay_payout_id: Optional[str]
    status: PayoutStatus
    failure_reason: Optional[str]
    initiated_at: datetime
    completed_at: Optional[datetime]


# ---------------------------------------------------------------------------
# Admin Dashboard
# ---------------------------------------------------------------------------
class ZoneStatsResponse(BaseModel):
    h3_index: str
    city: str
    active_policies: int
    total_claims_this_week: int
    total_payout_this_week_inr: Decimal
    loss_ratio: float = Field(..., description="claims_paid / premiums_collected")
    active_disruption: bool
    zone_risk_score: Decimal


class SystemHealthResponse(BaseModel):
    total_active_policies: int
    total_riders: int
    active_disruption_zones: int
    claims_pending: int
    payouts_queued: int
    automation_rate_pct: float = Field(
        ..., description="% of claims auto-approved without manual review"
    )
    overall_loss_ratio: float
    weekly_premium_revenue_inr: Decimal
    weekly_payout_total_inr: Decimal