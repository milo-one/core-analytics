from __future__ import annotations

import argparse
import csv
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import regex as re
import yaml


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CONFIG_DIR = PROJECT_ROOT / "config"
DATA_RAW = PROJECT_ROOT / "data_raw"
OUT_DIR = PROJECT_ROOT / "out"

PATTERN_KEYS = {"pattern", "patterns", "regex"}
EXCLUSION_KEYS = {"exclusion", "exclusions", "exclude"}
META_KEYS = {
    "description",
    "weight",
    "metric_features",
    "components",
    "examples",
    "notes",
}


@dataclass
class PatternRecord:
    file: str
    category: str
    yaml_path: str
    pattern: str
    kind: str = "pattern"


def discover_yaml_files(config_dir: Path) -> list[Path]:
    ignored = {"config.yaml", "config.yml"}
    return [
        path
        for path in sorted(config_dir.glob("*.y*ml"), key=lambda p: p.name.lower())
        if path.name.lower() not in ignored
    ]


def normalize_pattern(pattern: str) -> str:
    return re.sub(r"\s+", "", pattern.strip()).lower()


def looks_broad(pattern: str) -> bool:
    broad_markers = [".*", ".+", ".{0,", ".{1,", "[\\s\\S]*", "(?s).*"]
    return any(marker in pattern for marker in broad_markers)


def has_word_boundary(pattern: str) -> bool:
    return r"\b" in pattern or r"(?<!\w)" in pattern or r"(?!\w)" in pattern


def add_pattern(
    records: list[PatternRecord],
    file_name: str,
    category: str,
    yaml_path: str,
    value: Any,
    kind: str = "pattern",
) -> None:
    if isinstance(value, str):
        records.append(
            PatternRecord(
                file=file_name,
                category=category,
                yaml_path=yaml_path,
                pattern=value,
                kind=kind,
            )
        )
    elif isinstance(value, list):
        for idx, item in enumerate(value):
            add_pattern(records, file_name, category, f"{yaml_path}[{idx}]", item, kind)


def extract_records_from_yaml(path: Path) -> tuple[list[PatternRecord], list[dict[str, str]]]:
    warnings: list[dict[str, str]] = []
    records: list[PatternRecord] = []

    try:
        with path.open(encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}
    except Exception as exc:
        warnings.append({"file": path.name, "level": "error", "message": f"YAML parse error: {exc}"})
        return records, warnings

    if isinstance(data, list):
        add_pattern(records, path.name, path.stem, "$", data)
        return records, warnings

    if not isinstance(data, dict):
        warnings.append({"file": path.name, "level": "warning", "message": "Top-level YAML is neither dict nor list"})
        return records, warnings

    def walk(node: Any, current_category: str, yaml_path: str) -> None:
        if isinstance(node, list):
            add_pattern(records, path.name, current_category, yaml_path, node)
            return

        if not isinstance(node, dict):
            return

        for key, value in node.items():
            key_text = str(key)
            key_lower = key_text.lower()
            child_path = f"{yaml_path}.{key_text}" if yaml_path else key_text

            if key_lower in PATTERN_KEYS:
                add_pattern(records, path.name, current_category, child_path, value)
                continue

            if key_lower in EXCLUSION_KEYS:
                add_pattern(records, path.name, current_category, child_path, value, kind="exclusion")
                continue

            if key_lower in META_KEYS:
                continue

            next_category = key_text if isinstance(value, (dict, list)) else current_category
            walk(value, next_category, child_path)

    for top_key, value in data.items():
        walk(value, str(top_key), str(top_key))

    return records, warnings


def compile_audit(records: list[PatternRecord]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    normalized_counts = Counter(normalize_pattern(r.pattern) for r in records)
    normalized_kind_counts = Counter(
        (r.kind, normalize_pattern(r.pattern)) for r in records
    )

    for idx, record in enumerate(records, start=1):
        compile_ok = True
        compile_error = ""
        empty_match = False
        group_count = 0

        try:
            compiled = re.compile(record.pattern, flags=re.IGNORECASE | re.MULTILINE)
            empty_match = compiled.search("") is not None
            group_count = compiled.groups
        except Exception as exc:
            compile_ok = False
            compile_error = str(exc)

        normalized = normalize_pattern(record.pattern)
        rows.append(
            {
                "pattern_id": idx,
                "file": record.file,
                "category": record.category,
                "kind": record.kind,
                "yaml_path": record.yaml_path,
                "pattern": record.pattern,
                "normalized_pattern": normalized,
                "compile_ok": compile_ok,
                "compile_error": compile_error,
                "empty_match": empty_match,
                "group_count": group_count,
                "char_length": len(record.pattern),
                "looks_broad": looks_broad(record.pattern),
                "has_word_boundary": has_word_boundary(record.pattern),
                "duplicate_exact_count": normalized_counts[normalized],
                "duplicate_same_kind_count": normalized_kind_counts[(record.kind, normalized)],
            }
        )

    return rows


def build_duplicate_rows(audit_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in audit_rows:
        grouped[row["normalized_pattern"]].append(row)

    duplicate_rows: list[dict[str, Any]] = []
    for normalized, rows in sorted(grouped.items(), key=lambda item: (-len(item[1]), item[0])):
        if len(rows) < 2:
            continue
        for row in rows:
            duplicate_rows.append(
                {
                    "normalized_pattern": normalized,
                    "duplicate_count": len(rows),
                    "pattern_id": row["pattern_id"],
                    "file": row["file"],
                    "category": row["category"],
                    "kind": row["kind"],
                    "yaml_path": row["yaml_path"],
                    "pattern": row["pattern"],
                }
            )
    return duplicate_rows


def build_pattern_duplicate_rows(audit_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in audit_rows:
        if row["kind"] == "pattern":
            grouped[row["normalized_pattern"]].append(row)

    duplicate_rows: list[dict[str, Any]] = []
    for normalized, rows in sorted(grouped.items(), key=lambda item: (-len(item[1]), item[0])):
        if len(rows) < 2:
            continue
        for row in rows:
            duplicate_rows.append(
                {
                    "normalized_pattern": normalized,
                    "duplicate_count": len(rows),
                    "pattern_id": row["pattern_id"],
                    "file": row["file"],
                    "category": row["category"],
                    "yaml_path": row["yaml_path"],
                    "pattern": row["pattern"],
                }
            )
    return duplicate_rows


def build_category_summary_rows(audit_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in audit_rows:
        grouped[(row["file"], row["category"])].append(row)

    summary_rows: list[dict[str, Any]] = []
    for (file_name, category), rows in sorted(grouped.items()):
        pattern_rows = [row for row in rows if row["kind"] == "pattern"]
        exclusion_rows = [row for row in rows if row["kind"] == "exclusion"]
        duplicate_rows = [row for row in rows if int(row["duplicate_same_kind_count"]) > 1]
        summary_rows.append(
            {
                "file": file_name,
                "category": category,
                "patterns": len(pattern_rows),
                "exclusions": len(exclusion_rows),
                "compile_errors": sum(1 for row in rows if not row["compile_ok"]),
                "empty_match_patterns": sum(1 for row in rows if row["empty_match"]),
                "broad_patterns": sum(1 for row in rows if row["looks_broad"]),
                "duplicate_rows": len(duplicate_rows),
                "patterns_without_word_boundary": sum(
                    1 for row in pattern_rows if not row["has_word_boundary"]
                ),
            }
        )
    return summary_rows


def load_texts(max_texts: int | None = None) -> list[tuple[str, str]]:
    rows = []
    for path in sorted(DATA_RAW.rglob("*.txt")):
        rows.append((path.stem, path.read_text(encoding="utf-8", errors="ignore")))
        if max_texts is not None and len(rows) >= max_texts:
            break
    return rows


def context_window(text: str, start: int, end: int, width: int = 120) -> str:
    left = max(0, start - width)
    right = min(len(text), end + width)
    return text[left:right].replace("\n", " ").strip()


def match_audit(
    audit_rows: list[dict[str, Any]],
    max_texts: int | None,
    sample_limit: int,
    max_patterns: int | None,
    regex_timeout: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    texts = load_texts(max_texts=max_texts)
    summary_rows: list[dict[str, Any]] = []
    sample_rows: list[dict[str, Any]] = []

    pattern_rows = [row for row in audit_rows if row["kind"] == "pattern" and row["compile_ok"]]
    exclusion_rows = [row for row in audit_rows if row["kind"] == "exclusion" and row["compile_ok"]]
    exclusions_by_category: dict[str, list[re.Pattern]] = defaultdict(list)
    for row in exclusion_rows:
        exclusions_by_category[row["category"]].append(
            re.compile(row["pattern"], flags=re.IGNORECASE | re.MULTILINE)
        )

    if max_patterns is not None:
        pattern_rows = pattern_rows[:max_patterns]

    for row in pattern_rows:
        if row["kind"] != "pattern" or not row["compile_ok"]:
            continue

        compiled = re.compile(row["pattern"], flags=re.IGNORECASE | re.MULTILINE)
        raw_matches = 0
        kept_matches = 0
        excluded_matches = 0
        raw_matched_texts = 0
        kept_matched_texts = 0
        timeout_texts = 0
        samples_for_pattern = 0
        category_exclusions = exclusions_by_category.get(row["category"], [])

        for text_id, text in texts:
            raw_text_match_count = 0
            kept_text_match_count = 0
            try:
                iterator = compiled.finditer(text, timeout=regex_timeout)
                for match in iterator:
                    raw_text_match_count += 1
                    raw_matches += 1

                    context = context_window(text, match.start(), match.end())
                    excluded = any(ex.search(context) for ex in category_exclusions)
                    if excluded:
                        excluded_matches += 1
                        continue

                    kept_text_match_count += 1
                    kept_matches += 1

                    if samples_for_pattern >= sample_limit:
                        continue

                    sample_rows.append(
                        {
                            "pattern_id": row["pattern_id"],
                            "file": row["file"],
                            "category": row["category"],
                            "text_id": text_id,
                            "match": match.group(0),
                            "context": context,
                        }
                    )
                    samples_for_pattern += 1
            except TimeoutError:
                timeout_texts += 1

            if raw_text_match_count:
                raw_matched_texts += 1
            if kept_text_match_count:
                kept_matched_texts += 1

        texts_scanned = len(texts)
        raw_text_ratio = raw_matched_texts / texts_scanned if texts_scanned else 0
        kept_text_ratio = kept_matched_texts / texts_scanned if texts_scanned else 0
        exclusion_ratio = excluded_matches / raw_matches if raw_matches else 0

        if timeout_texts:
            quality_flag = "timeout_risk"
        elif raw_matches == 0:
            quality_flag = "dead_no_matches"
        elif kept_matches == 0 and raw_matches > 0:
            quality_flag = "fully_excluded"
        elif kept_text_ratio >= 0.50:
            quality_flag = "too_broad_review"
        elif kept_text_ratio >= 0.20:
            quality_flag = "broad_review"
        elif exclusion_ratio >= 0.75:
            quality_flag = "mostly_excluded_review"
        elif kept_matches <= 2 and texts_scanned >= 25:
            quality_flag = "very_sparse_review"
        else:
            quality_flag = "working_candidate"

        summary_rows.append(
            {
                "pattern_id": row["pattern_id"],
                "file": row["file"],
                "category": row["category"],
                "pattern": row["pattern"],
                "texts_scanned": texts_scanned,
                "raw_matched_texts": raw_matched_texts,
                "kept_matched_texts": kept_matched_texts,
                "raw_matches": raw_matches,
                "kept_matches": kept_matches,
                "excluded_matches": excluded_matches,
                "timeout_texts": timeout_texts,
                "raw_text_ratio": raw_text_ratio,
                "kept_text_ratio": kept_text_ratio,
                "exclusion_ratio": exclusion_ratio,
                "quality_flag": quality_flag,
            }
        )

    return summary_rows, sample_rows


def write_csv(path: Path, rows: list[dict[str, Any]], fieldnames: list[str] | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if fieldnames is None:
        fieldnames = list(rows[0].keys()) if rows else []
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit YAML regex files without modifying them.")
    parser.add_argument("--match-texts", action="store_true", help="Also run all valid regex patterns against data_raw.")
    parser.add_argument("--max-texts", type=int, default=None, help="Limit text files for match audit.")
    parser.add_argument("--max-patterns", type=int, default=None, help="Limit patterns for match audit.")
    parser.add_argument("--sample-limit", type=int, default=3, help="Evidence samples per pattern when matching.")
    parser.add_argument("--regex-timeout", type=float, default=0.05, help="Seconds before one regex/text match attempt times out.")
    args = parser.parse_args()

    all_records: list[PatternRecord] = []
    warnings: list[dict[str, str]] = []

    yaml_files = discover_yaml_files(CONFIG_DIR)
    for path in yaml_files:
        records, file_warnings = extract_records_from_yaml(path)
        all_records.extend(records)
        warnings.extend(file_warnings)

    audit_rows = compile_audit(all_records)
    duplicate_rows = build_duplicate_rows(audit_rows)
    pattern_duplicate_rows = build_pattern_duplicate_rows(audit_rows)
    category_summary_rows = build_category_summary_rows(audit_rows)

    write_csv(OUT_DIR / "yaml_regex_audit.csv", audit_rows)
    write_csv(OUT_DIR / "yaml_regex_duplicates.csv", duplicate_rows)
    write_csv(OUT_DIR / "yaml_regex_pattern_duplicates_only.csv", pattern_duplicate_rows)
    write_csv(OUT_DIR / "yaml_regex_category_summary.csv", category_summary_rows)
    write_csv(OUT_DIR / "yaml_regex_warnings.csv", warnings, fieldnames=["file", "level", "message"])

    print("YAML regex audit")
    print(f"- YAML files: {len(yaml_files)}")
    print(f"- records: {len(audit_rows)}")
    print(f"- compile errors: {sum(1 for row in audit_rows if not row['compile_ok'])}")
    print(f"- exact/normalized duplicate rows: {len(duplicate_rows)}")
    print(f"- output: {OUT_DIR / 'yaml_regex_audit.csv'}")

    if args.match_texts:
        summary_rows, sample_rows = match_audit(
            audit_rows,
            max_texts=args.max_texts,
            sample_limit=args.sample_limit,
            max_patterns=args.max_patterns,
            regex_timeout=args.regex_timeout,
        )
        write_csv(OUT_DIR / "yaml_regex_match_summary.csv", summary_rows)
        write_csv(OUT_DIR / "yaml_regex_match_samples.csv", sample_rows)
        print(f"- match summary: {OUT_DIR / 'yaml_regex_match_summary.csv'}")
        print(f"- match samples: {OUT_DIR / 'yaml_regex_match_samples.csv'}")


if __name__ == "__main__":
    main()

# Aufruf: python audit_yaml_regex.py --match-texts --max-texts 100 --max-patterns 50