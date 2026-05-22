
from __future__ import annotations

import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

URL_TO_TEST = "https://www.google.com/"

URL_PHISHING_THRESHOLD = 0.65

APK_FILE_PATH: str | None = None
APK_MALWARE_THRESHOLD = 0.70

def run_url() -> None:
    from url_ml_model import url_runtime

    model, names = url_runtime.load_url_artifacts()
    raw = url_runtime.raw_model_phishing_probability(URL_TO_TEST, model, names)
    p = url_runtime.phishing_probability(URL_TO_TEST, model, names)
    trusted = url_runtime.is_trusted_bank_url(URL_TO_TEST)
    verdict = "PHISHING (high risk)" if p >= URL_PHISHING_THRESHOLD else "SAFE (lower risk)"
    print("\n--- URL scan ---")
    print("URL:     ", URL_TO_TEST[:120])
    print("Trusted bank domain (allowlist):", trusted)
    print("Model-only score:", f"{raw * 100:.2f}%", "(before allowlist)")
    print("Final score:    ", f"{p * 100:.2f}%", "phishing probability")
    print("Verdict:        ", verdict, f"(threshold {URL_PHISHING_THRESHOLD:.2f})\n")

def run_apk() -> None:
    from apk_ml_model import apk_runtime

    path = APK_FILE_PATH
    if not path or not str(path).strip():
        print(
            "\n--- APK scan (skipped) ---\n"
            "Set APK_FILE_PATH in this script to the full path of a .apk file, e.g.\n"
            '  APK_FILE_PATH = "/Users/you/Downloads/sample.apk"\n'
            "Requires: pip install androguard\n"
        )
        return
    pth = Path(path).expanduser()
    if not pth.is_file():
        print(f"\n--- APK scan ---\nFile not found: {pth}\n")
        return

    model, names = apk_runtime.load_apk_artifacts()
    feats = apk_runtime.extract_apk_features(str(pth))
    p = apk_runtime.malware_probability(feats, model, names)
    impersonating = apk_runtime.is_impersonating_sbi(feats)
    if impersonating:
        p = max(p, 0.85)
    verdict = (
        "HIGH RISK / FAKE (style)"
        if p >= APK_MALWARE_THRESHOLD
        else ("REVIEW" if p >= 0.50 else "LOWER RISK")
    )
    cert = (feats.get("cert_sha256") or "")[:48]

    print("\n--- APK scan ---")
    print("File:    ", pth)
    print("Package: ", feats.get("package_name", "(unknown)"))
    print("Cert:    ", cert + ("..." if len(str(feats.get("cert_sha256"))) > 48 else ""))
    print("Score:   ", f"{p * 100:.2f}%", "malware-style probability")
    print("Impersonating SBI (rule):", impersonating)
    print("Verdict: ", verdict, f"(threshold {APK_MALWARE_THRESHOLD:.2f})\n")

def main() -> None:
    print("Backend:", BACKEND)
    run_url()
    run_apk()

if __name__ == "__main__":
    main()
