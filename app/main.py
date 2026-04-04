"""
EarnSure FastAPI Application Factory

Startup sequence:
  1. Load settings (Pydantic BaseSettings)
  2. Create async DB engine
  3. Register middleware (CORS, request ID, timing)
  4. Mount API routers
  5. Register startup/shutdown lifecycle events
"""
from app.db.base import Base
from app.models.admin import Admin
import logging
import time
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.router import api_router
from app.core.config import settings
from app.db.session import engine

from fastapi.encoders import jsonable_encoder

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s - %(message)s",
)
logger = logging.getLogger("earnsure.main")


# ---------------------------------------------------------------------------
# Lifespan (replaces deprecated on_event startup/shutdown)
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Startup: verify DB connectivity, build tables, warm up Redis connection.
    Shutdown: dispose DB engine connection pool.
    """
    logger.info("EarnSure backend starting up — env=%s", settings.ENVIRONMENT)

    # Verify database connectivity AND Auto-build Tables
    try:
        # We use engine.begin() so it opens a transaction to create the tables
        async with engine.begin() as conn:
            from sqlalchemy import text
            await conn.execute(text("SELECT 1"))
            
            logger.info("Auto-building database tables if missing...")
            await conn.run_sync(Base.metadata.create_all)
            
        logger.info("Database connectivity and initialization: OK")
    except Exception as exc:
        logger.critical("Database connection FAILED on startup: %s", exc)
        raise

    # Verify Redis connectivity
    try:
        import redis as redis_lib
        r = redis_lib.Redis.from_url(settings.REDIS_URL)
        r.ping()
        r.close()
        logger.info("Redis connectivity: OK")
    except Exception as exc:
        logger.warning("Redis connectivity check failed: %s — Celery tasks may not work", exc)

    yield  # Application runs here

    # Shutdown
    logger.info("EarnSure backend shutting down — disposing DB engine pool")
    await engine.dispose()


# ---------------------------------------------------------------------------
# App Factory
# ---------------------------------------------------------------------------
def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        version=settings.APP_VERSION,
        description=(
            "B2B2C Embedded Parametric Insurance Platform for Food Delivery Riders. "
            "Dual-Key Oracle triggers instant UPI payouts via H3 geospatial zones."
        ),
        docs_url="/docs" if settings.DEBUG else None,
        redoc_url="/redoc" if settings.DEBUG else None,
        openapi_url="/openapi.json" if settings.DEBUG else None,
        lifespan=lifespan,
    )

    # ------------------------------------------------------------------
    # CORS
    # ------------------------------------------------------------------
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    # ------------------------------------------------------------------
    # Request ID + Timing middleware
    # ------------------------------------------------------------------
    @app.middleware("http")
    async def request_context_middleware(request: Request, call_next):
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id
        start = time.perf_counter()

        response = await call_next(request)

        duration_ms = (time.perf_counter() - start) * 1000
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Response-Time-Ms"] = f"{duration_ms:.2f}"

        logger.info(
            "%s %s → %d (%.1f ms) [%s]",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
            request_id,
        )
        return response

    # ------------------------------------------------------------------
    # Global exception handlers
    # ------------------------------------------------------------------
    from fastapi.exceptions import RequestValidationError
    from pydantic import ValidationError

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=jsonable_encoder({"detail": exc.errors()}) # <--- Safely encodes the error
        )

    @app.exception_handler(Exception)
    async def global_exception_handler(request: Request, exc: Exception):
        logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "success": False,
                "error": "Internal server error",
                "request_id": getattr(request.state, "request_id", None),
            },
        )

    # ------------------------------------------------------------------
    # Routers
    # ------------------------------------------------------------------
    app.include_router(api_router, prefix="/api")

    # ------------------------------------------------------------------
    # Health check (unauthenticated — for load balancer / k8s probes)
    # ------------------------------------------------------------------
    @app.get("/health", tags=["Health"], include_in_schema=False)
    async def health_check():
        return {
            "status": "ok",
            "version": settings.APP_VERSION,
            "environment": settings.ENVIRONMENT,
        }

    @app.get("/", include_in_schema=False)
    async def root():
        return {
            "service": settings.APP_NAME,
            "version": settings.APP_VERSION,
            "docs": "/docs" if settings.DEBUG else "disabled in production",
        }

    logger.info("EarnSure app factory complete — %d routes registered", len(app.routes))
    return app


# ---------------------------------------------------------------------------
# ASGI entry point
# ---------------------------------------------------------------------------
app = create_app()