from __future__ import annotations

import asyncio
import sys
from pathlib import Path
from typing import Any

_BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(_BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(_BACKEND_ROOT))

from apk_ml_model.apk_runtime import (
    APK_FEATURE_NAMES,
    OFFICIAL_SBI_CERT_SHA256,
    extract_apk_features,
    is_impersonating_sbi,
    load_apk_artifacts,
    malware_probability,
)
from url_ml_model.url_runtime import (
    extract_features,
    load_url_artifacts,
    phishing_probability,
)

_lock = asyncio.Lock()
_url_model: Any = None
_url_names: list[str] | None = None
_apk_model: Any = None
_apk_names: list[str] | None = None

async def ensure_models() -> None:
    global _url_model, _url_names, _apk_model, _apk_names
    async with _lock:
        if _url_model is None:
            _url_model, _url_names = load_url_artifacts()
        if _apk_model is None:
            _apk_model, _apk_names = load_apk_artifacts()

def _apk_permissions(path: str) -> list[str]:
    try:
        from androguard.misc import AnalyzeAPK

        apk, _, _ = AnalyzeAPK(path)
        return sorted(list(apk.get_permissions() or []))
    except Exception:
        return []

def _cert_official(cert_sha: str) -> bool:
    if not cert_sha:
        return False
    return cert_sha.lower().strip() == OFFICIAL_SBI_CERT_SHA256.lower().strip()

def _host_from_url(url: str) -> str | None:
    try:
        from urllib.parse import urlparse

        u = url.strip()
        p = urlparse(u if "://" in u else "http://" + u)
        h = (p.netloc or "").split("@")[-1].split(":")[0].lower()
        return h or None
    except Exception:
        return None

async def scan_url_ml(
    url: str, settings: Any
) -> tuple[str, float, float, dict[str, Any]]:
    await ensure_models()
    assert _url_model is not None and _url_names is not None
    feats = extract_features(url)
    prob = float(
        phishing_probability(url, _url_model, _url_names, apply_trusted_domain_cap=True)
    )
    hi = float(settings.url_phish_high)
    lo = float(settings.url_phish_review)
    if prob >= hi:
        verdict = "phishing"
        conf = min(0.99, 0.55 + prob * 0.45)
    elif prob >= lo:
        verdict = "review"
        conf = min(0.85, 0.4 + prob * 0.5)
    else:
        verdict = "safe"
        conf = min(0.99, 1.0 - prob * 0.8)
    return verdict, conf, prob, {k: feats.get(k, 0) for k in _url_names}

async def scan_apk_ml(
    path: str, settings: Any
) -> tuple[
    str,
    float,
    dict[str, Any],
    str,
    bool,
    str,
    dict[str, Any],
    list[str],
]:
    await ensure_models()
    assert _apk_model is not None and _apk_names is not None
    feats = extract_apk_features(path)
    perms = _apk_permissions(path)
    mal = float(malware_probability(feats, _apk_model, _apk_names))
    imperson = bool(is_impersonating_sbi(feats))
    cert = str(feats.get("cert_sha256") or "")
    pkg = str(feats.get("package_name") or "")
    official = _cert_official(cert)

    hi = float(settings.apk_malware_high)
    mid = float(settings.apk_malware_review)

    if official and mal < hi and not imperson:
        verdict = "safe"
        conf = min(0.99, 1.0 - mal * 0.6)
    elif (not official) and (mal >= hi or imperson):
        verdict = "fake_apk"
        conf = min(0.99, max(mal, 0.55 if imperson else mal))
    elif mal >= mid or imperson:
        verdict = "review"
        conf = min(0.9, max(mal, 0.45))
    else:
        verdict = "safe"
        conf = min(0.95, 1.0 - mal)

    behavior = build_behavior_analysis(feats, perms, mal)
    return verdict, conf, feats, cert, official, pkg, behavior, perms

def build_behavior_analysis(
    feats: dict[str, Any], perms: list[str], malware_prob: float
) -> dict[str, Any]:
    """Static + permission heuristics aligned with dashboard / Flutter cards."""
    perm_set = set(perms)
    dangerous: list[list[str]] = []
    if (
        "android.permission.READ_SMS" in perm_set
        and "android.permission.RECEIVE_SMS" in perm_set
    ):
        dangerous.append(
            ["android.permission.READ_SMS", "android.permission.RECEIVE_SMS"]
        )
    if (
        "android.permission.BIND_ACCESSIBILITY_SERVICE" in perm_set
        and "android.permission.SYSTEM_ALERT_WINDOW" in perm_set
    ):
        dangerous.append(
            [
                "android.permission.BIND_ACCESSIBILITY_SERVICE",
                "android.permission.SYSTEM_ALERT_WINDOW",
            ]
        )
    if (
        "android.permission.CAMERA" in perm_set
        and "android.permission.RECORD_AUDIO" in perm_set
    ):
        dangerous.append(
            ["android.permission.CAMERA", "android.permission.RECORD_AUDIO"]
        )

    high_risk_kw = (
        "BIND_ACCESSIBILITY_SERVICE",
        "BIND_DEVICE_ADMIN",
        "READ_SMS",
        "RECEIVE_SMS",
        "SYSTEM_ALERT_WINDOW",
        "REQUEST_INSTALL_PACKAGES",
        "INSTALL_PACKAGES",
    )
    high_risk = [p for p in perms if any(k in p for k in high_risk_kw)]

    score = float(malware_prob)
    score += 0.08 * min(1.0, len(dangerous) / 3.0)
    score += 0.04 * min(1.0, len(high_risk) / 8.0)
    score += 0.05 * float(feats.get("has_accessibility_service", 0))
    score += 0.05 * float(feats.get("has_bind_device_admin", 0))
    score = float(min(1.0, max(0.0, score)))

    if score >= 0.72 or len(dangerous) >= 2:
        level = "HIGH"
    elif score >= 0.42 or dangerous:
        level = "MEDIUM"
    else:
        level = "LOW"

    return {
        "risk_level": level,
        "behavior_risk_score": round(score, 4),
        "dangerous_combos_detected": dangerous,
        "high_risk_permissions": high_risk[:24],
        "total_permissions": len(perms),
        "malware_model_score": round(malware_prob, 4),
        "static_flags": {
            k: int(feats.get(k, 0))
            for k in APK_FEATURE_NAMES
            if k not in ("cert_sha256", "package_name")
        },
    }
