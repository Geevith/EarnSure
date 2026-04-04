from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

# ---------------------------------------------------------------------------
# Password Hashing
# ---------------------------------------------------------------------------
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain: str) -> str:
    return pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ---------------------------------------------------------------------------
# JWT Tokens (for rider / admin sessions)
# ---------------------------------------------------------------------------
def create_access_token(
    subject: str,
    role: str = "rider",
    expires_delta: Optional[timedelta] = None,
) -> str:
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    payload = {
        "sub": subject,
        "role": role,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        return payload
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired token: {exc}",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ---------------------------------------------------------------------------
# FastAPI dependency: Bearer JWT
# ---------------------------------------------------------------------------
bearer_scheme = HTTPBearer(auto_error=True)


async def get_current_rider(
    credentials: HTTPAuthorizationCredentials = Security(bearer_scheme),
) -> dict:
    """Validates JWT and returns the decoded payload."""
    payload = decode_access_token(credentials.credentials)
    if payload.get("role") not in ("rider", "admin"):
        raise HTTPException(status_code=403, detail="Insufficient role")
    return payload


async def require_admin(
    credentials: HTTPAuthorizationCredentials = Security(bearer_scheme),
) -> dict:
    payload = decode_access_token(credentials.credentials)
    if payload.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return payload


# ---------------------------------------------------------------------------
# FastAPI dependency: Internal API Key (for webhook & Celery callbacks)
# ---------------------------------------------------------------------------
api_key_header = APIKeyHeader(name=settings.API_KEY_HEADER, auto_error=True)


async def verify_internal_api_key(api_key: str = Security(api_key_header)) -> str:
    if api_key != settings.INTERNAL_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid internal API key",
        )
    return api_key


# ---------------------------------------------------------------------------
# HMAC Signature Validation (Zomato / Swiggy webhooks)
# ---------------------------------------------------------------------------
import hashlib
import hmac


def verify_webhook_signature(
    payload_bytes: bytes,
    received_signature: str,
    secret: str,
) -> bool:
    """
    Validates HMAC-SHA256 signature sent by Zomato/Swiggy.
    Expected header format: sha256=<hex_digest>
    """
    expected = hmac.new(
        secret.encode("utf-8"),
        payload_bytes,
        hashlib.sha256,
    ).hexdigest()
    received_clean = received_signature.replace("sha256=", "")
    return hmac.compare_digest(expected, received_clean)