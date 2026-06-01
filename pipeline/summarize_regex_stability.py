from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = PROJECT_ROOT / "out"


def load_csv(path: Path) -> pd.DataFrame:
    if not path.exists():
        return pd.DataFrame()
    return pd.read_csv(path, encoding="utf-8")


def ratio(series: pd.Series) -> float:
    if len(series) == 0:
        return 0.0
    return float(series.mean())


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Summarize regex category stability from audit and match-audit CSVs."
    )
    parser.add_argument("--out-dir", type=Path, default=OUT_DIR)
    args = parser.parse_args()

    audit = load_csv(args.out_dir / "yaml_regex_audit.csv")
    category_static = load_csv(args.out_dir / "yaml_regex_category_summary.csv")
    match_summary = load_csv(args.out_dir / "yaml_regex_match_summary.csv")

    if audit.empty or category_static.empty:
        raise SystemExit(
            "Missing audit CSVs. Run: python -m pipeline.audit_yaml_regex"
        )

    pattern_audit = audit[audit["kind"] == "pattern"].copy()

    rows = []
    for (file_name, category), cat_rows in category_static.groupby(["file", "category"], dropna=False):
        audit_rows = pattern_audit[
            (pattern_audit["file"] == file_name)
            & (pattern_audit["category"] == category)
        ]
        match_rows = pd.DataFrame()
        if not match_summary.empty:
            match_rows = match_summary[
                (match_summary["file"] == file_name)
                & (match_summary["category"] == category)
            ]

        patterns = int(cat_rows["patterns"].sum())
        compile_errors = int(cat_rows["compile_errors"].sum())
        empty_match_patterns = int(cat_rows["empty_match_patterns"].sum())
        broad_static = int(cat_rows["broad_patterns"].sum())
        no_boundary = int(cat_rows["patterns_without_word_boundary"].sum())
        duplicate_rows = int(cat_rows["duplicate_rows"].sum())

        static_risk_score = (
            compile_errors * 10
            + empty_match_patterns * 8
            + broad_static * 3
            + no_boundary * 2
            + duplicate_rows
        )

        match_risk_score = 0.0
        matched_text_ratio_mean = None
        matched_text_ratio_max = None
        total_kept_matches = None
        dead_patterns = None
        broad_patterns = None
        timeout_patterns = None
        sparse_patterns = None

        if not match_rows.empty:
            matched_text_ratio_mean = ratio(match_rows["kept_text_ratio"])
            matched_text_ratio_max = float(match_rows["kept_text_ratio"].max())
            total_kept_matches = int(match_rows["kept_matches"].sum())
            dead_patterns = int((match_rows["quality_flag"] == "dead_no_matches").sum())
            broad_patterns = int(match_rows["quality_flag"].isin(["broad_review", "too_broad_review"]).sum())
            timeout_patterns = int((match_rows["quality_flag"] == "timeout_risk").sum())
            sparse_patterns = int((match_rows["quality_flag"] == "very_sparse_review").sum())
            match_risk_score = (
                timeout_patterns * 8
                + broad_patterns * 5
                + dead_patterns * 2
                + sparse_patterns
            )

        if compile_errors:
            status = "broken"
        elif match_rows.empty:
            status = "needs_match_audit"
        elif timeout_patterns:
            status = "timeout_review"
        elif broad_patterns:
            status = "broad_review"
        elif dead_patterns and dead_patterns == patterns:
            status = "dead_category_review"
        elif sparse_patterns and total_kept_matches is not None and total_kept_matches <= 2:
            status = "sparse_review"
        elif static_risk_score or match_risk_score:
            status = "review"
        else:
            status = "stable_candidate"

        rows.append(
            {
                "file": file_name,
                "category": category,
                "status": status,
                "patterns": patterns,
                "compile_errors": compile_errors,
                "empty_match_patterns": empty_match_patterns,
                "broad_static_patterns": broad_static,
                "patterns_without_word_boundary": no_boundary,
                "duplicate_rows": duplicate_rows,
                "matched_text_ratio_mean": matched_text_ratio_mean,
                "matched_text_ratio_max": matched_text_ratio_max,
                "total_kept_matches": total_kept_matches,
                "dead_patterns": dead_patterns,
                "broad_match_patterns": broad_patterns,
                "timeout_patterns": timeout_patterns,
                "sparse_patterns": sparse_patterns,
                "static_risk_score": static_risk_score,
                "match_risk_score": match_risk_score,
                "risk_score": static_risk_score + match_risk_score,
            }
        )

    report = pd.DataFrame(rows).sort_values(
        ["risk_score", "status", "category"], ascending=[False, True, True]
    )
    out_path = args.out_dir / "yaml_regex_stability_report.csv"
    report.to_csv(out_path, index=False, encoding="utf-8")

    print(f"stability report: {out_path}")
    print(f"categories: {len(report)}")
    print(report["status"].value_counts(dropna=False).to_string())
    print("\nTop review candidates:")
    cols = ["category", "status", "patterns", "risk_score", "matched_text_ratio_max", "total_kept_matches"]
    print(report[cols].head(20).to_string(index=False))


if __name__ == "__main__":
    main()
