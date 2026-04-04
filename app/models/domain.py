"""
SQLAlchemy 2.0 ORM models — all tables EarnSure requires.

Tables:
  - riders          — Delivery rider profiles and trust scores
  - hex_zones       — H3 hexagonal zone metadata and risk scores
  - policies        — Weekly insurance policies purchased by riders
  - claims          — Parametric payout claims (auto-triggered or manual)
  - disruption_events — Oracle-validated weather/traffic/platform events
  - device_fingerprints — Anti-spoofing device state snapshots
  - payout_transactions — Razorpay payout audit trail
"""

import uuid
from datetime import datetime, timezone
from decimal import Decimal
from enum import Enum as PyEnum

from geoalchemy2 import Geometry
from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------
class RiderStatus(str, PyEnum):
    ACTIVE = "active"
    SUSPENDED = "suspended"
    PENDING_KYC = "pending_kyc"


class PolicyStatus(str, PyEnum):
    ACTIVE = "active"
    EXPIRED = "expired"
    CANCELLED = "cancelled"


class ClaimStatus(str, PyEnum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    PAID = "paid"
    FLAGGED = "flagged"


class DisruptionType(str, PyEnum):
    MONSOON = "monsoon"
    HEATWAVE = "heatwave"
    TRAFFIC_GRIDLOCK = "traffic_gridlock"
    PLATFORM_OUTAGE = "platform_outage"
    CIVIC_BARRICADE = "civic_barricade"


class DisruptionEventStatus(str, PyEnum):
    PENDING_CONSENSUS = "pending_consensus"   # Primary key fired, awaiting NLP
    CONFIRMED = "confirmed"                    # Dual-key consensus achieved
    REJECTED = "rejected"                      # NLP contradiction / false positive
    PAYOUTS_PROCESSING = "payouts_processing"
    PAYOUTS_COMPLETE = "payouts_complete"


class PayoutStatus(str, PyEnum):
    QUEUED = "queued"
    PROCESSING = "processing"
    SUCCESS = "success"
    FAILED = "failed"
    REVERSED = "reversed"


class FraudRiskLevel(str, PyEnum):
    LOW = "low"        # Auto-approve
    MEDIUM = "medium"  # Soft flag — request 1 delivery confirmation
    HIGH = "high"      # Hard block


class Platform(str, PyEnum):
    SWIGGY = "swiggy"
    ZOMATO = "zomato"


# ---------------------------------------------------------------------------
# Utility: UTC-aware datetime default
# ---------------------------------------------------------------------------
def utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Riders
# ---------------------------------------------------------------------------
class Rider(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    phone: Mapped[str] = mapped_column(String(15), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    platform: Mapped[Platform] = mapped_column(Enum(Platform), nullable=False)
    city: Mapped[str] = mapped_column(String(60), nullable=False)

    # UPI / Bank details (encrypted at rest in production via Vault)
    upi_id: Mapped[str | None] = mapped_column(String(100))
    bank_account_number: Mapped[str | None] = mapped_column(String(30))
    bank_ifsc: Mapped[str | None] = mapped_column(String(15))

    # Pricing factors
    historical_claims_factor: Mapped[Decimal] = mapped_column(
        Numeric(5, 4), default=Decimal("1.0000"), nullable=False,
        comment="Multiplier derived from past claim frequency. >1.0 = higher risk."
    )
    avg_hourly_rate_inr: Mapped[Decimal] = mapped_column(
        Numeric(8, 2), default=Decimal("200.00"), nullable=False,
        comment="Rolling 30-day average hourly earning used for payout cap."
    )
    consecutive_streak_weeks: Mapped[int] = mapped_column(
        Integer, default=0, nullable=False,
        comment="Consecutive weeks with active policy — drives streak discount."
    )

    # Trust & fraud
    trust_score: Mapped[Decimal] = mapped_column(
        Numeric(4, 2), default=Decimal("5.00"), nullable=False,
        comment="0.00 - 10.00. Used in fraud gating logic."
    )
    status: Mapped[RiderStatus] = mapped_column(
        Enum(RiderStatus), default=RiderStatus.PENDING_KYC, nullable=False
    )
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False
    )

    # Relationships
    policies: Mapped[list["Policy"]] = relationship(back_populates="rider")
    claims: Mapped[list["Claim"]] = relationship(back_populates="rider")
    device_fingerprints: Mapped[list["DeviceFingerprint"]] = relationship(
        back_populates="rider"
    )

    __table_args__ = (
        Index("ix_rider_city_status", "city", "status"),
    )


# ---------------------------------------------------------------------------
# Hex Zones (H3 Grid)
# ---------------------------------------------------------------------------
class HexZone(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    h3_index: Mapped[str] = mapped_column(
        String(20), unique=True, nullable=False, index=True,
        comment="Uber H3 cell index string at resolution 8."
    )
    city: Mapped[str] = mapped_column(String(60), nullable=False, index=True)
    district: Mapped[str | None] = mapped_column(String(80))

    # PostGIS geometry for spatial queries
    centroid: Mapped[Geometry | None] = mapped_column(
        Geometry(geometry_type="POINT", srid=4326)
    )
    boundary: Mapped[Geometry | None] = mapped_column(
        Geometry(geometry_type="POLYGON", srid=4326)
    )

    # Risk scoring
    zone_risk_score: Mapped[Decimal] = mapped_column(
        Numeric(4, 3), default=Decimal("0.500"), nullable=False,
        comment="0.000 - 1.000. Calibrated from historical disruption frequency."
    )
    monsoon_risk: Mapped[Decimal] = mapped_column(
        Numeric(4, 3), default=Decimal("0.500"), nullable=False
    )
    heat_risk: Mapped[Decimal] = mapped_column(
        Numeric(4, 3), default=Decimal("0.500"), nullable=False
    )
    traffic_risk: Mapped[Decimal] = mapped_column(
        Numeric(4, 3), default=Decimal("0.500"), nullable=False
    )

    # Live state
    active_policy_count: Mapped[int] = mapped_column(Integer, default=0)
    is_active_disruption: Mapped[bool] = mapped_column(Boolean, default=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    disruption_events: Mapped[list["DisruptionEvent"]] = relationship(
        back_populates="hex_zone"
    )

    __table_args__ = (
        Index("ix_hex_zone_city_risk", "city", "zone_risk_score"),
    )


# ---------------------------------------------------------------------------
# Policies
# ---------------------------------------------------------------------------
class Policy(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    rider_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rider.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    hex_zone_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("hex_zone.id", ondelete="RESTRICT"), nullable=False
    )

    # Coverage window
    start_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    end_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    # Financials (stored in paise → avoid float drift)
    weekly_premium_inr: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    max_payout_inr: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    platform: Mapped[Platform] = mapped_column(Enum(Platform), nullable=False)
    status: Mapped[PolicyStatus] = mapped_column(
        Enum(PolicyStatus), default=PolicyStatus.ACTIVE, nullable=False
    )

    # Pricing audit
    base_rate_used: Mapped[Decimal] = mapped_column(Numeric(8, 2))
    disruption_prob_used: Mapped[Decimal] = mapped_column(Numeric(5, 4))
    zone_risk_used: Mapped[Decimal] = mapped_column(Numeric(5, 4))
    historical_claims_factor_used: Mapped[Decimal] = mapped_column(Numeric(5, 4))
    streak_discount_applied: Mapped[bool] = mapped_column(Boolean, default=False)

    # Payment reference
    razorpay_order_id: Mapped[str | None] = mapped_column(String(60))
    razorpay_payment_id: Mapped[str | None] = mapped_column(String(60))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    rider: Mapped["Rider"] = relationship(back_populates="policies")
    hex_zone: Mapped["HexZone"] = relationship()
    claims: Mapped[list["Claim"]] = relationship(back_populates="policy")

    __table_args__ = (
        Index("ix_policy_rider_status_end", "rider_id", "status", "end_date"),
    )


# ---------------------------------------------------------------------------
# Disruption Events (Oracle outputs)
# ---------------------------------------------------------------------------
class DisruptionEvent(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    hex_zone_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("hex_zone.id", ondelete="CASCADE"), nullable=False, index=True
    )
    disruption_type: Mapped[DisruptionType] = mapped_column(
        Enum(DisruptionType), nullable=False
    )
    status: Mapped[DisruptionEventStatus] = mapped_column(
        Enum(DisruptionEventStatus),
        default=DisruptionEventStatus.PENDING_CONSENSUS,
        nullable=False,
    )

    # Primary Key data (Weather API)
    primary_trigger_value: Mapped[Decimal | None] = mapped_column(
        Numeric(8, 3),
        comment="Raw sensor value: e.g. 27.4 mm/hr rainfall or 46.2 °C"
    )
    primary_trigger_source: Mapped[str | None] = mapped_column(String(80))
    primary_triggered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Secondary Key data (NLP Social Sentinel)
    secondary_nlp_confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 4))
    secondary_nlp_source_url: Mapped[str | None] = mapped_column(Text)
    secondary_nlp_snippet: Mapped[str | None] = mapped_column(Text)
    secondary_triggered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    # Dual-key consensus
    consensus_achieved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    total_riders_affected: Mapped[int] = mapped_column(Integer, default=0)
    total_payout_inr: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0"))

    # Raw API responses for audit
    raw_weather_payload: Mapped[dict | None] = mapped_column(JSONB)
    raw_nlp_payload: Mapped[dict | None] = mapped_column(JSONB)

    # Platform outage tracking
    webhook_platform: Mapped[Platform | None] = mapped_column(Enum(Platform))
    webhook_first_5xx_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    hex_zone: Mapped["HexZone"] = relationship(back_populates="disruption_events")
    claims: Mapped[list["Claim"]] = relationship(back_populates="disruption_event")

    __table_args__ = (
        Index("ix_disruption_hex_status", "hex_zone_id", "status"),
        Index("ix_disruption_type_created", "disruption_type", "created_at"),
    )


# ---------------------------------------------------------------------------
# Claims
# ---------------------------------------------------------------------------
class Claim(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    rider_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rider.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    policy_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("policy.id", ondelete="RESTRICT"), nullable=False
    )
    disruption_event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("disruption_event.id", ondelete="RESTRICT"), nullable=False
    )

    status: Mapped[ClaimStatus] = mapped_column(
        Enum(ClaimStatus), default=ClaimStatus.PENDING, nullable=False, index=True
    )
    fraud_risk_level: Mapped[FraudRiskLevel] = mapped_column(
        Enum(FraudRiskLevel), default=FraudRiskLevel.LOW, nullable=False
    )

    # Payout calculation (all in INR)
    claimed_duration_hours: Mapped[Decimal] = mapped_column(Numeric(4, 2), nullable=False)
    hourly_rate_used_inr: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    calculated_payout_inr: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    approved_payout_inr: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))

    # Fraud evidence snapshot (denormalised from device fingerprint at claim time)
    device_fingerprint_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("device_fingerprint.id", ondelete="SET NULL")
    )
    fraud_signals: Mapped[dict | None] = mapped_column(
        JSONB, comment="Snapshot of all fraud signals at claim time."
    )

    rejection_reason: Mapped[str | None] = mapped_column(Text)
    admin_notes: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    rider: Mapped["Rider"] = relationship(back_populates="claims")
    policy: Mapped["Policy"] = relationship(back_populates="claims")
    disruption_event: Mapped["DisruptionEvent"] = relationship(back_populates="claims")
    payout: Mapped["PayoutTransaction | None"] = relationship(back_populates="claim")

    __table_args__ = (
        # Strict duplicate prevention: one claim per rider per disruption event
        UniqueConstraint("rider_id", "disruption_event_id", name="uq_claim_rider_event"),
        Index("ix_claim_status_created", "status", "created_at"),
    )


# ---------------------------------------------------------------------------
# Device Fingerprints (Anti-Spoofing)
# ---------------------------------------------------------------------------
class DeviceFingerprint(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    rider_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rider.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # Stable device identifiers
    device_id: Mapped[str] = mapped_column(
        String(120), nullable=False, index=True,
        comment="Android ANDROID_ID or iOS identifierForVendor"
    )
    device_model: Mapped[str | None] = mapped_column(String(80))
    os_version: Mapped[str | None] = mapped_column(String(30))
    app_version: Mapped[str | None] = mapped_column(String(20))

    # GPS state
    gps_lat: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    gps_lng: Mapped[Decimal | None] = mapped_column(Numeric(10, 7))
    gps_accuracy_meters: Mapped[Decimal | None] = mapped_column(Numeric(8, 3))
    gps_altitude_m: Mapped[Decimal | None] = mapped_column(Numeric(8, 2))
    gps_speed_mps: Mapped[Decimal | None] = mapped_column(Numeric(6, 3))

    # Physics sensors (anti-spoofing core)
    accelerometer_magnitude_hz: Mapped[Decimal | None] = mapped_column(
        Numeric(8, 4), comment="Std-dev of accelerometer over 5-second window."
    )
    gyroscope_active: Mapped[bool | None] = mapped_column(Boolean)
    is_charging: Mapped[bool | None] = mapped_column(Boolean)
    battery_level_pct: Mapped[int | None] = mapped_column(Integer)
    charging_type: Mapped[str | None] = mapped_column(
        String(20), comment="usb | ac | wireless | none"
    )

    # Network triangulation
    cell_tower_id: Mapped[str | None] = mapped_column(String(40))
    cell_mcc: Mapped[str | None] = mapped_column(String(5))
    cell_mnc: Mapped[str | None] = mapped_column(String(5))
    wifi_bssid: Mapped[str | None] = mapped_column(String(20))
    wifi_ssid: Mapped[str | None] = mapped_column(String(64))

    # Computed fraud signals
    is_gps_spoofed: Mapped[bool] = mapped_column(Boolean, default=False)
    is_flat_sensor: Mapped[bool] = mapped_column(Boolean, default=False)
    is_ac_charging_anomaly: Mapped[bool] = mapped_column(Boolean, default=False)
    is_bssid_farm: Mapped[bool] = mapped_column(Boolean, default=False)
    fraud_risk_level: Mapped[FraudRiskLevel] = mapped_column(
        Enum(FraudRiskLevel), default=FraudRiskLevel.LOW
    )
    fraud_score: Mapped[Decimal] = mapped_column(Numeric(5, 4), default=Decimal("0.0000"))

    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    rider: Mapped["Rider"] = relationship(back_populates="device_fingerprints")

    __table_args__ = (
        Index("ix_device_fp_device_id_captured", "device_id", "captured_at"),
        Index("ix_device_fp_wifi_bssid", "wifi_bssid"),
    )


# ---------------------------------------------------------------------------
# Payout Transactions (Razorpay audit trail)
# ---------------------------------------------------------------------------
class PayoutTransaction(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    claim_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("claim.id", ondelete="RESTRICT"),
        nullable=False, unique=True
    )
    rider_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rider.id", ondelete="RESTRICT"), nullable=False, index=True
    )

    amount_inr: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False)
    amount_paise: Mapped[int] = mapped_column(
        BigInteger, nullable=False,
        comment="amount_inr * 100. Razorpay uses paise."
    )
    payout_mode: Mapped[str] = mapped_column(String(10), default="UPI")
    upi_id_used: Mapped[str | None] = mapped_column(String(100))

    # Razorpay references
    razorpay_payout_id: Mapped[str | None] = mapped_column(String(60), unique=True, index=True)
    razorpay_fund_account_id: Mapped[str | None] = mapped_column(String(60))
    razorpay_contact_id: Mapped[str | None] = mapped_column(String(60))
    razorpay_batch_id: Mapped[str | None] = mapped_column(String(60))

    status: Mapped[PayoutStatus] = mapped_column(
        Enum(PayoutStatus), default=PayoutStatus.QUEUED, nullable=False, index=True
    )
    failure_reason: Mapped[str | None] = mapped_column(Text)
    raw_response: Mapped[dict | None] = mapped_column(JSONB)

    initiated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    claim: Mapped["Claim"] = relationship(back_populates="payout")

    __table_args__ = (
        Index("ix_payout_status_initiated", "status", "initiated_at"),
    )