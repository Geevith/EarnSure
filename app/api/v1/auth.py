"""
Admin Authentication Routes

POST /api/v1/auth/login    — Verify credentials, return JWT
POST /api/v1/auth/register — Create new admin (superadmin-only in production)
GET  /api/v1/auth/me       — Return current admin profile from JWT
"""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import (
    create_access_token,
    get_current_rider,          # re-used — payload shape is the same
    hash_password,
    pwd_context,
    require_admin,
    verify_password,
)
from app.db.session import get_db
from app.models.admin import Admin
from app.schemas.auth import AdminResponse, LoginRequest, RegisterRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["Auth"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# POST /login
# ---------------------------------------------------------------------------

@router.post("/login", response_model=TokenResponse)
async def login(
    body: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticates an admin user and returns a signed JWT.

    1. Look up admin by email
    2. Verify bcrypt password hash
    3. Reject if account is inactive
    4. Update last_login_at
    5. Return signed JWT with role='admin'
    """
    result = await db.execute(select(Admin).where(Admin.email == body.email))
    admin = result.scalar_one_or_none()

    # Constant-time failure to prevent email enumeration
    if not admin or not verify_password(body.password, admin.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is inactive. Contact your superadmin.",
        )

    # Update last login timestamp
    admin.last_login_at = datetime.now(timezone.utc)

    token = create_access_token(
        subject=str(admin.id),
        role="admin",
    )

    logger.info("Admin login: %s (id=%s)", admin.email, admin.id)

    return TokenResponse(
        access_token=token,
        token_type="bearer",
        expires_in_seconds=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        admin_id=admin.id,
        email=admin.email,
        full_name=admin.full_name,
        is_superadmin=admin.is_superadmin,
    )


# ---------------------------------------------------------------------------
# POST /register
# ---------------------------------------------------------------------------

@router.post(
    "/register",
    response_model=AdminResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register(
    body: RegisterRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Creates a new admin account.

    NOTE FOR PRODUCTION: Gate this endpoint behind `require_admin` or an
    invite-token system so only superadmins can create new admins.
    For the initial seed, this remains open — protect it via network policy
    or add `_: dict = Depends(require_admin)` as a parameter.
    """
    # Check for duplicate email
    existing = await db.execute(select(Admin).where(Admin.email == body.email))
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An admin with this email already exists",
        )

    admin = Admin(
        email=body.email,
        hashed_password=hash_password(body.password),
        full_name=body.full_name,
        is_active=True,
        is_superadmin=body.is_superadmin,
    )
    db.add(admin)
    await db.flush()
    await db.refresh(admin)

    logger.info("Admin registered: %s (id=%s)", admin.email, admin.id)

    return AdminResponse(
        id=admin.id,
        email=admin.email,
        full_name=admin.full_name,
        is_active=admin.is_active,
        is_superadmin=admin.is_superadmin,
        created_at=admin.created_at,
    )


# ---------------------------------------------------------------------------
# GET /me
# ---------------------------------------------------------------------------

@router.get("/me", response_model=AdminResponse)
async def get_me(
    current_user: dict = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    """Returns the authenticated admin's profile from the JWT subject claim."""
    from uuid import UUID

    admin_id = UUID(current_user["sub"])
    result = await db.execute(select(Admin).where(Admin.id == admin_id))
    admin = result.scalar_one_or_none()

    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")

    return AdminResponse(
        id=admin.id,
        email=admin.email,
        full_name=admin.full_name,
        is_active=admin.is_active,
        is_superadmin=admin.is_superadmin,
        created_at=admin.created_at,
    )