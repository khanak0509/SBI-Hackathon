"""
Integration-style tests for saved URL and APK XGBoost models.

Run from repo root:
  cd SBI-Hackathon/backend && python -m pytest tests/test_kavach_ml_models.py -v

Requires: joblib, numpy, pandas, scikit-learn, xgboost, tldextract
Optional real APK: export KAVACH_TEST_APK=/path/to/file.apk
"""
from __future__ import annotations

import os
from pathlib import Path

import numpy as np
import pandas as pd
import pytest
from sklearn.metrics import accuracy_score, roc_auc_score

BACKEND = Path(__file__).resolve().parents[1]
URL_DATA = BACKEND / "url_ml_model" / "data"
APK_DATA = BACKEND / "apk_ml_model" / "data"


@pytest.fixture(scope="module")
def url_bundle():
    pytest.importorskip("tldextract", reason="pip install tldextract (URL features)")
    from url_ml_model import url_runtime

    mp = URL_DATA / "url_model.pkl"
    fp = URL_DATA / "feature_names.pkl"
    if not mp.is_file() or not fp.is_file():
        pytest.skip(f"Missing URL artifacts: {mp} or {fp}")
    model, names = url_runtime.load_url_artifacts(str(mp), str(fp))
    return url_runtime, model, names


@pytest.fixture(scope="module")
def apk_bundle():
    from apk_ml_model import apk_runtime

    mp = APK_DATA / "apk_model.pkl"
    fp = APK_DATA / "apk_feature_names.pkl"
    if not mp.is_file() or not fp.is_file():
        pytest.skip(f"Missing APK artifacts: {mp} or {fp}")
    model, names = apk_runtime.load_apk_artifacts(str(mp), str(fp))
    return apk_runtime, model, names


class TestUrlModel:
    def test_artifact_contract(self, url_bundle):
        url_runtime, model, names = url_bundle
        assert len(names) == len(url_runtime.FEATURE_NAMES)
        assert model.n_features_in_ == len(names)

    def test_proba_shape_and_range(self, url_bundle):
        url_runtime, model, names = url_bundle
        x = url_runtime.feature_vector(
            "https://www.onlinesbi.sbi/", feature_names=names
        )
        p = model.predict_proba(x)[0]
        assert p.shape == (2,)
        assert 0 <= float(p[1]) <= 1

    def test_trusted_sbi_domains_return_safe_score(self, url_bundle):
        """Official allowlisted bank hosts must not be flagged (model can FP otherwise)."""
        url_runtime, model, names = url_bundle
        for u in ("https://www.onlinesbi.sbi/", "https://sbicard.com/"):
            assert url_runtime.is_trusted_bank_url(u)
            assert url_runtime.phishing_probability(u, model, names) == 0.0

    def test_curated_urls_rank_correctly(self, url_bundle):
        """Phishing-style URLs should score higher than known-good retail/bank URLs."""
        url_runtime, model, names = url_bundle
        bad = [
            "http://sbi-kyc-update.xyz/login?id=1",
            "https://paypa1-verify.example.com/signin",
            "http://192.168.1.1/fake-sbi-yono.apk",
        ]
        good = [
            "https://www.onlinesbi.sbi/",
            "https://www.google.com/",
            "https://www.wikipedia.org/wiki/State_Bank_of_India",
        ]
        bad_probs = [url_runtime.phishing_probability(u, model, names) for u in bad]
        good_probs = [url_runtime.phishing_probability(u, model, names) for u in good]
        assert np.mean(bad_probs) > np.mean(good_probs) + 0.05

    def test_sample_from_training_csv(self, url_bundle):
        """Stratified rows from the same CSV family should separate on average."""
        csv_path = URL_DATA / "phishing_site_urls.csv"
        if not csv_path.is_file():
            pytest.skip("phishing_site_urls.csv not present")
        url_runtime, model, names = url_bundle
        # First rows are often all phishing; stream chunks until both classes appear.
        parts: list[pd.DataFrame] = []
        for chunk in pd.read_csv(
            csv_path, usecols=["URL", "Label"], chunksize=50_000
        ):
            chunk = chunk.copy()
            chunk["y"] = chunk["Label"].apply(
                lambda x: 1
                if str(x).strip().lower() in ("bad", "phishing", "1", "malicious")
                else 0
            )
            parts.append(chunk)
            cat = pd.concat(parts, ignore_index=True)
            if (cat["y"] == 0).sum() >= 200 and (cat["y"] == 1).sum() >= 200:
                break
        else:
            pytest.skip("Could not find enough mixed labels when scanning CSV")
        df0 = pd.concat(parts, ignore_index=True)
        from sklearn.model_selection import train_test_split

        n = min(2000, len(df0))
        df0, _ = train_test_split(df0, train_size=n, stratify=df0["y"], random_state=0)
        df, _ = train_test_split(
            df0, train_size=min(800, len(df0)), stratify=df0["y"], random_state=1
        )
        probs = []
        for u in df["URL"].astype(str):
            probs.append(url_runtime.phishing_probability(u, model, names))
        auc = roc_auc_score(df["y"].values, np.array(probs))
        assert auc >= 0.75, f"ROC-AUC on CSV sample too low: {auc:.3f}"


class TestApkModel:
    def test_artifact_contract(self, apk_bundle):
        apk_runtime, model, names = apk_bundle
        assert names == apk_runtime.APK_FEATURE_NAMES
        assert model.n_features_in_ == len(apk_runtime.APK_FEATURE_NAMES)

    def test_drebin_sample_separation(self, apk_bundle):
        """Saved model should rank Drebin-derived malware rows above benign on average."""
        drebin_csv = APK_DATA / "drebin-215-dataset-5560malware-9476-benign.csv"
        cat_csv = APK_DATA / "dataset-features-categories.csv"
        if not drebin_csv.is_file() or not cat_csv.is_file():
            pytest.skip("Drebin data files not present")
        apk_runtime, model, names = apk_bundle
        X, y = apk_runtime.build_apk_matrix_from_drebin(
            str(drebin_csv), str(cat_csv)
        )
        # Subset for speed; indices fixed for reproducibility
        idx = np.arange(0, len(y), max(1, len(y) // 3000))[:3000]
        Xs, ys = X[idx], y[idx]
        probs = model.predict_proba(Xs)[:, 1]
        m = probs[ys == 1]
        b = probs[ys == 0]
        assert len(m) and len(b)
        assert float(np.mean(m)) > float(np.mean(b)) + 0.05

    def test_drebin_holdout_auc(self, apk_bundle):
        drebin_csv = APK_DATA / "drebin-215-dataset-5560malware-9476-benign.csv"
        cat_csv = APK_DATA / "dataset-features-categories.csv"
        if not drebin_csv.is_file() or not cat_csv.is_file():
            pytest.skip("Drebin data files not present")
        apk_runtime, model, names = apk_bundle
        X, y = apk_runtime.build_apk_matrix_from_drebin(
            str(drebin_csv), str(cat_csv)
        )
        from sklearn.model_selection import train_test_split

        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, stratify=y, random_state=42
        )
        # Model was trained on same distribution; sanity-check it still discriminates
        y_prob = model.predict_proba(X_test)[:, 1]
        auc = roc_auc_score(y_test, y_prob)
        acc = accuracy_score(y_test, model.predict(X_test))
        assert auc >= 0.90, f"Holdout ROC-AUC unexpectedly low: {auc:.3f}"
        assert acc >= 0.85, f"Holdout accuracy unexpectedly low: {acc:.3f}"

    def test_optional_real_apk(self, apk_bundle):
        path = os.environ.get("KAVACH_TEST_APK")
        if not path or not os.path.isfile(path):
            pytest.skip("Set KAVACH_TEST_APK to a real .apk for this test")
        apk_runtime, model, names = apk_bundle
        feats = apk_runtime.extract_apk_features(path)
        assert isinstance(feats.get("package_name", ""), str)
        prob = apk_runtime.malware_probability(feats, model, names)
        assert 0 <= prob <= 1


class TestImpersonationRule:
    def test_rule_logic(self):
        from apk_ml_model.apk_runtime import (
            OFFICIAL_SBI_CERT_SHA256,
            is_impersonating_sbi,
        )

        assert is_impersonating_sbi(
            {"package_name_sbi_similarity": 0.9, "cert_sha256": "aa"}
        )
        assert not is_impersonating_sbi(
            {
                "package_name_sbi_similarity": 1.0,
                "cert_sha256": OFFICIAL_SBI_CERT_SHA256,
            }
        )
