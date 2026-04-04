from pydantic_settings import BaseSettings, SettingsConfigDict
from functools import lru_cache
from typing import List


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # --- Application ---
    APP_NAME: str = "EarnSure Backend"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "development"  # Changed to development for local testing

    # --- Security ---
    SECRET_KEY: str = "CHANGE_ME_IN_PRODUCTION_USE_SECRETS_MANAGER"
    API_KEY_HEADER: str = "X-API-Key"
    INTERNAL_API_KEY: str = "earnsure-internal-key-change-me"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    # --- Database (FIXED FOR DOCKER) ---
    DATABASE_URL: str = (
        "postgresql+asyncpg://earnsure:earnsure_pass@db:5432/earnsure_db"
    )
    DB_POOL_SIZE: int = 20
    DB_MAX_OVERFLOW: int = 10
    DB_POOL_TIMEOUT: int = 30
    DB_ECHO: bool = False

    # --- Redis / Celery (FIXED FOR DOCKER) ---
    REDIS_URL: str = "redis://redis:6379/0"
    CELERY_BROKER_URL: str = "redis://redis:6379/0"
    CELERY_RESULT_BACKEND: str = "redis://redis:6379/1"
    CELERY_TASK_SERIALIZER: str = "json"
    CELERY_RESULT_SERIALIZER: str = "json"
    CELERY_TIMEZONE: str = "Asia/Kolkata"

    # --- CORS ---
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "https://admin.earnsure.in",
        "https://dashboard.earnsure.in",
    ]

    # --- Weather API (Visual Crossing - Free Tier) ---
    WEATHER_API_KEY: str = "YOUR_VISUAL_CROSSING_API_KEY"
    WEATHER_API_BASE_URL: str = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline"
    WEATHER_RAIN_THRESHOLD_MM: float = 25.0
    WEATHER_HEAT_THRESHOLD_C: float = 45.0

    # --- Traffic API (TomTom - Free Tier) ---
    TOMTOM_API_KEY: str = "YOUR_TOMTOM_API_KEY"
    TOMTOM_BASE_URL: str = "https://api.tomtom.com/traffic/services/4/flowSegmentData"
    TRAFFIC_CONGESTION_THRESHOLD: float = 0.2

    # --- Events / NLP (NewsAPI + PredictHQ trial) ---
    NEWS_API_KEY: str = "YOUR_NEWS_API_KEY"
    NEWS_API_BASE_URL: str = "https://newsapi.org/v2/everything"
    PREDICT_HQ_API_KEY: str = "YOUR_PREDICTHQ_API_KEY"
    PREDICT_HQ_BASE_URL: str = "https://api.predicthq.com/v1/events"

    # --- HuggingFace (Social NLP) ---
    HF_API_TOKEN: str = "YOUR_HUGGINGFACE_TOKEN"
    HF_NLP_MODEL: str = "cardiffnlp/twitter-roberta-base-sentiment-latest"
    HF_INFERENCE_URL: str = "https://api-inference.huggingface.co/models"
    NLP_DISRUPTION_CONFIDENCE_THRESHOLD: float = 0.65

    # --- Razorpay ---
    RAZORPAY_KEY_ID: str = "YOUR_RAZORPAY_KEY_ID"
    RAZORPAY_KEY_SECRET: str = "YOUR_RAZORPAY_KEY_SECRET"
    RAZORPAY_ACCOUNT_NUMBER: str = "YOUR_RAZORPAYХ_ACCOUNT"
    RAZORPAY_BASE_URL: str = "https://api.razorpay.com/v1"
    RAZORPAY_PAYOUT_MODE: str = "UPI"

    # --- Payout Rules ---
    MAX_PAYOUT_PERCENTAGE_OF_HOURLY_RATE: float = 0.80
    DEFAULT_HOURLY_RATE_INR: float = 200.0
    DISRUPTION_WINDOW_HOURS: float = 2.0

    # --- Pricing Engine ---
    BASE_PREMIUM_INR: float = 60.0
    STREAK_DISCOUNT_WEEKS: int = 4
    STREAK_DISCOUNT_RATE: float = 0.15
    MAX_WEEKLY_PREMIUM_INR: float = 200.0
    MIN_WEEKLY_PREMIUM_INR: float = 40.0

    # --- H3 Grid ---
    H3_RESOLUTION: int = 8
    H3_INDIA_CENTER_LAT: float = 20.5937
    H3_INDIA_CENTER_LNG: float = 78.9629

    # --- Fraud Detection ---
    CLAIM_CLUSTERING_WINDOW_SECONDS: int = 3
    CLAIM_CLUSTERING_MAX_COUNT: int = 50
    WIFI_BSSID_MAX_OVERLAP: int = 50
    VIBRATION_FLAT_THRESHOLD_HZ: float = 0.5
    GPS_ACCURACY_SPOOF_THRESHOLD_M: float = 2.0
    DUPLICATE_CLAIM_WINDOW_HOURS: int = 6

    # --- Celery Polling ---
    ZONE_POLL_INTERVAL_SECONDS: int = 300
    ACTIVE_ZONE_BATCH_SIZE: int = 100

    # --- Zomato/Swiggy Webhook ---
    WEBHOOK_SECRET_ZOMATO: str = "ZOMATO_WEBHOOK_HMAC_SECRET"
    WEBHOOK_SECRET_SWIGGY: str = "SWIGGY_WEBHOOK_HMAC_SECRET"
    PLATFORM_5XX_THRESHOLD_MINUTES: int = 45

    # --- Peak Hours (IST) ---
    PEAK_HOURS: List[List[int]] = [[12, 15], [19, 23]]


@lru_cache()
def get_settings() -> Settings:
    return Settings()

settings = get_settings()