from __future__ import annotations

import os
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="KAVACH_", extra="ignore")

    cors_origins: str = os.environ.get(
        "KAVACH_CORS_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173,http://localhost:3000,"
        "http://localhost:8000,http://127.0.0.1:8000",
    )
    url_phish_high: float = 0.55
    url_phish_review: float = 0.35
    apk_malware_high: float = 0.45
    apk_malware_review: float = 0.28


@lru_cache
def get_settings() -> Settings:
    return Settings()


def cors_origins_list() -> list[str]:
    raw = get_settings().cors_origins
    return [o.strip() for o in raw.split(",") if o.strip()]
