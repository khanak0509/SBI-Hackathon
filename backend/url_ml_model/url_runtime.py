
from __future__ import annotations

import os
import re
from typing import Any, Sequence
from urllib.parse import parse_qs, urlparse

import numpy as np

SUSPICIOUS_TLDS = {
    ".xyz",
    ".top",
    ".click",
    ".pw",
    ".tk",
    ".ml",
    ".ga",
    ".cf",
    ".gq",
    ".loan",
    ".work",
    ".men",
    ".download",
    ".stream",
    ".racing",
    ".win",
    ".bid",
    ".faith",
    ".party",
}

LEGITIMATE_SBI = {
    "onlinesbi.sbi",
    "sbi.co.in",
    "retail.onlinesbi.com",
    "sbicard.com",
    "sbimf.com",
    "sbigeneral.in",
}

SBI_KEYWORDS = [
    "sbi",
    "yono",
    "onlinesbi",
    "sbionline",
    "sbiyono",
    "sbibank",
]

def _host_registered_fqdn(url: str) -> tuple[str, str, str]:
    import tldextract

    url = str(url).strip()
    parsed = urlparse(url if "://" in url else "http://" + url)
    ext = tldextract.extract(url if "://" in url else "http://" + url)
    host = (parsed.netloc or ext.fqdn or "").lower()
    if "@" in host:
        host = host.split("@")[-1]
    host_no_port = host.split(":")[0]
    reg = getattr(ext, "top_domain_under_public_suffix", None) or getattr(
        ext, "registered_domain", ""
    )
    registered = str(reg).lower() if reg else ""
    fqdn = (ext.fqdn or host_no_port).lower()
    return host_no_port, registered, fqdn

def is_trusted_bank_url(url: str) -> bool:
    try:
        host, registered, fqdn = _host_registered_fqdn(url)
    except Exception:
        return False
    trusted = {d.lower().strip() for d in LEGITIMATE_SBI}
    if registered and registered in trusted:
        return True
    if fqdn in trusted:
        return True
    if host in trusted:
        return True
    for d in trusted:
        if fqdn and (fqdn == d or fqdn.endswith("." + d)):
            return True
        if host and (host == d or host.endswith("." + d)):
            return True
    return False

FEATURE_NAMES: list[str] = [
    "url_length",
    "domain_length",
    "num_dots",
    "num_hyphens",
    "num_underscores",
    "num_slashes",
    "num_query_params",
    "has_ip_address",
    "has_at_symbol",
    "has_double_slash",
    "uses_https",
    "has_port",
    "num_subdomains",
    "levenshtein_to_sbi",
    "suspicious_tld",
    "has_sbi_keyword",
]

def levenshtein(s1: str, s2: str) -> int:
    m, n = len(s1), len(s2)
    dp = list(range(n + 1))
    for i in range(1, m + 1):
        prev, dp[0] = dp[0], i
        for j in range(1, n + 1):
            temp = dp[j]
            dp[j] = (
                prev
                if s1[i - 1] == s2[j - 1]
                else 1 + min(prev, dp[j], dp[j - 1])
            )
            prev = temp
    return dp[n]

def extract_features(url: str) -> dict[str, float | int]:
    import tldextract

    url = str(url).strip()
    try:
        parsed = urlparse(url if "://" in url else "http://" + url)
        ext = tldextract.extract(url if "://" in url else "http://" + url)
        domain = (parsed.netloc or ext.fqdn or "").lower()
        scheme = (parsed.scheme or "http").lower()
        query = parsed.query or ""
        reg = getattr(ext, "top_domain_under_public_suffix", None) or getattr(
            ext, "registered_domain", ""
        )
        registered = str(reg).lower() if reg else ""
        subdomain = ext.subdomain.lower() if ext.subdomain else ""
        suffix = ("." + ext.suffix) if ext.suffix else ""
        after_scheme = (
            url[len(scheme) + 3 :]
            if scheme and url.lower().startswith(scheme + "://")
            else url
        )
        is_legit = registered in LEGITIMATE_SBI
        ip_pat = re.compile(r"^(\d{1,3}\.){3}\d{1,3}$")
        host_no_port = domain.split(":")[0]
        return {
            "url_length": len(url),
            "domain_length": len(domain),
            "num_dots": url.count("."),
            "num_hyphens": url.count("-"),
            "num_underscores": url.count("_"),
            "num_slashes": after_scheme.count("/"),
            "num_query_params": len(parse_qs(query)) if query else 0,
            "has_ip_address": 1 if ip_pat.match(host_no_port) else 0,
            "has_at_symbol": 1 if "@" in url else 0,
            "has_double_slash": 1 if "//" in after_scheme else 0,
            "uses_https": 1 if scheme == "https" else 0,
            "has_port": 1 if parsed.port else 0,
            "num_subdomains": len([p for p in subdomain.split(".") if p])
            if subdomain
            else 0,
            "levenshtein_to_sbi": 0
            if is_legit
            else levenshtein(registered, "onlinesbi.sbi"),
            "suspicious_tld": 1 if suffix in SUSPICIOUS_TLDS else 0,
            "has_sbi_keyword": 1
            if (any(k in url.lower() for k in SBI_KEYWORDS) and not is_legit)
            else 0,
        }
    except Exception:
        return {k: 0 for k in FEATURE_NAMES}

def feature_vector(url: str, feature_names: Sequence[str] | None = None) -> np.ndarray:
    names = list(feature_names) if feature_names is not None else FEATURE_NAMES
    feats = extract_features(url)
    return np.array([[feats[f] for f in names]], dtype=float)

def default_model_paths(data_dir: str | None = None) -> tuple[str, str]:
    base = data_dir or os.path.join(os.path.dirname(__file__), "data")
    return (
        os.path.join(base, "url_model.pkl"),
        os.path.join(base, "feature_names.pkl"),
    )

def load_url_artifacts(
    model_path: str | None = None,
    features_path: str | None = None,
) -> tuple[Any, list[str]]:
    import joblib

    mp, fp = default_model_paths()
    mp = model_path or mp
    fp = features_path or fp
    model = joblib.load(mp)
    names: list[str] = list(joblib.load(fp))
    return model, names

def raw_model_phishing_probability(
    url: str,
    model: Any,
    feature_names: Sequence[str],
) -> float:
    """XGBoost score only (no allowlist). For debugging / ablations."""
    x = feature_vector(url, feature_names)
    return float(model.predict_proba(x)[0, 1])

def phishing_probability(
    url: str,
    model: Any,
    feature_names: Sequence[str],
    *,
    apply_trusted_domain_cap: bool = True,
) -> float:
    """
    Phishing probability in [0, 1]. By default, known bank domains return 0.0
    regardless of the classifier (see module docstring).
    """
    raw = raw_model_phishing_probability(url, model, feature_names)
    if apply_trusted_domain_cap and is_trusted_bank_url(url):
        return 0.0
    return raw
