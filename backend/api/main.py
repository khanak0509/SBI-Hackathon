from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, Form, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from api.config import cors_origins_list, get_settings
from api.ml_service import scan_apk_ml, scan_url_ml
from api.reports_service import build_all_reports
from api.schemas import BackgroundThreatRequest, MarkReportedRequest, UrlScanRequest
from api.threat_store import store
from api.ws_manager import manager

app = FastAPI(title="KAVACH API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins_list(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _threat_row_from_url(
    body: UrlScanRequest,
    verdict: str,
    conf: float,
    prob: float,
    feats: dict[str, Any],
) -> dict[str, Any]:
    host = None
    try:
        from urllib.parse import urlparse

        u = body.url.strip()
        p = urlparse(u if "://" in u else "http://" + u)
        host = (p.netloc or "").split("@")[-1].split(":")[0].lower() or None
    except Exception:
        pass
    return {
        "threat_type": "url",
        "verdict": verdict,
        "confidence": round(float(conf), 4),
        "probability": round(float(prob), 4),
        "raw_input": body.url.strip(),
        "source_channel": body.source_channel or "manual",
        "device_city": body.device_city,
        "device_state": body.device_state,
        "device_district": body.device_district,
        "device_lat": body.device_lat,
        "device_lng": body.device_lng,
        "malicious_domain": host,
        "apk_package_name": None,
        "apk_sha256": None,
        "cert_is_official": None,
        "url_features": feats,
        "behavior_risk_level": None,
        "behavior_risk_score": None,
        "apk_permissions": None,
        "behavior_analysis": None,
        "reported_certin": False,
        "reported_google": False,
        "reported_cybercrime": False,
    }


def _threat_row_from_apk(
    source_channel: str,
    verdict: str,
    conf: float,
    mal_prob: float,
    feats: dict[str, Any],
    cert: str,
    file_sha256: str,
    official: bool,
    pkg: str,
    behavior: dict[str, Any],
    perms: list[str],
    device_city: str | None,
    device_state: str | None,
    device_district: str | None,
    device_lat: float | None,
    device_lng: float | None,
    raw_filename: str,
) -> dict[str, Any]:
    return {
        "threat_type": "apk",
        "verdict": verdict,
        "confidence": round(float(conf), 4),
        "probability": round(float(mal_prob), 4),
        "raw_input": raw_filename,
        "source_channel": source_channel or "manual",
        "device_city": device_city,
        "device_state": device_state,
        "device_district": device_district,
        "device_lat": device_lat,
        "device_lng": device_lng,
        "malicious_domain": None,
        "apk_package_name": pkg or None,
        "apk_sha256": file_sha256 or None,
        "apk_cert_sha256": cert or None,
        "cert_is_official": official,
        "url_features": None,
        "behavior_risk_level": behavior.get("risk_level"),
        "behavior_risk_score": behavior.get("behavior_risk_score"),
        "apk_permissions": perms,
        "behavior_analysis": behavior,
        "reported_certin": False,
        "reported_google": False,
        "reported_cybercrime": False,
    }


@app.post("/scan/url")
async def scan_url(body: UrlScanRequest) -> dict[str, Any]:
    settings = get_settings()
    verdict, conf, prob, feats = await scan_url_ml(body.url, settings)
    row = _threat_row_from_url(body, verdict, conf, prob, feats)
    saved = await store.add(row)
    await manager.broadcast_json("new_threat", saved)
    return {
        "verdict": verdict,
        "confidence": round(conf, 4),
        "probability": round(prob, 4),
        "features": feats,
        "threat_id": saved["id"],
    }


@app.post("/scan/apk")
async def scan_apk(
    file: UploadFile = File(...),
    source_channel: str = Form("manual"),
    device_city: str | None = Form(None),
    device_state: str | None = Form(None),
    device_district: str | None = Form(None),
    device_lat: float | None = Form(None),
    device_lng: float | None = Form(None),
) -> dict[str, Any]:
    settings = get_settings()
    suffix = Path(file.filename or "upload.apk").suffix or ".apk"
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    file_sha256 = hashlib.sha256(data).hexdigest()
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    try:
        verdict, conf, feats, cert, official, pkg, behavior, perms = (
            await scan_apk_ml(tmp_path, settings)
        )
        mal_prob = float(behavior.get("malware_model_score", 0))
        row = _threat_row_from_apk(
            source_channel,
            verdict,
            conf,
            mal_prob,
            feats,
            cert,
            file_sha256,
            official,
            pkg,
            behavior,
            perms,
            device_city,
            device_state,
            device_district,
            device_lat,
            device_lng,
            file.filename or "upload.apk",
        )
        saved = await store.add(row)
        await manager.broadcast_json("new_threat", saved)
        feat_out = {
            k: feats.get(k, 0)
            for k in feats
            if k not in ("cert_sha256", "package_name")
        }
        return {
            "verdict": verdict,
            "confidence": round(conf, 4),
            "sha256": cert or file_sha256,
            "apk_file_sha256": file_sha256,
            "cert_is_official": official,
            "package_name": pkg,
            "behavior_analysis": behavior,
            "features": feat_out,
            "threat_id": saved["id"],
        }
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except Exception:
            pass


@app.post("/report/background_threat")
async def report_background_threat(body: BackgroundThreatRequest) -> dict[str, Any]:
    row = {
        "threat_type": "apk",
        "verdict": "fake_apk",
        "confidence": round(float(body.similarity), 4),
        "probability": round(float(body.similarity), 4),
        "raw_input": body.package_name,
        "source_channel": body.source_channel,
        "device_city": body.device_city,
        "device_state": body.device_state,
        "device_district": body.device_district,
        "device_lat": body.device_lat,
        "device_lng": body.device_lng,
        "apk_package_name": body.package_name,
        "cert_is_official": False,
        "reported_certin": False,
        "reported_google": False,
        "reported_cybercrime": False,
    }
    saved = await store.add(row)
    await manager.broadcast_json("new_threat", saved)
    return {"status": "ok", "threat_id": saved["id"]}


@app.get("/threats")
async def list_threats(limit: int = 50) -> dict[str, Any]:
    total, items = await store.list_items(limit=max(1, min(limit, 500)))
    return {"total": total, "items": items}


@app.get("/threats/stats")
async def threats_stats() -> dict[str, Any]:
    return await store.stats()


@app.get("/threats/{threat_id}")
async def get_threat(threat_id: str) -> dict[str, Any]:
    t = await store.get(threat_id)
    if not t:
        raise HTTPException(status_code=404, detail="Threat not found")
    return t


@app.post("/reports/{threat_id}/all")
async def reports_all(threat_id: str) -> dict[str, Any]:
    t = await store.get(threat_id)
    if not t:
        raise HTTPException(status_code=404, detail="Threat not found")
    return build_all_reports(t)


@app.post("/threats/{threat_id}/mark_reported")
async def mark_reported(threat_id: str, body: MarkReportedRequest) -> dict[str, Any]:
    updated = await store.mark_reported(
        threat_id,
        {
            "certin": body.certin,
            "google": body.google,
            "cybercrime": body.cybercrime,
        },
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Threat not found")
    return updated


@app.websocket("/ws/threats")
async def ws_threats(websocket: WebSocket) -> None:
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
