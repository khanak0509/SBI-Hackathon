from __future__ import annotations

from datetime import datetime
from typing import Any

def _ist_now() -> str:
    from datetime import timedelta, timezone

    ist = timezone(timedelta(hours=5, minutes=30))
    return datetime.now(ist).strftime("%d %b %Y %H:%M:%S IST")

def build_all_reports(threat: dict[str, Any]) -> dict[str, Any]:
    tid = threat.get("id", "")
    verdict = threat.get("verdict", "")
    ttype = threat.get("threat_type", "")
    raw = threat.get("raw_input", "")
    conf = float(threat.get("confidence") or 0)
    prob = float(threat.get("probability") or 0)
    loc = ", ".join(
        filter(
            None,
            [
                threat.get("device_city"),
                threat.get("device_district"),
                threat.get("device_state"),
            ],
        )
    )
    pkg = threat.get("apk_package_name")
    sha = threat.get("apk_sha256")
    domain = threat.get("malicious_domain")

    certin: dict[str, Any] = {
        "schema_version": "1.0",
        "reporting_entity": "KAVACH FraudOps Intelligence Center",
        "incident_reference": tid,
        "incident_datetime": threat.get("created_at"),
        "incident_type": "Phishing / Malicious mobile application"
        if ttype == "apk"
        else "Phishing / fraudulent banking URL",
        "severity": "HIGH" if verdict in ("phishing", "fake_apk") else "MEDIUM",
        "affected_sector": "Banking — State Bank of India customers",
        "description": (
            f"Automated KAVACH detection flagged a {ttype} threat with verdict "
            f"{verdict}. Confidence {conf:.2%}, model score {prob:.2%}."
        ),
        "technical_indicators": {
            "threat_type": ttype,
            "verdict": verdict,
            "raw_observable": raw,
            "malicious_domain": domain,
            "apk_package_name": pkg,
            "apk_file_sha256": threat.get("apk_sha256"),
            "apk_cert_sha256": threat.get("apk_cert_sha256"),
            "apk_sha256": sha,
            "certificate_official_sbi": threat.get("cert_is_official"),
            "url_feature_snapshot": threat.get("url_features"),
            "behavior_analysis": threat.get("behavior_analysis"),
        },
        "geolocation_note": loc or "Not supplied by reporting client",
        "recommended_actions": [
            "Takedown coordination with hosting / app store",
            "Customer awareness broadcast",
            "IOC enrichment and sharing with sector ISAC",
        ],
        "contact": {
            "portal": "https://www.cert-in.org.in/",
            "email_hint": "Use CERT-In incident reporting form with this JSON attachment",
        },
        "generated_at": _ist_now(),
    }

    google: dict[str, Any] = {
        "submission_type": "Safe Browsing — phishing / unwanted software",
        "urls": [raw] if ttype == "url" and raw.startswith("http") else [],
        "urls_alternate": [f"http://{raw}", f"https://{raw}"]
        if ttype == "url" and raw and "://" not in raw
        else [],
        "software_identifiers": {
            "sha256": sha,
            "package_name": pkg,
        }
        if ttype == "apk"
        else {},
        "threat_category": verdict,
        "confidence": round(conf, 4),
        "context": "SBI customer protection — KAVACH automated pipeline",
        "safe_browsing_report_url": "https://safebrowsing.google.com/safebrowsing/report_phish/",
        "generated_at": _ist_now(),
    }

    cybercrime: dict[str, Any] = {
        "portal": "https://cybercrime.gov.in/",
        "complaint_category": "Online Financial Fraud / Phishing",
        "incident_summary": (
            f"Potential {verdict} targeting SBI users. "
            f"Observable: {raw[:500]}"
        ),
        "financial_institution": "State Bank of India",
        "evidence_bundle": {
            "kavach_threat_id": tid,
            "detection_time": threat.get("created_at"),
            "source_channel": threat.get("source_channel"),
            "model_verdict": verdict,
            "model_confidence": round(conf, 4),
            "apk_sha256": sha,
            "apk_package": pkg,
            "url": raw if ttype == "url" else None,
        },
        "victim_guidance": [
            "Do not share OTP/MPIN",
            "Uninstall suspicious APKs only after screenshot evidence",
            "Call official SBI helpline from printed materials",
        ],
        "generated_at": _ist_now(),
    }

    return {"certin": certin, "google": google, "cybercrime": cybercrime}
