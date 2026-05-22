from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

class DeviceMeta(BaseModel):
    device_city: str | None = None
    device_state: str | None = None
    device_district: str | None = None
    device_lat: float | None = None
    device_lng: float | None = None

class UrlScanRequest(DeviceMeta):
    url: str = Field(..., min_length=3, max_length=4096)
    source_channel: str = "manual"

class MarkReportedRequest(BaseModel):
    certin: bool = False
    google: bool = False
    cybercrime: bool = False

class BackgroundThreatRequest(DeviceMeta):
    package_name: str
    similarity: float
    source_channel: str = "background"

class ThreatOut(BaseModel):
    id: str
    created_at: str
    threat_type: str
    verdict: str
    confidence: float
    probability: float
    raw_input: str
    source_channel: str
    device_city: str | None = None
    device_state: str | None = None
    device_district: str | None = None
    device_lat: float | None = None
    device_lng: float | None = None
    malicious_domain: str | None = None
    apk_package_name: str | None = None
    apk_sha256: str | None = None
    cert_is_official: bool | None = None
    url_features: dict[str, Any] | None = None
    behavior_risk_level: str | None = None
    behavior_risk_score: float | None = None
    apk_permissions: list[str] | None = None
    behavior_analysis: dict[str, Any] | None = None
    reported_certin: bool = False
    reported_google: bool = False
    reported_cybercrime: bool = False

    class Config:
        extra = "allow"

class ThreatsListResponse(BaseModel):
    total: int
    items: list[dict[str, Any]]

class StatsResponse(BaseModel):
    total_threats_24h: int
    total_threats_all: int
    by_type: dict[str, int]
    by_verdict: dict[str, int]
    by_state: dict[str, int]
