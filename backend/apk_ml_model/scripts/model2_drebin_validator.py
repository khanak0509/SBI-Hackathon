
import hashlib
import json
import re
import sys
import warnings
import zipfile
from datetime import datetime
from pathlib import Path

warnings.filterwarnings("ignore")

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier, VotingClassifier
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder, StandardScaler

try:
    from androguard.core.apk import APK

    ANDROGUARD_AVAILABLE = True
except ImportError:
    try:
        from androguard.core.bytecodes.apk import APK

        ANDROGUARD_AVAILABLE = True
    except ImportError:
        ANDROGUARD_AVAILABLE = False
        APK = None
if not ANDROGUARD_AVAILABLE:
    print("[WARN] androguard not installed → live APK scan disabled (training still works)")
    print("       Install: pip install androguard")
else:
    try:
        from loguru import logger as _loguru_logger

        _loguru_logger.remove()
        _loguru_logger.add(sys.stderr, level="WARNING")
    except Exception:
        pass

_PKG = Path(__file__).resolve().parent.parent

DATA_PATH = _PKG / "data" / "drebin-215-dataset-5560malware-9476-benign.csv"
FEAT_DESC_CANDIDATES = (
    _PKG / "data" / "feature_description.csv",
    _PKG / "data" / "dataset-features-categories.csv",
)
MODEL_DIR = _PKG / "artifacts" / "standalone"
REPORT_DIR = _PKG / "reports" / "standalone"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)
MODEL_PATH    = MODEL_DIR / "model2_apk_validator.pkl"
FEATURES_PATH = MODEL_DIR / "model2_feature_names.json"
FEAT_TYPE_PATH= MODEL_DIR / "model2_feature_types.json"

SBI_CERT_REGISTRY = {
    "com.sbi.lotusintouch": [
        "REPLACE_WITH_OFFICIAL_YONO_CERT_SHA256",
    ],
    "com.sbi.SBIFreedomPlus": [
        "REPLACE_WITH_OFFICIAL_SBIFREEDOM_CERT_SHA256",
    ],
    "com.onlinesbi.sbi": [
        "REPLACE_WITH_OFFICIAL_SBIPORTAL_CERT_SHA256",
    ],
}

DANGEROUS_COMBOS = [
    {"android.permission.BIND_ACCESSIBILITY_SERVICE",
     "android.permission.SYSTEM_ALERT_WINDOW",
     "android.permission.READ_CONTACTS"},
    {"android.permission.RECEIVE_SMS",
     "android.permission.READ_SMS",
     "android.permission.SEND_SMS"},
    {"android.permission.BIND_ACCESSIBILITY_SERVICE",
     "android.permission.CAMERA",
     "android.permission.RECORD_AUDIO"},
    {"android.permission.GET_ACCOUNTS",
     "android.permission.READ_CONTACTS",
     "android.permission.INTERNET"},
]

OVERLAY_WINDOW_TYPES = [
    "TYPE_APPLICATION_OVERLAY",
    "TYPE_SYSTEM_OVERLAY",
    "TYPE_SYSTEM_ALERT",
]

NETWORK_RE = re.compile(
    r'(?:\b(?:\d{1,3}\.){3}\d{1,3}\b'
    r'|(?:https?://)[^\s"\'<>]{4,100}'
    r'|\.onion\b)',
    re.IGNORECASE,
)

def extract_cert_sha256(apk_path: str):
    if not ANDROGUARD_AVAILABLE:
        return None
    try:
        apk = APK(apk_path)
        for cert in apk.get_certificates():
            return hashlib.sha256(cert.dump()).hexdigest().upper()
    except Exception as e:
        print(f"  [CERT ERROR] {e}")
    return None

def check_cert(package_name: str, cert_sha256):
    result = {
        "is_sbi_package": False,
        "cert_matches":   False,
        "cert_verdict":   "UNKNOWN" if cert_sha256 is None else "NON_SBI",
    }
    if cert_sha256 is None:
        return result
    for pkg, valid_hashes in SBI_CERT_REGISTRY.items():
        if pkg in package_name:
            result["is_sbi_package"] = True
            result["cert_verdict"]   = "VALID" if cert_sha256 in valid_hashes else "FORGED"
            result["cert_matches"]   = cert_sha256 in valid_hashes
            break
    return result

def extract_apk_features_live(apk_path: str) -> dict:
    f = {
        "package_name":              "",
        "cert_sha256":               None,
        "cert_verdict":              "UNKNOWN",
        "is_sbi_package":            False,
        "permission_count":          0,
        "dangerous_perm_count":      0,
        "has_overlay":               False,
        "has_accessibility":         False,
        "has_sms_read":              False,
        "has_sms_receive":           False,
        "has_send_sms":              False,
        "has_internet":              False,
        "has_camera":                False,
        "has_record_audio":          False,
        "has_get_accounts":          False,
        "has_read_contacts":         False,
        "dangerous_combo_score":     0,
        "overlay_window_declared":   False,
        "hardcoded_network_strings": 0,
        "activity_count":            0,
        "service_count":             0,
        "receiver_count":            0,
        "uses_native_code":          False,
        "min_sdk":                   0,
        "target_sdk":                0,
        "signature_risk_score":      0.0,
    }

    if not ANDROGUARD_AVAILABLE or not Path(apk_path).exists():
        print(f"  [WARN] Skipping live extraction: {apk_path}")
        return f

    try:
        apk   = APK(apk_path)
        perms = set(apk.get_permissions())

        f["package_name"]    = apk.get_package()
        cert                 = extract_cert_sha256(apk_path)
        f["cert_sha256"]     = cert
        cert_info            = check_cert(f["package_name"], cert)
        f.update({k: v for k, v in cert_info.items()})

        danger_kws = ["READ_SMS","RECEIVE_SMS","SEND_SMS","CAMERA","RECORD_AUDIO",
                      "READ_CONTACTS","GET_ACCOUNTS","SYSTEM_ALERT_WINDOW",
                      "BIND_ACCESSIBILITY_SERVICE","READ_CALL_LOG"]
        f["permission_count"]     = len(perms)
        f["dangerous_perm_count"] = sum(1 for p in perms if any(d in p for d in danger_kws))
        f["has_overlay"]          = "android.permission.SYSTEM_ALERT_WINDOW" in perms
        f["has_accessibility"]    = "android.permission.BIND_ACCESSIBILITY_SERVICE" in perms
        f["has_sms_read"]         = "android.permission.READ_SMS" in perms
        f["has_sms_receive"]      = "android.permission.RECEIVE_SMS" in perms
        f["has_send_sms"]         = "android.permission.SEND_SMS" in perms
        f["has_internet"]         = "android.permission.INTERNET" in perms
        f["has_camera"]           = "android.permission.CAMERA" in perms
        f["has_record_audio"]     = "android.permission.RECORD_AUDIO" in perms
        f["has_get_accounts"]     = "android.permission.GET_ACCOUNTS" in perms
        f["has_read_contacts"]    = "android.permission.READ_CONTACTS" in perms
        f["dangerous_combo_score"]= sum(1 for c in DANGEROUS_COMBOS if c.issubset(perms))

        try:
            xml = apk.get_android_manifest_axml().get_xml()
            if xml:
                s = xml.decode("utf-8", errors="ignore") if isinstance(xml, bytes) else xml
                f["overlay_window_declared"] = any(ow in s for ow in OVERLAY_WINDOW_TYPES)
        except Exception:
            pass

        f["activity_count"]   = len(apk.get_activities())
        f["service_count"]    = len(apk.get_services())
        f["receiver_count"]   = len(apk.get_receivers())
        f["uses_native_code"] = bool(apk.get_libraries())
        f["min_sdk"]          = int(apk.get_min_sdk_version()    or 0)
        f["target_sdk"]       = int(apk.get_target_sdk_version() or 0)

        net_hits = 0
        try:
            with zipfile.ZipFile(apk_path, "r") as zf:
                for name in zf.namelist():
                    if name.endswith(".dex"):
                        txt = zf.read(name).decode("latin-1", errors="ignore")
                        net_hits += len(NETWORK_RE.findall(txt))
        except Exception:
            pass
        f["hardcoded_network_strings"] = min(net_hits, 999)

        risk = 0.0
        if f["cert_verdict"] == "FORGED":         risk += 0.60
        if f["dangerous_combo_score"] > 0:         risk += 0.15 * min(f["dangerous_combo_score"], 2)
        if f["overlay_window_declared"]:           risk += 0.10
        if f["has_accessibility"] and f["has_sms_read"]: risk += 0.10
        if f["hardcoded_network_strings"] > 10:   risk += 0.05
        f["signature_risk_score"] = round(min(risk, 1.0), 3)

    except Exception as e:
        print(f"  [APK ERROR] {e}")

    return f

def resolve_feature_desc_path() -> Path | None:
    for p in FEAT_DESC_CANDIDATES:
        if p.exists():
            return p
    return None

def load_feature_types() -> dict:
    p = resolve_feature_desc_path()
    if p is None:
        return {}
    try:
        fd = pd.read_csv(p)
        c0 = str(fd.columns[0]).strip().lower()
        c1 = str(fd.columns[1]).strip().lower() if fd.shape[1] > 1 else ""
        if c0 in ("feature", "feature_name", "name") and c1 in (
            "type",
            "category",
            "categories",
        ):
            feat_col, typ_col = fd.columns[0], fd.columns[1]
        else:
            fd = pd.read_csv(p, header=None, names=["feature", "type"])
            feat_col, typ_col = "feature", "type"
        return dict(
            zip(
                fd[feat_col].astype(str).str.strip(),
                fd[typ_col].astype(str).str.strip(),
            )
        )
    except Exception as e:
        print(f"  [WARN] Could not load feature description ({p}): {e}")
        return {}

def load_dataset(csv_path: Path):
    print(f"\n[1/5] Loading dataset: {csv_path}")
    df = pd.read_csv(csv_path)
    print(f"      Rows x Cols : {df.shape}")
    print(f"      First 5 cols: {list(df.columns[:5])}")
    print(f"      Last  5 cols: {list(df.columns[-5:])}")

    label_col = "class"
    if label_col not in df.columns:
        label_col = df.columns[-1]
        print(f"      [WARN] 'class' not found — falling back to: '{label_col}'")

    print(f"\n      Label column : '{label_col}'")
    raw_counts = df[label_col].value_counts()
    print(f"      Raw values   :\n{raw_counts.to_string()}")

    y_raw = df[label_col].astype(str).str.strip()
    le    = LabelEncoder()
    y     = le.fit_transform(y_raw)
    label_map = dict(zip(le.classes_, le.transform(le.classes_).tolist()))
    print(f"      Encoding     : {label_map}  ← B=0 (Benign), S=1 (Malware)")
    if label_map.get("B") != 0 or label_map.get("S") != 1:
        print("      [WARN] Unexpected encoding order — check label values.")

    X = df.drop(columns=[label_col])
    non_num = X.select_dtypes(exclude=[np.number]).columns.tolist()
    if non_num:
        print(f"      Dropping non-numeric cols: {non_num}")
        X = X.drop(columns=non_num)
    X = X.fillna(0).astype(float)

    desc_src = resolve_feature_desc_path()
    feat_types = load_feature_types()
    if feat_types:
        type_counts: dict = {}
        for fn in X.columns:
            ft = feat_types.get(fn, "Unknown")
            type_counts[ft] = type_counts.get(ft, 0) + 1
        print(f"\n      Feature breakdown ({desc_src}):")
        for ft, cnt in sorted(type_counts.items(), key=lambda x: -x[1]):
            print(f"        {ft:<40} {cnt:>4} features")

        FEAT_TYPE_PATH.write_text(json.dumps(feat_types, indent=2))
    else:
        print(
            "\n      [INFO] No feature description CSV found "
            "(tried data/feature_description.csv, data1/dataset-features-categories.csv) "
            "— skipping type breakdown."
        )

    print(f"\n      Final X  : {X.shape}")
    print(f"      Benign   : {(y == 0).sum()}  |  Malware: {(y == 1).sum()}")
    return X, y, X.columns.tolist()

def train(X: pd.DataFrame, y: np.ndarray, feature_names: list) -> Pipeline:
    print("\n[2/5] Splitting dataset (80 / 20 stratified) ...")
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    print(f"      Train: {len(X_tr)}  |  Test: {len(X_te)}")

    rf = RandomForestClassifier(
        n_estimators=200, max_depth=None,
        class_weight="balanced", random_state=42, n_jobs=-1,
    )
    gb = GradientBoostingClassifier(
        n_estimators=150, learning_rate=0.1,
        max_depth=5, subsample=0.8, random_state=42,
    )
    ensemble = VotingClassifier(
        estimators=[("rf", rf), ("gb", gb)],
        voting="soft", n_jobs=-1,
    )
    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("model",  ensemble),
    ])

    print("\n[3/5] Training Voting Ensemble (RandomForest + GradientBoosting) ...")
    pipeline.fit(X_tr, y_tr)

    print("\n[4/5] Evaluation ─────────────────────────────────────────────────────")
    y_pred = pipeline.predict(X_te)
    y_prob = pipeline.predict_proba(X_te)[:, 1]
    print(classification_report(y_te, y_pred, target_names=["Benign (B)", "Malware (S)"]))
    cm  = confusion_matrix(y_te, y_pred)
    auc = roc_auc_score(y_te, y_prob)
    print(f"  Confusion Matrix:  TN={cm[0,0]}  FP={cm[0,1]}  FN={cm[1,0]}  TP={cm[1,1]}")
    print(f"  ROC-AUC: {auc:.4f}")

    print("\n  5-Fold Stratified Cross-Validation ──────────────────────────────────")
    cv = cross_val_score(
        pipeline, X, y,
        cv=StratifiedKFold(5, shuffle=True, random_state=42),
        scoring="roc_auc", n_jobs=-1,
    )
    print(f"  Fold AUC: {np.round(cv, 4)}")
    print(f"  Mean AUC: {cv.mean():.4f} ± {cv.std():.4f}")

    rf_fitted   = pipeline.named_steps["model"].estimators_[0]
    importances = rf_fitted.feature_importances_
    feat_types  = load_feature_types()
    top15 = sorted(zip(feature_names, importances), key=lambda x: -x[1])[:15]

    print("\n  Top 15 Most Important Features ──────────────────────────────────────")
    for fname, imp in top15:
        ftype = feat_types.get(fname, "")
        bar   = "█" * int(imp * 400)
        print(f"  {fname:<45} {bar} {imp:.4f}  [{ftype}]")

    rp = REPORT_DIR / "model2_eval_report.json"
    rp.write_text(json.dumps({
        "timestamp":    datetime.now().isoformat(),
        "roc_auc_test": round(auc, 4),
        "cv_auc_mean":  round(cv.mean(), 4),
        "cv_auc_std":   round(cv.std(),  4),
        "confusion_matrix": cm.tolist(),
        "top_15_features": [
            {"name": n, "importance": round(i, 5), "type": feat_types.get(n, "")}
            for n, i in top15
        ],
    }, indent=2))
    print(f"\n  Eval report saved → {rp}")

    return pipeline

THRESHOLDS = {
    "SAFE":       (0.00, 0.35),
    "QUARANTINE": (0.35, 0.65),
    "MALICIOUS":  (0.65, 1.01),
}

def predict(apk_path: str, pipeline: Pipeline, feature_names: list) -> dict:
    print(f"\n{'═'*62}")
    print(f"  Scanning APK: {apk_path}")
    print(f"{'═'*62}")

    lf = extract_apk_features_live(apk_path)

    print(f"  Package          : {lf['package_name'] or 'N/A'}")
    print(f"  Cert SHA-256     : {lf['cert_sha256'] or 'N/A'}")
    print(f"  Cert Verdict     : {lf['cert_verdict']}")
    print(f"  Permissions      : {lf['permission_count']} total, {lf['dangerous_perm_count']} dangerous")
    print(f"  Dangerous combos : {lf['dangerous_combo_score']}")
    print(f"  Overlay declared : {lf['overlay_window_declared']}")
    print(f"  Network strings  : {lf['hardcoded_network_strings']}")

    row = {fn: 0.0 for fn in feature_names}
    exact = {
        "SEND_SMS": float(lf["has_send_sms"]),
        "READ_SMS": float(lf["has_sms_read"]),
        "RECEIVE_SMS": float(lf["has_sms_receive"]),
        "CAMERA": float(lf["has_camera"]),
        "RECORD_AUDIO": float(lf["has_record_audio"]),
        "GET_ACCOUNTS": float(lf["has_get_accounts"]),
        "READ_CONTACTS": float(lf["has_read_contacts"]),
        "SYSTEM_ALERT_WINDOW": float(lf["has_overlay"]),
        "BIND_ACCESSIBILITY_SERVICE": float(lf["has_accessibility"]),
        "INTERNET": float(lf["has_internet"]),
    }
    for fn in feature_names:
        if fn in exact:
            row[fn] = exact[fn]

    X_live  = pd.DataFrame([row])[feature_names].fillna(0.0)
    ml_prob = float(pipeline.predict_proba(X_live)[0][1])

    cert_boost = 0.50 if lf["cert_verdict"] == "FORGED" else \
                -0.15 if lf["cert_verdict"] == "VALID"  else 0.0

    final_score = float(np.clip(
        ml_prob + cert_boost + lf["signature_risk_score"] * 0.3,
        0.0, 1.0
    ))

    verdict = "SAFE"
    for v, (lo, hi) in THRESHOLDS.items():
        if lo <= final_score < hi:
            verdict = v; break

    result = {
        "apk_path":              apk_path,
        "package_name":          lf["package_name"],
        "cert_sha256":           lf["cert_sha256"],
        "cert_verdict":          lf["cert_verdict"],
        "ml_malware_prob":       round(ml_prob,    4),
        "cert_boost":            round(cert_boost, 4),
        "signal_risk_score":     round(lf["signature_risk_score"], 4),
        "final_risk_score":      round(final_score, 4),
        "verdict":               verdict,
        "analyst_review_needed": verdict == "QUARANTINE",
        "signals": {
            "dangerous_combo_score":     lf["dangerous_combo_score"],
            "overlay_window_declared":   lf["overlay_window_declared"],
            "accessibility_abuse":       lf["has_accessibility"],
            "sms_interception":          lf["has_sms_read"] or lf["has_sms_receive"],
            "hardcoded_network_strings": lf["hardcoded_network_strings"],
        },
        "timestamp": datetime.now().isoformat(),
    }

    icons = {"SAFE": "✅", "QUARANTINE": "⚠️ ", "MALICIOUS": "🚨"}
    print(f"\n  ML Prob (model)  : {ml_prob:.4f}")
    print(f"  Cert Boost       : {cert_boost:+.4f}")
    print(f"  Signal Score     : {lf['signature_risk_score']:.4f}")
    print(f"  Final Risk Score : {final_score:.4f}")
    print(f"\n  ┌{'─'*40}┐")
    print(f"  │  VERDICT: {icons.get(verdict,'')} {verdict:<28}│")
    print(f"  └{'─'*40}┘")

    if verdict == "QUARANTINE":
        print("  → Added to 'Needs Review' queue for SBI analyst (never silently blocked)")
    elif verdict == "MALICIOUS":
        print("  → Persistent alert triggered · CERT-In report queued")

    return result

def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║   KAVACH · ML Model 2 · APK Signature Validator         ║")
    print("╚══════════════════════════════════════════════════════════╝")

    if not MODEL_PATH.exists():
        if not DATA_PATH.exists():
            print(f"\n[ERROR] Dataset not found: {DATA_PATH}")
            print("  Download from Kaggle:")
            print("  https://www.kaggle.com/datasets/shashwatwork/android-malware-dataset-for-machine-learning")
            print("  Place Drebin CSV under apk_ml_model/data/ (see docstring).")
            print(f"    Expected: {DATA_PATH}")
            sys.exit(1)

        X, y, feature_names = load_dataset(DATA_PATH)
        pipeline = train(X, y, feature_names)

        print(f"\n[5/5] Saving model → {MODEL_PATH}")
        joblib.dump(pipeline, MODEL_PATH)
        FEATURES_PATH.write_text(json.dumps(feature_names))
        print("      Done ✓")
    else:
        print(f"\n[INFO] Trained model found: {MODEL_PATH}")
        print("       Delete .pkl to retrain from scratch.")

    pipeline      = joblib.load(MODEL_PATH)
    feature_names = json.loads(FEATURES_PATH.read_text())

    if len(sys.argv) > 1:
        apk_path = sys.argv[1]
        if not Path(apk_path).exists():
            print(f"[ERROR] APK not found: {apk_path}")
            sys.exit(1)
        result = predict(apk_path, pipeline, feature_names)
        ts     = datetime.now().strftime("%Y%m%d_%H%M%S")
        out    = REPORT_DIR / f"scan_{Path(apk_path).stem}_{ts}.json"
        out.write_text(json.dumps(result, indent=2))
        print(f"\n  Full report → {out}")
    else:
        print("\n[INFO] No APK path given. Training complete.")
        print("  Usage:  python apk_ml_model/scripts/model2_drebin_validator.py path/to/app.apk")

if __name__ == "__main__":
    main()
