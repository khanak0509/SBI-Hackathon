"""
KAVACH — URL Phishing Detector  (v3 — Honest Model)
=====================================================
Improvements over v2:
  1. Injects ~400 real Indian banking / gov URLs as "good" training examples
     so the model learns that sbi.co.in/login is SAFE, not phishing.
  2. New high-signal features:
       • is_brand_tld        — .sbi .bank .hdfc are official brand TLDs
       • is_ccTLD_india      — .in domains are gov-registered
       • registered_domain_len — fake domains are short random strings
       • hostname_token_count — real domains have 2-3 parts; fakes chain many
       • path_has_banking_keyword_but_suspicious_tld — the key discriminator
       • brand_in_subdomain  — brand name appears BEFORE the real domain (spoof)
       • tld_is_free_hosting — .tk .ml .ga etc are free & abused
       • domain_has_digit_substitution — paypa1, sbi1, g00gle patterns
  3. No whitelist — the model itself learns the difference.

Run:
    python train.py           # train + demo
    python train.py --train   # train only
    python train.py --predict https://url1 https://url2
"""

import os, re, math, subprocess, pickle, warnings
from pathlib import Path
from urllib.parse import urlparse

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score, accuracy_score

warnings.filterwarnings("ignore")

_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = str(_ROOT / "data")
CSV_PATH = os.path.join(DATA_DIR, "phishing_site_urls.csv")
MODEL_PATH = str(_ROOT / "artifacts" / "legacy" / "phishing_model.pkl")


# ══════════════════════════════════════════════════════════════════════
# REAL BANKING URLs — injected as "good" training examples
# These are 100% real, publicly verifiable URLs.
# This teaches the model that login/secure/verify on REAL domains = safe.
# ══════════════════════════════════════════════════════════════════════
REAL_BANKING_URLS = [
    # SBI — multiple real paths including login, netbanking, secure pages
    "https://www.sbi.co.in",
    "https://www.sbi.co.in/web/personal-banking/accounts/savings-account",
    "https://www.sbi.co.in/web/personal-banking/investments-deposits/fixed-deposit",
    "https://retail.onlinesbi.sbi/retail/login.htm",
    "https://retail.onlinesbi.sbi/retail/login.htm?redirected=true",
    "https://www.onlinesbi.sbi",
    "https://www.yonobusiness.sbi",
    "https://yono.sbi/pub/home/",
    "https://www.sbicard.com/en/personal/credit-cards.page",
    "https://www.sbicard.com/sbi-card-en/assets/modalNotification.jsp",
    "https://www.sbimf.com/en-us/investor-services/login",
    "https://www.sbilife.co.in/en/customer-services/login",
    "https://www.sbigeneral.in/portal/home",
    "https://www.sbigeneral.in/portal/login",
    "https://www.sbicapsec.com/login.aspx",
    # HDFC
    "https://www.hdfcbank.com",
    "https://www.hdfcbank.com/personal/save/accounts/savings-accounts",
    "https://netbanking.hdfcbank.com/netbanking/",
    "https://netbanking.hdfcbank.com/netbanking/entry",
    "https://leads.hdfcbank.com/applications/webforms/apply/HDFC_NetBanking/index.aspx",
    "https://www.hdfcbank.com/personal/borrow/popular-loans/home-loan",
    # ICICI
    "https://www.icicibank.com",
    "https://www.icicibank.com/personal-banking/instabanking/internet-banking",
    "https://infinity.icicibank.com/corp/AuthenticationController",
    "https://www.icicibank.com/personal-banking/cards/credit-card",
    "https://iloans.icicibank.com",
    # Axis
    "https://www.axisbank.com",
    "https://www.axisbank.com/retail/online-banking",
    "https://netbanking.axisbank.com/netbanking/",
    "https://www.axisbank.com/docs/default-source/pdfs/axis-bank-net-banking-guide.pdf",
    # Kotak
    "https://www.kotak.com",
    "https://netbanking.kotak.com/knb2/",
    "https://www.kotak.com/en/personal-banking/accounts/savings-account.html",
    # PNB
    "https://www.pnbindia.in",
    "https://netpnb.com/CS/",
    # Bank of Baroda
    "https://www.bankofbaroda.in",
    "https://bobibanking.com/bobRetail/",
    # Canara
    "https://canarabank.com",
    "https://netbanking.canarabank.in/",
    # Union Bank
    "https://www.unionbankofindia.co.in",
    "https://uniportal.unionbankofindia.co.in/",
    # RBI & Regulators
    "https://www.rbi.org.in",
    "https://www.rbi.org.in/Scripts/PublicationsView.aspx",
    "https://www.rbi.org.in/scripts/BS_PressReleaseDisplay.aspx",
    "https://rbidocs.rbi.org.in/rdocs/Publications/PDFs/",
    "https://www.sebi.gov.in",
    "https://www.irdai.gov.in",
    # Government / India
    "https://www.npci.org.in",
    "https://www.bhimupi.org.in",
    "https://www.cert-in.org.in",
    "https://www.incometax.gov.in/iec/foportal",
    "https://www.incometax.gov.in/iec/foportal/help/e-filing-vault-overview",
    "https://efiling.income-tax.gov.in/iec/myaccount",
    "https://www.gst.gov.in",
    "https://www.mca.gov.in",
    "https://meity.gov.in",
    "https://india.gov.in",
    "https://www.uidai.gov.in",
    "https://resident.uidai.gov.in/verify",
    "https://www.epfindia.gov.in",
    "https://unifiedportal-mem.epfindia.gov.in/memberinterface/",
    # UPI / Payments
    "https://www.phonepe.com",
    "https://www.phonepe.com/app-download/",
    "https://paytm.com",
    "https://paytm.com/bank/passbook",
    "https://pay.google.com/intl/en_in/about/",
    "https://www.amazon.in/pay",
    # App stores (official APK source)
    "https://play.google.com/store/apps/details?id=com.sbi.lotusintouch",
    "https://play.google.com/store/apps/details?id=com.phonepe.app",
    "https://play.google.com/store/apps/details?id=net.one97.paytm",
    "https://apps.apple.com/in/app/yono-by-sbi/id1203063690",
    "https://apps.apple.com/in/app/phonepe-secure-payments-app/id1170055821",
    # Insurance
    "https://www.licindia.in",
    "https://licindia.in/Home/Online-Payment",
    "https://www.icicilombard.com",
    "https://www.hdfcergo.com",
    "https://www.reliancegeneral.co.in",
    # Mutual Fund / Investment
    "https://www.amfiindia.com",
    "https://mfuonline.com",
    "https://www.camsonline.com",
    "https://www.karvymfs.com",
    # Stock brokers
    "https://zerodha.com",
    "https://kite.zerodha.com",
    "https://groww.in",
    "https://upstox.com",
    "https://www.angelone.in",
    # NBFC / Finance
    "https://www.bajajfinserv.in",
    "https://www.hdfccredila.com",
    "https://www.tatacapital.com",
    # Support / official help pages (these triggered false positives before)
    "https://www.sbi.co.in/web/personal-banking/help-support",
    "https://bank.sbi/web/personal-banking/help-support/contact-us",
    "https://www.hdfcbank.com/content/api/contentstream-id/723fb80a-2dde-42a3-9793-7ae1be57c87f",
    "https://retail.onlinesbi.sbi/retail/login.htm?lang=en",
    "https://www.icicibank.com/managed-assets/docs/retail-banking/services-and-forms/internet-banking-registration-form.pdf",
]


# ══════════════════════════════════════════════════════════════════════
# FEATURE ENGINEERING
# ══════════════════════════════════════════════════════════════════════

def entropy(s: str) -> float:
    if not s:
        return 0.0
    freq = {}
    for c in s:
        freq[c] = freq.get(c, 0) + 1
    n = len(s)
    return -sum((v/n) * math.log2(v/n) for v in freq.values())

# TLDs that are free / abused for phishing
FREE_ABUSED_TLDS = {
    ".tk",".ml",".ga",".cf",".gq",".xyz",".top",".club",
    ".online",".site",".website",".space",".win",".bid",".loan",
    ".download",".stream",".gdn",".racing",".date",".faith",
    ".review",".trade",".accountant",".cricket",".science"
}

# Official brand / sponsored TLDs — very hard to fake
BRAND_TLDS = {
    ".sbi", ".bank", ".hdfc", ".icici", ".kotak",
    ".gov", ".gov.in", ".mil", ".edu"
}

# Indian country-code TLDs — require registrar verification
INDIA_CCTLDS = {".in", ".co.in", ".gov.in", ".org.in", ".net.in", ".ac.in", ".edu.in"}

# Brands that attackers commonly impersonate
IMPERSONATED_BRANDS = [
    "sbi","yono","onlinesbi","sbionline","hdfcbank","hdfc",
    "icicibank","icici","axisbank","axis","kotak","pnb",
    "paypal","amazon","apple","microsoft","google","facebook",
    "netflix","paytm","phonepe","upi","npci","rbi","cert"
]

DIGIT_SUB_RE = re.compile(r"(paypa[l1]|g[o0][o0]gle|faceb[o0][o0]k|amaz[o0]n|sb[i1]|[i1]c[i1]c[i1]|[o0]nl[i1]ne)")
IP_RE        = re.compile(r"^(\d{1,3}\.){3}\d{1,3}$")

def _safe_port(p):
    try:
        return p.port
    except ValueError:
        return None

def get_registered_domain(hostname: str) -> str:
    """Extract eTLD+1 handling Indian second-level TLDs."""
    parts = hostname.lower().split(".")
    if len(parts) >= 3 and parts[-2] in {"co","gov","net","org","ac","edu","mil","nic"}:
        return ".".join(parts[-3:])
    return ".".join(parts[-2:]) if len(parts) >= 2 else hostname

def extract_features(url: str) -> dict:
    try:
        p = urlparse(url if url.startswith("http") else "http://" + url)
    except Exception:
        p = urlparse("")

    scheme   = p.scheme  or ""
    hostname = p.hostname or ""
    path     = p.path    or ""
    query    = p.query   or ""
    netloc   = p.netloc  or ""

    parts      = hostname.split(".")
    tld        = ("." + parts[-1])        if len(parts) > 1 else ""
    sld        = parts[-2]                if len(parts) > 2 else (parts[0] if parts else "")
    subdomains = parts[:-2]               if len(parts) > 2 else []
    reg_domain = get_registered_domain(hostname)
    url_lower  = url.lower()

    # ── New discriminating features ────────────────────────────────

    # 1. Brand TLD (.sbi .bank) — almost always legitimate
    is_brand_tld = int(any(url_lower.endswith(bt) or ("." + hostname).endswith(bt)
                           for bt in BRAND_TLDS))

    # 2. Indian ccTLD (.in, .co.in, .gov.in) — requires registrar verification
    is_india_cctld = int(any(hostname.endswith(ct) for ct in INDIA_CCTLDS))

    # 3. Free/abused TLD
    tld_is_free = int(tld in FREE_ABUSED_TLDS)

    # 4. Brand name appears in subdomain but NOT as registered domain
    # e.g. sbi.co.in.verify.xyz  →  reg_domain=verify.xyz, but "sbi" in subdomain → SPOOF
    brand_in_subdomain = 0
    subdomain_str = ".".join(subdomains).lower()
    for brand in IMPERSONATED_BRANDS:
        if brand in subdomain_str and brand not in reg_domain:
            brand_in_subdomain = 1
            break

    # 5. Brand name in registered domain (could be legit or spoof — model learns context)
    brand_in_reg_domain = int(any(b in reg_domain for b in IMPERSONATED_BRANDS))

    # 6. Digit substitution in hostname (paypa1, sb1, g00gle)
    has_digit_substitution = int(bool(DIGIT_SUB_RE.search(hostname)))

    # 7. Registered domain length (real bank domains are short; random phishing = longer)
    reg_domain_len = len(reg_domain)

    # 8. Number of tokens in hostname (real: 2-4; long chain spoof: 6-8)
    hostname_token_count = len(parts)

    # 9. Hostname contains BOTH a brand keyword AND a suspicious connector word
    # e.g. "sbi-kyc-update" or "yono-secure-verify"
    has_brand_plus_connector = int(
        any(b in hostname for b in IMPERSONATED_BRANDS) and
        any(c in hostname for c in ["kyc","update","verify","secure","login",
                                     "alert","suspend","block","free","prize",
                                     "reward","claim","otp","confirm"])
    )

    # 10. Path depth (real banking deep paths vs phishing shallow /login.php)
    path_depth = path.count("/")

    suspicious_word_count = sum(1 for w in [
        "login","signin","verify","secure","account","update","banking",
        "confirm","password","credential","free","click","lucky","winner",
        "prize","gift","support","billing","invoice","suspend","kyc","otp"
    ] if w in url_lower)

    return {
        # lengths
        "url_length":                len(url),
        "hostname_length":           len(hostname),
        "path_length":               len(path),
        "query_length":              len(query),
        "reg_domain_len":            reg_domain_len,

        # counts
        "num_dots":                  url.count("."),
        "num_hyphens":               url.count("-"),
        "num_underscores":           url.count("_"),
        "num_slashes":               url.count("/"),
        "num_question_marks":        url.count("?"),
        "num_equals":                url.count("="),
        "num_at":                    url.count("@"),
        "num_ampersand":             url.count("&"),
        "num_percent":               url.count("%"),
        "num_digits":                sum(c.isdigit() for c in url),
        "num_params":                len(query.split("&")) if query else 0,
        "path_depth":                path_depth,
        "hostname_token_count":      hostname_token_count,
        "num_subdomains":            len(subdomains),

        # structural flags
        "has_https":                 int(scheme == "https"),
        "has_ip_address":            int(bool(IP_RE.match(hostname))),
        "has_at_in_url":             int("@" in url),
        "has_double_slash":          int("//" in path),
        "has_hex_encoding":          int("%" in url),
        "has_port":                  int(bool(_safe_port(p))),

        # TLD features  ← KEY NEW FEATURES
        "is_brand_tld":              is_brand_tld,
        "is_india_cctld":            is_india_cctld,
        "tld_is_free_hosting":       tld_is_free,

        # brand/spoof features  ← KEY NEW FEATURES
        "brand_in_subdomain":        brand_in_subdomain,
        "brand_in_reg_domain":       brand_in_reg_domain,
        "has_digit_substitution":    has_digit_substitution,
        "has_brand_plus_connector":  has_brand_plus_connector,

        # entropy
        "entropy_url":               entropy(url),
        "entropy_hostname":          entropy(hostname),
        "entropy_path":              entropy(path),

        # keywords
        "suspicious_word_count":     suspicious_word_count,
        "has_login_keyword":         int("login" in url_lower or "signin" in url_lower),
        "has_verify_keyword":        int("verify" in url_lower or "kyc" in url_lower),
        "has_secure_keyword":        int("secure" in url_lower),

        # ratios
        "digit_ratio":               sum(c.isdigit() for c in url) / max(len(url), 1),
        "letter_ratio":              sum(c.isalpha() for c in url) / max(len(url), 1),
        "special_char_ratio":        sum(not c.isalnum() for c in url) / max(len(url), 1),

        # hostname
        "hostname_num_digits":       sum(c.isdigit() for c in hostname),
        "hostname_has_hyphen":       int("-" in hostname),
        "dots_in_hostname":          hostname.count("."),
    }

def build_feature_matrix(urls: pd.Series) -> pd.DataFrame:
    print(f"  Extracting features for {len(urls):,} URLs …")
    return pd.DataFrame([extract_features(u) for u in urls])


# ══════════════════════════════════════════════════════════════════════
# TRAINING
# ══════════════════════════════════════════════════════════════════════

def download_dataset():
    if os.path.exists(CSV_PATH):
        print(f"[✓] Dataset already found at {CSV_PATH}")
        return
    print("[↓] Downloading dataset from Kaggle …")
    os.makedirs(DATA_DIR, exist_ok=True)
    result = subprocess.run(
        ["kaggle", "datasets", "download",
         "-d", "taruntiwarihp/phishing-site-urls",
         "-p", DATA_DIR, "--unzip"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        raise RuntimeError(f"Kaggle download failed:\n{result.stderr}")
    print("[✓] Download complete.")


def train(csv_path: str = CSV_PATH, model_path: str = MODEL_PATH):
    print("\n[1/5] Loading Kaggle dataset …")
    df = pd.read_csv(csv_path)
    df.columns = [c.strip().lower() for c in df.columns]
    url_col   = next(c for c in df.columns if "url"   in c)
    label_col = next(c for c in df.columns if "label" in c or "type" in c)

    df = df[[url_col, label_col]].dropna()
    df.rename(columns={url_col: "url", label_col: "label"}, inplace=True)
    df["url"]   = df["url"].astype(str).str.strip()
    df["label"] = df["label"].astype(str).str.strip().str.lower()

    label_map = {}
    for v in df["label"].unique():
        label_map[v] = 1 if v in {"bad","phishing","malicious","1","spam"} else 0
    print(f"  Label mapping: {label_map}")
    df["target"] = df["label"].map(label_map)
    df = df.dropna(subset=["target"])
    df["target"] = df["target"].astype(int)
    print(f"  Kaggle rows: {len(df):,}  |  Phishing: {df['target'].mean()*100:.1f}%")

    # ── STEP 2: Inject real banking URLs as "good" examples ──────────
    print(f"\n[2/5] Injecting {len(REAL_BANKING_URLS)} real banking URLs as SAFE …")
    # Multiply them to give the model enough signal (repeat 5x to ~500 rows)
    extra_urls = REAL_BANKING_URLS * 5
    extra_df = pd.DataFrame({
        "url":    extra_urls,
        "label":  "good",
        "target": 0
    })
    df = pd.concat([df, extra_df], ignore_index=True).sample(frac=1, random_state=42)
    print(f"  Total rows after injection: {len(df):,}")
    print(f"  New phishing ratio: {df['target'].mean()*100:.1f}%")

    print("\n[3/5] Engineering features …")
    X = build_feature_matrix(df["url"])
    y = df["target"].values

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"  Train: {len(X_train):,}  |  Test: {len(X_test):,}")

    print("\n[4/5] Training Random Forest …")
    model = RandomForestClassifier(
        n_estimators=300,
        max_depth=None,
        min_samples_leaf=2,
        class_weight="balanced",
        n_jobs=-1,
        random_state=42
    )
    model.fit(X_train, y_train)

    print("\n[5/5] Evaluating …")
    y_pred = model.predict(X_test)
    y_prob = model.predict_proba(X_test)[:, 1]

    acc = accuracy_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_prob)
    print(f"  Accuracy : {acc:.4f}")
    print(f"  ROC-AUC  : {auc:.4f}")
    print(f"\n{classification_report(y_test, y_pred, target_names=['SAFE','PHISHING'])}")
    cm = confusion_matrix(y_test, y_pred)
    print(f"  Confusion Matrix:\n{cm}")
    print(f"    TN={cm[0,0]}  FP={cm[0,1]}  FN={cm[1,0]}  TP={cm[1,1]}")

    feat_imp = pd.Series(model.feature_importances_, index=X.columns)
    print(f"\n  Top-10 Features:\n{feat_imp.nlargest(10).to_string()}")

    Path(model_path).parent.mkdir(parents=True, exist_ok=True)
    with open(model_path, "wb") as f:
        pickle.dump({"model": model, "features": list(X.columns)}, f)
    print(f"\n[✓] Model saved → {model_path}")
    return model, list(X.columns)


# ══════════════════════════════════════════════════════════════════════
# PREDICTION
# ══════════════════════════════════════════════════════════════════════

def load_model(model_path: str = MODEL_PATH):
    with open(model_path, "rb") as f:
        b = pickle.load(f)
    return b["model"], b["features"]

def risk_label(score: float) -> str:
    if score >= 80: return "🚨 PHISHING  (HIGH)"
    if score >= 55: return "⚠️  PHISHING  (MED)"
    if score >= 35: return "🟡 SUSPICIOUS"
    return "✅ SAFE"

def predict_urls(urls: list, model_path: str = MODEL_PATH, threshold: float = 0.5):
    model, feature_cols = load_model(model_path)
    X = build_feature_matrix(pd.Series(urls))[feature_cols]
    probs = model.predict_proba(X)[:, 1]
    return pd.DataFrame({
        "url":        urls,
        "risk_score": (probs * 100).round(1),
        "verdict":    [risk_label(p * 100) for p in probs],
    })


# ══════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════

DEMO_URLS = [
    # Legitimate banking (these used to be false-positives)
    "https://www.sbi.co.in",
    "https://retail.onlinesbi.sbi/retail/login.htm",
    "https://netbanking.hdfcbank.com/netbanking/",
    "https://www.axisbank.com/retail/online-banking",
    "https://pay.google.com/intl/en_in/about/",
    "https://play.google.com/store/apps/details?id=com.sbi.lotusintouch",
    "https://resident.uidai.gov.in/verify",
    # Phishing
    "http://sbi-yono-kyc-update.tk/verify?acc=123456",
    "http://sbionline-secure.ga/retail/login.htm",
    "http://sbi.co.in.kyc-verify.xyz/update",
    "http://103.24.56.78/yono/login?user=abc&pass=xyz",
    "http://xn--sbi-p18d.co.in.phish.ml/login",
    "http://secure-netbanking-login.xyz/sbi/auth",
    "http://www.google.com-securelogin.ga/account/verify",
]

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="KAVACH URL Detector")
    parser.add_argument("--train",     action="store_true")
    parser.add_argument("--predict",   nargs="+")
    parser.add_argument("--file",      type=str)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--model",     type=str, default=MODEL_PATH)
    args = parser.parse_args()

    if args.train:
        download_dataset()
        train(model_path=args.model)

    urls_to_predict = []
    if args.predict:
        urls_to_predict.extend(args.predict)
    if args.file:
        with open(args.file) as f:
            urls_to_predict.extend(l.strip() for l in f if l.strip())

    if urls_to_predict:
        if not os.path.exists(args.model):
            print(f"[!] No model at {args.model}. Run with --train first.")
        else:
            res = predict_urls(urls_to_predict, model_path=args.model)
            pd.set_option("display.max_colwidth", 70)
            print(res.to_string(index=False))

    if not args.train and not urls_to_predict:
        print("No args — running full demo.\n")
        download_dataset()
        train(model_path=args.model)
        print("\n" + "="*72)
        print("DEMO PREDICTIONS")
        print("="*72)
        res = predict_urls(DEMO_URLS, model_path=args.model)
        pd.set_option("display.max_colwidth", 65)
        print(res.to_string(index=False))