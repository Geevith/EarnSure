from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool
from app.core.config import settings

# ---------------------------------------------------------------------------
# 1. Main App Engine (FastAPI)
# ---------------------------------------------------------------------------
# Used by the web server. Uses a pool for high performance.
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DB_ECHO,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
    pool_timeout=settings.DB_POOL_TIMEOUT,
    pool_pre_ping=True,
    future=True,
)

# ---------------------------------------------------------------------------
# 2. Worker Engine Factory (Celery)
# ---------------------------------------------------------------------------
def get_worker_engine():
    """
    Returns a fresh engine with NullPool.
    CRITICAL: Celery tasks running in separate processes must not share 
    a connection pool. NullPool ensures each task opens/closes its own connection.
    """
    return create_async_engine(
        settings.DATABASE_URL,
        poolclass=NullPool,
        echo=settings.DB_ECHO,
        future=True
    )

# ---------------------------------------------------------------------------
# 3. Session Factory
# ---------------------------------------------------------------------------
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
)

# ---------------------------------------------------------------------------
# 4. FastAPI Dependency
# ---------------------------------------------------------------------------
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency used in FastAPI routes.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            # We handle commits manually in services, but this provides safety
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()