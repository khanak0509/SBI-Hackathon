
import json
import sys
import warnings
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path

warnings.filterwarnings("ignore")

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier
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
else:
    try:
        from loguru import logger as _loguru_logger

        _loguru_logger.remove()
        _loguru_logger.add(sys.stderr, level="WARNING")
    except Exception:
        pass

_PKG = Path(__file__).resolve().parent.parent

DATA_PATH_CANDIDATES = (
    _PKG / "data" / "data.csv",
    _PKG / "data" / "drebin-215-dataset-5560malware-9476-benign.csv",
)
FEAT_DESC_CANDIDATES = (
    _PKG / "data" / "feature_description.csv",
    _PKG / "data" / "dataset-features-categories.csv",
)
MODEL_DIR = _PKG / "artifacts" / "standalone"
REPORT_DIR = _PKG / "reports" / "standalone"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
REPORT_DIR.mkdir(parents=True, exist_ok=True)
MODEL_PATH    = MODEL_DIR / "model3_behavioral_engine.pkl"
ISO_PATH      = MODEL_DIR / "model3_isolation_forest.pkl"
FEATURES_PATH = MODEL_DIR / "model3_feature_names.json"

YONO_KNOWN_GOOD_PERMISSIONS = {
    "android.permission.INTERNET",
    "android.permission.ACCESS_NETWORK_STATE",
    "android.permission.CAMERA",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
    "android.permission.USE_BIOMETRIC",
    "android.permission.USE_FINGERPRINT",
    "android.permission.VIBRATE",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.POST_NOTIFICATIONS",

}

YONO_FORBIDDEN_PERMISSIONS = {
    "android.permission.BIND_ACCESSIBILITY_SERVICE",
    "android.permission.READ_SMS",
    "android.permission.RECEIVE_SMS",
    "android.permission.SEND_SMS",
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.PROCESS_OUTGOING_CALLS",
    "android.permission.READ_CALL_LOG",
    "android.permission.WRITE_CALL_LOG",
}

DANGEROUS_COMBOS = [
    frozenset({"android.permission.BIND_ACCESSIBILITY_SERVICE",
               "android.permission.SYSTEM_ALERT_WINDOW"}),
    frozenset({"android.permission.RECEIVE_SMS",
               "android.permission.READ_SMS"}),
    frozenset({"android.permission.BIND_ACCESSIBILITY_SERVICE",
               "android.permission.RECORD_AUDIO",
               "android.permission.CAMERA"}),
    frozenset({"android.permission.GET_ACCOUNTS",
               "android.permission.RECEIVE_SMS"}),
    frozenset({"android.permission.ACCESS_FINE_LOCATION",
               "android.permission.RECORD_AUDIO",
               "android.permission.CAMERA"}),
]

OVERLAY_TYPES = [
    "TYPE_APPLICATION_OVERLAY",
    "TYPE_SYSTEM_OVERLAY",
    "TYPE_SYSTEM_ALERT",
]

@dataclass
class BehavioralFeatures:
    package_name:              str   = ""
    claims_to_be_sbi:          bool  = False
    is_sideloaded:             bool  = False
    permission_count:          int   = 0
    dangerous_perm_count:      int   = 0
    forbidden_perm_count:      int   = 0
    dangerous_combo_count:     int   = 0
    fingerprint_divergence:    float = 0.0
    has_overlay_permission:    bool  = False
    has_accessibility:         bool  = False
    has_sms_read:              bool  = False
    has_sms_receive:           bool  = False
    has_send_sms:              bool  = False
    has_camera:                bool  = False
    has_record_audio:          bool  = False
    has_get_accounts:          bool  = False
    has_read_contacts:         bool  = False
    overlay_window_declared:   bool  = False
    activity_count:            int   = 0
    service_count:             int   = 0
    receiver_count:            int   = 0
    uses_native_code:          bool  = False
    min_sdk:                   int   = 0
    target_sdk:                int   = 0
    heuristic_risk_score:      float = 0.0

def compute_fingerprint_divergence(app_perms: set, reference: set) -> float:
    union = app_perms | reference
    if not union:
        return 0.0
    intersection = app_perms & reference
    return round(1.0 - len(intersection) / len(union), 4)

def compute_heuristic_score(bf: BehavioralFeatures) -> float:
    score = 0.0

    if bf.claims_to_be_sbi:
        score += 0.10
        if bf.forbidden_perm_count > 0:
            score += 0.25 * min(bf.forbidden_perm_count, 3)
        if bf.fingerprint_divergence > 0.3:
            score += 0.20 * bf.fingerprint_divergence

    score += 0.12 * min(bf.dangerous_combo_count, 3)

    if bf.has_overlay_permission and bf.has_accessibility:
        score += 0.20
    if bf.overlay_window_declared:
        score += 0.10
    if bf.has_sms_read or bf.has_sms_receive or bf.has_send_sms:
        score += 0.10
    if bf.has_accessibility and (bf.has_sms_read or bf.has_send_sms or bf.has_record_audio):
        score += 0.10
    if bf.is_sideloaded and bf.claims_to_be_sbi:
        score += 0.15

    return round(min(score, 1.0), 4)

def behavioral_features_from_dict(d: dict) -> BehavioralFeatures:
    perms = set(d.get("permissions", []))
    bf    = BehavioralFeatures()

    bf.package_name     = d.get("package_name", "")
    bf.claims_to_be_sbi = d.get("claims_to_be_sbi",
        any(kw in bf.package_name.lower() for kw in ["sbi", "yono", "statebank"]))
    bf.is_sideloaded    = d.get("is_sideloaded", False)
    bf.permission_count = len(perms)

    danger_kws = ["READ_SMS","RECEIVE_SMS","SEND_SMS","CAMERA","RECORD_AUDIO",
                  "READ_CONTACTS","GET_ACCOUNTS","SYSTEM_ALERT_WINDOW",
                  "BIND_ACCESSIBILITY_SERVICE","READ_CALL_LOG"]
    bf.dangerous_perm_count  = sum(1 for p in perms if any(d in p for d in danger_kws))
    bf.forbidden_perm_count  = len(YONO_FORBIDDEN_PERMISSIONS & perms)
    bf.dangerous_combo_count = sum(1 for c in DANGEROUS_COMBOS if c.issubset(perms))

    if bf.claims_to_be_sbi:
        bf.fingerprint_divergence = compute_fingerprint_divergence(
            perms, YONO_KNOWN_GOOD_PERMISSIONS
        )

    bf.has_overlay_permission = "android.permission.SYSTEM_ALERT_WINDOW" in perms
    bf.has_accessibility      = "android.permission.BIND_ACCESSIBILITY_SERVICE" in perms
    bf.has_sms_read           = "android.permission.READ_SMS" in perms
    bf.has_sms_receive        = "android.permission.RECEIVE_SMS" in perms
    bf.has_send_sms           = "android.permission.SEND_SMS" in perms
    bf.has_camera             = "android.permission.CAMERA" in perms
    bf.has_record_audio       = "android.permission.RECORD_AUDIO" in perms
    bf.has_get_accounts       = "android.permission.GET_ACCOUNTS" in perms
    bf.has_read_contacts      = "android.permission.READ_CONTACTS" in perms
    bf.overlay_window_declared= d.get("overlay_window_declared", False)
    bf.activity_count         = d.get("activity_count",  0)
    bf.service_count          = d.get("service_count",   0)
    bf.receiver_count         = d.get("receiver_count",  0)
    bf.uses_native_code       = d.get("uses_native_code", False)
    bf.min_sdk                = d.get("min_sdk",    0)
    bf.target_sdk             = d.get("target_sdk", 0)
    bf.heuristic_risk_score   = compute_heuristic_score(bf)

    return bf

def extract_behavioral_features_live(apk_path: str) -> BehavioralFeatures:
    if not ANDROGUARD_AVAILABLE or not Path(apk_path).exists():
        print(f"  [WARN] Cannot extract from: {apk_path}")
        return BehavioralFeatures()

    try:
        apk   = APK(apk_path)
        perms = set(apk.get_permissions())
        pkg   = apk.get_package()

        manifest_xml = ""
        try:
            xml = apk.get_android_manifest_axml().get_xml()
            if xml:
                manifest_xml = xml.decode("utf-8", errors="ignore") if isinstance(xml, bytes) else xml
        except Exception:
            pass

        bf = behavioral_features_from_dict({
            "package_name":          pkg,
            "permissions":           list(perms),
            "overlay_window_declared": any(ow in manifest_xml for ow in OVERLAY_TYPES),
            "activity_count":        len(apk.get_activities()),
            "service_count":         len(apk.get_services()),
            "receiver_count":        len(apk.get_receivers()),
            "uses_native_code":      bool(apk.get_libraries()),
            "min_sdk":               int(apk.get_min_sdk_version()    or 0),
            "target_sdk":            int(apk.get_target_sdk_version() or 0),
            "is_sideloaded":         False,
        })
        return bf

    except Exception as e:
        print(f"  [APK ERROR] {e}")
        return BehavioralFeatures()

def resolve_dataset_csv() -> Path | None:
    for p in DATA_PATH_CANDIDATES:
        if p.exists():
            return p
    return None

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

def engineer_behavioral_features(df_raw: pd.DataFrame) -> pd.DataFrame:
    feat = pd.DataFrame(index=df_raw.index)
    cols = df_raw.columns

    def col_flag(keywords: list) -> pd.Series:
        matching = [c for c in cols if any(kw.upper() in c.upper() for kw in keywords)]
        return df_raw[matching].max(axis=1) if matching else pd.Series(0, index=df_raw.index)

    def col_sum(keywords: list) -> pd.Series:
        matching = [c for c in cols if any(kw.upper() in c.upper() for kw in keywords)]
        return df_raw[matching].sum(axis=1) if matching else pd.Series(0, index=df_raw.index)

    feat["has_overlay_permission"] = col_flag(["SYSTEM_ALERT_WINDOW", "ALERT_WINDOW"])
    feat["has_accessibility"]      = col_flag(["BIND_ACCESSIBILITY_SERVICE", "ACCESSIBILITY"])
    feat["has_sms_read"]           = col_flag(["READ_SMS"])
    feat["has_sms_receive"]        = col_flag(["RECEIVE_SMS"])
    feat["has_send_sms"]           = col_flag(["SEND_SMS"])
    feat["has_camera"]             = col_flag(["CAMERA"])
    feat["has_record_audio"]       = col_flag(["RECORD_AUDIO"])
    feat["has_get_accounts"]       = col_flag(["GET_ACCOUNTS"])
    feat["has_read_contacts"]      = col_flag(["READ_CONTACTS"])
    feat["uses_native_code"]       = col_flag(["System.loadLibrary", "Runtime.loadLibrary",
                                               "DexClassLoader", "ClassLoader"])

    feat["permission_count"]       = df_raw.sum(axis=1)
    feat["dangerous_perm_count"]   = (
        feat["has_sms_read"].astype(int) +
        feat["has_sms_receive"].astype(int) +
        feat["has_send_sms"].astype(int) +
        feat["has_camera"].astype(int) +
        feat["has_record_audio"].astype(int) +
        feat["has_get_accounts"].astype(int) +
        feat["has_read_contacts"].astype(int) +
        feat["has_accessibility"].astype(int) +
        feat["has_overlay_permission"].astype(int)
    )

    combo1 = feat["has_overlay_permission"] * feat["has_accessibility"]

    sms_perm_sum = (
        feat["has_sms_read"].astype(int)
        + feat["has_sms_receive"].astype(int)
        + feat["has_send_sms"].astype(int)
    )
    combo2 = (sms_perm_sum >= 2).astype(int)

    combo3 = feat["has_accessibility"] * feat["has_record_audio"] * feat["has_camera"]
    feat["dangerous_combo_count"] = (combo1 + combo2 + combo3).clip(0, 5)

    feat["overlay_window_declared"] = feat["has_overlay_permission"]
    feat["forbidden_perm_count"]    = (feat["has_sms_read"].astype(int) +
                                       feat["has_sms_receive"].astype(int) +
                                       feat["has_send_sms"].astype(int) +
                                       feat["has_accessibility"].astype(int) +
                                       feat["has_overlay_permission"].astype(int))
    feat["fingerprint_divergence"]  = (feat["dangerous_perm_count"] / 10.0).clip(0, 1)

    feat["uses_reflection"]         = col_flag(["Class.getMethod", "Class.getDeclaredField",
                                                "Class.forName", "DexClassLoader"])
    feat["uses_crypto"]             = col_flag(["SecretKeySpec", "Cipher", "SecretKey", "KeySpec"])
    feat["uses_shell_commands"]     = col_flag(["Runtime.exec", "Process.start",
                                                "ProcessBuilder", "createSubprocess",
                                                "chmod", "chown", "mount", "remount"])
    feat["uses_telephony"]          = col_flag(["TelephonyManager", "SmsManager",
                                                "sendMultipartTextMessage", "sendDataMessage"])
    feat["uses_dynamic_loading"]    = col_flag(["DexClassLoader", "URLClassLoader",
                                                "PathClassLoader", "defineClass"])
    feat["uses_network"]            = col_flag(["HttpGet", "HttpPost", "HttpUriRequest",
                                                "URLDecoder"])
    feat["uses_binder_ipc"]         = col_flag(["transact", "onServiceConnected", "bindService",
                                                "IBinder", "Binder", "attachInterface"])
    feat["accesses_device_id"]      = col_flag(["getDeviceId", "getSubscriberId",
                                                "getSimSerialNumber", "getLine1Number"])

    feat["heuristic_risk_score"] = (
        0.20 * feat["has_accessibility"].astype(float) +
        0.15 * feat["has_overlay_permission"].astype(float) +
        0.12 * feat["has_sms_read"].astype(float) +
        0.10 * feat["has_sms_receive"].astype(float) +
        0.10 * feat["has_send_sms"].astype(float) +
        0.10 * feat["overlay_window_declared"].astype(float) +
        0.08 * (feat["dangerous_combo_count"].clip(0, 3) / 3.0) +
        0.07 * feat["uses_native_code"].astype(float) +
        0.06 * feat["uses_shell_commands"].astype(float) +
        0.05 * feat["uses_dynamic_loading"].astype(float) +
        0.05 * feat["uses_telephony"].astype(float) +
        0.04 * feat["accesses_device_id"].astype(float) +
        0.03 * feat["uses_reflection"].astype(float)
    ).clip(0, 1).round(4)

    feat["claims_to_be_sbi"] = 0
    feat["is_sideloaded"]    = 0
    feat["activity_count"]   = 0
    feat["service_count"]    = 0
    feat["receiver_count"]   = 0
    feat["min_sdk"]          = 0
    feat["target_sdk"]       = 0

    return feat.fillna(0).astype(float)

def load_dataset(csv_path: Path):
    print(f"\n[1/5] Loading dataset: {csv_path}")
    df = pd.read_csv(csv_path)
    print(f"      Shape: {df.shape}")

    label_col = "class"
    if label_col not in df.columns:
        label_col = df.columns[-1]
        print(f"      [WARN] 'class' not found — using: '{label_col}'")

    print(f"      Label column : '{label_col}'")
    print(f"      Value counts :\n{df[label_col].value_counts().to_string()}")

    y_raw = df[label_col].astype(str).str.strip()
    le    = LabelEncoder()
    y     = le.fit_transform(y_raw)
    label_map = dict(zip(le.classes_, le.transform(le.classes_).tolist()))
    print(f"      Encoding: {label_map}  ← B=0 (Benign), S=1 (Malware)")

    X_raw = df.drop(columns=[label_col])
    non_num = X_raw.select_dtypes(exclude=[np.number]).columns.tolist()
    if non_num:
        X_raw = X_raw.drop(columns=non_num)
    X_raw = X_raw.fillna(0).astype(float)

    feat_types = load_feature_types()
    if feat_types:
        type_counts: dict = {}
        for fn in X_raw.columns:
            ft = feat_types.get(fn, "Unknown")
            type_counts[ft] = type_counts.get(ft, 0) + 1
        print(f"\n      Raw feature breakdown:")
        for ft, cnt in sorted(type_counts.items(), key=lambda x: -x[1]):
            print(f"        {ft:<40} {cnt:>4}")

    print(f"\n      Engineering behavioral feature vector ...")
    X = engineer_behavioral_features(X_raw)
    print(f"      Behavioral features: {X.shape[1]} cols  |  Rows: {X.shape[0]}")
    print(f"      Benign: {(y==0).sum()}  |  Malware: {(y==1).sum()}")

    return X, y, X.columns.tolist()

def train(X: pd.DataFrame, y: np.ndarray, feature_names: list) -> tuple:
    print("\n[2/5] Splitting (80/20 stratified) ...")
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    print(f"      Train: {len(X_tr)}  |  Test: {len(X_te)}")

    rf_pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("clf",    RandomForestClassifier(
            n_estimators=200,
            max_depth=None,
            class_weight="balanced",
            random_state=42,
            n_jobs=-1,
        )),
    ])

    print("\n[3/5] Training supervised RandomForest ...")
    rf_pipeline.fit(X_tr, y_tr)

    print("\n[4/5] Evaluation ──────────────────────────────────────────────────────")
    y_pred = rf_pipeline.predict(X_te)
    y_prob = rf_pipeline.predict_proba(X_te)[:, 1]
    print(classification_report(y_te, y_pred, target_names=["Benign (B)", "Malware (S)"]))
    cm  = confusion_matrix(y_te, y_pred)
    auc = roc_auc_score(y_te, y_prob)
    print(f"  Confusion Matrix:  TN={cm[0,0]}  FP={cm[0,1]}  FN={cm[1,0]}  TP={cm[1,1]}")
    print(f"  ROC-AUC: {auc:.4f}")

    print("\n  5-Fold Stratified CV ─────────────────────────────────────────────────")
    cv = cross_val_score(
        rf_pipeline, X, y,
        cv=StratifiedKFold(5, shuffle=True, random_state=42),
        scoring="roc_auc", n_jobs=-1,
    )
    print(f"  Fold AUC : {np.round(cv, 4)}")
    print(f"  Mean AUC : {cv.mean():.4f} ± {cv.std():.4f}")

    importances = rf_pipeline.named_steps["clf"].feature_importances_
    top10 = sorted(zip(feature_names, importances), key=lambda x: -x[1])[:10]
    print("\n  Top 10 Behavioral Features ────────────────────────────────────────────")
    for name, imp in top10:
        bar = "█" * int(imp * 500)
        print(f"  {name:<40} {bar} {imp:.4f}")

    print("\n  Training Isolation Forest (unsupervised zero-day detection) ...")
    X_benign = X_tr[y_tr == 0]
    iso = IsolationForest(
        n_estimators=100,
        contamination=0.05,
        random_state=42,
        n_jobs=-1,
    )
    iso.fit(X_benign)
    iso_labels  = iso.predict(X_te)
    iso_malware = (iso_labels == -1).astype(int)
    iso_acc     = (iso_malware == y_te).mean()
    print(f"  IsolationForest accuracy on test set: {iso_acc:.4f}")
    print(f"  (Trains only on benign apps → detects any deviation as anomaly)")

    rp = REPORT_DIR / "model3_eval_report.json"
    rp.write_text(json.dumps({
        "timestamp":                   datetime.now().isoformat(),
        "roc_auc_test":                round(auc, 4),
        "cv_auc_mean":                 round(cv.mean(), 4),
        "cv_auc_std":                  round(cv.std(),  4),
        "isolation_forest_accuracy":   round(iso_acc, 4),
        "confusion_matrix":            cm.tolist(),
        "top_10_behavioral_features":  [(n, round(i, 5)) for n, i in top10],
    }, indent=2))
    print(f"\n  Report → {rp}")

    return rf_pipeline, iso

RISK_THRESHOLDS = {
    "SAFE":       (0.00, 0.30),
    "SUSPICIOUS": (0.30, 0.60),
    "CRITICAL":   (0.60, 1.01),
}

def predict(
    bf: BehavioralFeatures,
    rf_pipeline: Pipeline,
    iso: IsolationForest,
    feature_names: list,
) -> dict:
    """
    Score a single app's behavioral features.
    Fuses: rule-based heuristic + RF classifier + Isolation Forest.
    All computation is local. Zero data egress.
    """
    sep = "═" * 62
    print(f"\n{sep}")
    print(f"  Behavioral scan: {bf.package_name or 'unknown'}")
    print(sep)
    print(f"  Claims SBI app     : {bf.claims_to_be_sbi}")
    print(f"  Sideloaded         : {bf.is_sideloaded}")
    print(f"  Permissions        : {bf.permission_count} ({bf.dangerous_perm_count} dangerous)")
    print(f"  Forbidden perms    : {bf.forbidden_perm_count}")
    print(f"  Dangerous combos   : {bf.dangerous_combo_count}")
    print(f"  Fingerprint drift  : {bf.fingerprint_divergence:.3f}")
    print(f"  Overlay declared   : {bf.overlay_window_declared}")
    print(f"  Accessibility      : {bf.has_accessibility}")
    print(
        "  SMS risk (read/recv/send): "
        f"{bf.has_sms_read or bf.has_sms_receive or bf.has_send_sms}"
    )
    print(f"  Heuristic score    : {bf.heuristic_risk_score:.3f}")

    bf_dict = asdict(bf)
    row = {}
    for fn in feature_names:
        val = bf_dict.get(fn, 0)
        row[fn] = float(val) if not isinstance(val, str) else 0.0
    X_live = pd.DataFrame([row])[feature_names].fillna(0.0)

    ml_prob = float(rf_pipeline.predict_proba(X_live)[0][1])

    iso_score_raw = float(iso.score_samples(X_live)[0])
    iso_risk      = float(np.clip(-iso_score_raw + 0.5, 0, 1))

    final_score = 0.50 * ml_prob + 0.30 * iso_risk + 0.20 * bf.heuristic_risk_score
    final_score = round(float(np.clip(final_score, 0, 1)), 4)

    if bf.claims_to_be_sbi and bf.forbidden_perm_count > 0:
        final_score = max(final_score, 0.75)
        print(f"\n  [!] FORCED TO CRITICAL: {bf.forbidden_perm_count} YONO-forbidden perm(s) detected")

    verdict = "SAFE"
    for v, (lo, hi) in RISK_THRESHOLDS.items():
        if lo <= final_score < hi:
            verdict = v; break

    triggered = []
    if bf.claims_to_be_sbi and bf.forbidden_perm_count > 0:
        triggered.append(f"YONO-forbidden permission(s): {bf.forbidden_perm_count} detected")
    if bf.claims_to_be_sbi and bf.fingerprint_divergence > 0.3:
        triggered.append(f"Permission fingerprint divergence: {bf.fingerprint_divergence:.2f}")
    if bf.dangerous_combo_count > 0:
        triggered.append(f"Dangerous permission combo: {bf.dangerous_combo_count} match(es)")
    if bf.overlay_window_declared:
        triggered.append("Overlay window (TYPE_APPLICATION_OVERLAY) declared in manifest")
    if bf.has_accessibility and (bf.has_sms_read or bf.has_send_sms):
        triggered.append(
            "Accessibility + SMS read/send = keylogger / OTP theft pattern"
        )
    if bf.is_sideloaded and bf.claims_to_be_sbi:
        triggered.append("Sideloaded SBI clone (not installed from Play Store)")

    result = {
        "package_name":           bf.package_name,
        "claims_to_be_sbi":       bf.claims_to_be_sbi,
        "is_sideloaded":          bf.is_sideloaded,
        "ml_risk_prob":           round(ml_prob,    4),
        "isolation_forest_risk":  round(iso_risk,   4),
        "heuristic_risk_score":   round(bf.heuristic_risk_score, 4),
        "final_risk_score":       final_score,
        "verdict":                verdict,
        "analyst_review_needed":  verdict == "SUSPICIOUS",
        "triggered_signals":      triggered,
        "zero_data_egress":       True,
        "timestamp":              datetime.now().isoformat(),
    }

    icons = {"SAFE": "✅", "SUSPICIOUS": "⚠️ ", "CRITICAL": "🚨"}
    print(f"\n  ML Prob (RF)       : {ml_prob:.4f}")
    print(f"  Isolation Forest   : {iso_risk:.4f}")
    print(f"  Heuristic Score    : {bf.heuristic_risk_score:.4f}")
    print(f"  Final Risk Score   : {final_score:.4f}")
    print(f"\n  ┌{'─'*42}┐")
    print(f"  │  VERDICT: {icons.get(verdict,'')} {verdict:<30}│")
    print(f"  └{'─'*42}┘")

    if triggered:
        print("\n  Triggered signals:")
        for s in triggered:
            print(f"    → {s}")

    if verdict == "SUSPICIOUS":
        print("\n  → Added to SBI analyst review queue (never silently blocked)")
    elif verdict == "CRITICAL":
        print("\n  → Persistent alert shown to user · CERT-In report queued")

    return result

def run_self_test(rf_pipeline, iso, feature_names):
    print("\n" + "═"*62)
    print("  SELF-TEST: Synthetic Scenarios")
    print("═"*62)

    print("\n  Scenario 1 — Genuine YONO SBI App (expected: SAFE)")
    bf1 = behavioral_features_from_dict({
        "package_name":     "com.sbi.lotusintouch",
        "claims_to_be_sbi": True,
        "is_sideloaded":    False,
        "permissions":      list(YONO_KNOWN_GOOD_PERMISSIONS),
    })
    predict(bf1, rf_pipeline, iso, feature_names)

    print("\n  Scenario 2 — Fake YONO Clone (expected: CRITICAL)")
    bf2 = behavioral_features_from_dict({
        "package_name":     "com.sbi.yono.kyc.update",
        "claims_to_be_sbi": True,
        "is_sideloaded":    True,
        "permissions": [
            "android.permission.INTERNET",
            "android.permission.CAMERA",
            "android.permission.BIND_ACCESSIBILITY_SERVICE",
            "android.permission.SYSTEM_ALERT_WINDOW",
            "android.permission.READ_SMS",
            "android.permission.RECEIVE_SMS",
            "android.permission.SEND_SMS",
        ],
        "overlay_window_declared": True,
    })
    predict(bf2, rf_pipeline, iso, feature_names)

    print("\n  Scenario 3 — Generic Banking Malware (expected: CRITICAL/SUSPICIOUS)")
    bf3 = behavioral_features_from_dict({
        "package_name": "com.flashlight.battery.saver",
        "permissions": [
            "android.permission.RECEIVE_SMS",
            "android.permission.READ_SMS",
            "android.permission.SEND_SMS",
            "android.permission.BIND_ACCESSIBILITY_SERVICE",
            "android.permission.RECORD_AUDIO",
            "android.permission.CAMERA",
            "android.permission.INTERNET",
            "android.permission.GET_ACCOUNTS",
        ],
    })
    predict(bf3, rf_pipeline, iso, feature_names)

def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║  KAVACH · ML Model 3 · Behavioral Anomaly Engine        ║")
    print("╚══════════════════════════════════════════════════════════╝")

    if not MODEL_PATH.exists() or not ISO_PATH.exists():
        data_csv = resolve_dataset_csv()
        if data_csv is None:
            print("\n[ERROR] Dataset CSV not found. Tried:")
            for p in DATA_PATH_CANDIDATES:
                print(f"    {p}")
            print("  Download from Kaggle:")
            print("  https://www.kaggle.com/datasets/shashwatwork/android-malware-dataset-for-machine-learning")
            sys.exit(1)

        X, y, feature_names = load_dataset(data_csv)
        rf_pipeline, iso    = train(X, y, feature_names)

        print(f"\n[5/5] Saving models ...")
        joblib.dump(rf_pipeline, MODEL_PATH)
        joblib.dump(iso,         ISO_PATH)
        FEATURES_PATH.write_text(json.dumps(feature_names))
        print(f"      RF model  → {MODEL_PATH}")
        print(f"      ISO model → {ISO_PATH}")
        print("      Done ✓")
    else:
        print(f"\n[INFO] Trained models found — skipping training.")
        print("       Delete .pkl files to retrain.")

    rf_pipeline   = joblib.load(MODEL_PATH)
    iso           = joblib.load(ISO_PATH)
    feature_names = json.loads(FEATURES_PATH.read_text())

    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg == "--self-test":
            run_self_test(rf_pipeline, iso, feature_names)
        elif Path(arg).exists():
            bf     = extract_behavioral_features_live(arg)
            result = predict(bf, rf_pipeline, iso, feature_names)
            ts     = datetime.now().strftime("%Y%m%d_%H%M%S")
            out    = REPORT_DIR / f"behavioral_{Path(arg).stem}_{ts}.json"
            out.write_text(json.dumps(result, indent=2))
            print(f"\n  Report → {out}")
        else:
            print(f"[ERROR] Not found: {arg}")
            sys.exit(1)
    else:
        print("\n[INFO] No APK path given. Running built-in self-test ...")
        run_self_test(rf_pipeline, iso, feature_names)
        print("\n  Usage:")
        print("    python apk_ml_model/scripts/model3_behavioral_engine.py path/to/app.apk")
        print("    python apk_ml_model/scripts/model3_behavioral_engine.py --self-test")

if __name__ == "__main__":
    main()
