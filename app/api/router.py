from fastapi import APIRouter

from app.api.v1 import admin, policies, webhooks, auth

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/v1")
api_router.include_router(policies.router, prefix="/v1")
api_router.include_router(webhooks.router, prefix="/v1")
api_router.include_router(admin.router, prefix="/v1")