"""
KAVACH — URL Test Suite (v3 — No whitelist, honest ML)
=======================================================
45 URLs: 20 legitimate + 25 phishing
The model itself must learn the difference. No shortcuts.

Run from SBI-Hackathon/backend:
  python url_ml_model/scripts/legacy_v3_standalone_test.py
"""

import importlib.util
from pathlib import Path

import pandas as pd

_ROOT = Path(__file__).resolve().parent.parent
_SCRIPTS = Path(__file__).resolve().parent
MODEL_PATH = str(_ROOT / "artifacts" / "legacy" / "phishing_model.pkl")

spec = importlib.util.spec_from_file_location(
    "train",
    str(_SCRIPTS / "legacy_v3_standalone_train.py"),
)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
predict_urls = mod.predict_urls

LEGITIMATE = [
    ("SBI Official",          "https://www.sbi.co.in"),
    ("google.com",            "https://www.google.com"),
    ("SBI YONO",              "https://www.yonobusiness.sbi"),
    ("SBI Net Banking",       "https://retail.onlinesbi.sbi/retail/login.htm"),
    ("SBI Cards",             "https://www.sbicard.com"),
    ("SBI Mutual Fund",       "https://www.sbimf.com"),
    ("SBI Life",              "https://www.sbilife.co.in"),
    ("SBI General Insurance", "https://www.sbigeneral.in"),
    ("YONO Play Store",       "https://play.google.com/store/apps/details?id=com.sbi.lotusintouch"),
    ("YONO iOS App Store",    "https://apps.apple.com/in/app/yono-by-sbi/id1203063690"),
    ("RBI Official",          "https://www.rbi.org.in"),
    ("NPCI / UPI",            "https://www.npci.org.in"),
    ("CERT-In",               "https://www.cert-in.org.in"),
    ("HDFC Net Banking",      "https://netbanking.hdfcbank.com/netbanking"),
    ("ICICI iMobile",         "https://www.icicibank.com/Personal-Banking/instabanking/mobile-banking"),
    ("Axis Bank",             "https://www.axisbank.com/retail/online-banking"),
    ("Google Pay India",      "https://pay.google.com/intl/en_in/about"),
    ("PhonePe",               "https://www.phonepe.com"),
    ("Paytm",                 "https://paytm.com"),
    ("MeitY",                 "https://meity.gov.in"),
    ("Income Tax Portal",     "https://www.incometax.gov.in/iec/foportal"),
]

PHISHING = [
    ("Fake YONO KYC 1",       "http://sbi-yono-kyc-update.tk/verify?acc=123456"),
    ("Fake YONO KYC 2",       "http://yono-sbi-kyc.ml/login?redirect=home&token=abc"),
    ("Fake SBI Login",        "http://sbionline-secure.ga/retail/login.htm"),
    ("Typosquat sbi.co.in",   "http://www.sb1.co.in/personal-banking/login"),
    ("Subdomain spoof",       "http://sbi.co.in.kyc-verify.xyz/update"),
    ("IP-based fake YONO",    "http://103.24.56.78/yono/login?user=abc&pass=xyz"),
    ("Fake SBI reward",       "http://sbi-reward-2025.tk/claim?mobile=9876543210"),
    ("Punycode-style spoof",  "http://xn--sbi-p18d.co.in.phish.ml/login"),
    ("Account block scam",    "http://sbi-account-suspended.cf/reactivate?id=cust001"),
    ("OTP harvester",         "http://sbi-otp-verify.gq/confirm?otp=&mobile="),
    ("Fake net banking",      "http://secure-netbanking-login.xyz/sbi/auth"),
    ("Fake UPI fraud",        "http://upi-cashback-offer.tk/claim?vpa=user@sbi"),
    ("Credential harvester",  "http://192.168.10.22/banking/secure/login.php"),
    ("HDFC spoof",            "http://hdfcbank-netbanking.ml/login?session=new"),
    ("Phishing with @",       "http://login@sbi-secure.cf/home"),
    ("Redirect chain",        "http://bit.ly.sbi-kyc.gq/redir?url=phish"),
    ("Data exfil URL",        "http://collect-sbi-data.win/form?name=&card=&cvv="),
    ("Fake IMPS transfer",    "http://imps-transfer-sbi.loan/initiate?to=fraud"),
    ("WhatsApp link spoof",   "http://wa.me.sbi-offer.xyz/prize?phone=91XXXXXXXX"),
    ("Fake APK download",     "http://yono-sbi-update.download/YONO_v3.2_official.apk"),
    ("Typo: yono0.sbi",       "http://yono0.sbi.kyc-alert.club/verify"),
    ("Hex-encoded phish",     "http://sbi%2Dlogin%2Esecure.tk/auth%3Ftoken%3Dabc"),
    ("Long subdomain chain",  "http://secure.login.sbi.co.in.verify.kyc.update.ml/home"),
    ("Fake CERT-In warning",  "http://cert-in-alert-sbi.cf/malware-detected?device=android"),
    ("SMS lure page",         "http://sbi-free-cashback-5000.gdn/apply?mobile=98XXXXXXXX"),
]

all_entries = [(lbl, url, "LEGITIMATE") for lbl, url in LEGITIMATE] + \
              [(lbl, url, "PHISHING")   for lbl, url in PHISHING]

desc_col   = [e[0] for e in all_entries]
urls_col   = [e[1] for e in all_entries]
actual_col = [e[2] for e in all_entries]

results = predict_urls(urls_col, model_path=MODEL_PATH)
results.insert(0, "actual",      actual_col)
results.insert(0, "description", desc_col)

def print_section(title, df):
    print(f"\n{'═'*82}")
    print(f"  {title}")
    print(f"{'═'*82}")
    for _, row in df.iterrows():
        bar_len = int(row["risk_score"] / 5)
        bar = "█" * bar_len + "░" * (20 - bar_len)
        print(f"  [{bar}] {row['risk_score']:>5.1f}%  {row['verdict']:<28}  {row['description']}")

leg = results[results["actual"] == "LEGITIMATE"]
phi = results[results["actual"] == "PHISHING"]

print("\n" + "█"*82)
print("  KAVACH — URL THREAT ASSESSMENT  |  SBI FinNovation Hackathon 2026")
print("  (Pure ML — no whitelist, no shortcuts)")
print("█"*82)

print_section("✅ LEGITIMATE URLs  (expected: score < 50)", leg)
print_section("🚨 PHISHING URLs   (expected: score ≥ 50)", phi)

leg_correct = (leg["risk_score"] < 50).sum()
phi_correct = (phi["risk_score"] >= 50).sum()
total       = len(results)

print(f"\n{'─'*82}")
print(f"  SUMMARY  (Pure ML, no whitelist)")
print(f"{'─'*82}")
print(f"  Legitimate correctly identified  (score < 50) : {leg_correct}/{len(leg)}")
print(f"  Phishing correctly flagged       (score ≥ 50) : {phi_correct}/{len(phi)}")
print(f"  Overall accuracy on this test set             : {(leg_correct+phi_correct)/total*100:.1f}%")
print(f"{'─'*82}\n")

_out = _ROOT / "reports" / "legacy" / "kavach_test_results.csv"
_out.parent.mkdir(parents=True, exist_ok=True)
results.to_csv(str(_out), index=False)
print(f"  [✓] Saved → {_out}\n")