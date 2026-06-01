from __future__ import annotations

import argparse
import re
from pathlib import Path


COMMON_OCR_FIXES = {
    "Ciinicai": "Clinical",
    "ciinicai": "clinical",
    "Ciinical": "Clinical",
    "ciinical": "clinical",
    "Functionai": "Functional",
    "functionai": "functional",
    "Differentiai": "Differential",
    "differentiai": "differential",
    "Deveiopment": "Development",
    "deveiopment": "development",
    "Reiated": "Related",
    "reiated": "related",
    "iViaricers": "Markers",
    "iviaricers": "markers",
    "Intaice": "Intake",
    "intaice": "intake",
    "tlie": "the",
    "Tlie": "The",
    "tfie": "the",
    "Tfie": "The",
    "tiie": "the",
    "Tiie": "The",
    "ciiaracteristics": "characteristics",
    "Ciiaracteristics": "Characteristics",
    "intal<e": "intake",
    "Intal<e": "Intake",
    "weigfit": "weight",
    "Weigfit": "Weight",
    "regur gitation": "regurgitation",
    "conse quences": "consequences",
    "avoid ance": "avoidance",
    "occur rence": "occurrence",
    "frinctional": "functional",
    "Frinctional": "Functional",
}


HEADING_MARKERS = [
    "Diagnostic Criteria",
    "Diagnostic Features",
    "Associated Features Supporting Diagnosis",
    "Prevalence",
    "Development and Course",
    "Risk and Prognostic Factors",
    "Culture-Related Diagnostic Issues",
    "Gender-Related Diagnostic Issues",
    "Diagnostic Markers",
    "Functional Consequences",
    "Differential Diagnosis",
    "Comorbidity",
    "Specify if:",
    "Specify whether:",
    "Coding note:",
    "Note:",
    "Bitte angeben, ob:",
    "Aktuellen Schweregrad angeben:",
    "Hinweis:",
]


def collapse_spaced_letters(match: re.Match[str]) -> str:
    return re.sub(r"\s+", "", match.group(0))


def normalize_text(text: str) -> str:
    text = text.replace("\ufeff", "")
    text = text.replace("\xa0", " ")
    text = text.replace("\u2011", "-")
    text = text.replace("\u2010", "-")
    text = text.replace("\u2013", "-")
    text = text.replace("\u2014", " - ")

    # PDF extraction often leaves soft hyphens plus a following layout space.
    text = re.sub(r"(?<=[A-Za-zÄÖÜäöüß])\u00ad\s*(?=[A-Za-zÄÖÜäöüß])", "", text)
    text = text.replace("\u00ad", "")

    # Join artifacts such as "T h is   d i s c u s s i o n" in headings.
    text = re.sub(
        r"(?<![A-Za-zÄÖÜäöüß])(?:[A-Za-zÄÖÜäöüß]\s+){3,}[A-Za-zÄÖÜäöüß](?![A-Za-zÄÖÜäöüß])",
        collapse_spaced_letters,
        text,
    )

    for wrong, right in COMMON_OCR_FIXES.items():
        text = re.sub(rf"\b{re.escape(wrong)}\b", right, text)

    text = re.sub(r"\bT\s+h\s+is\b", "This", text)
    text = re.sub(r"\bt\s+h\s+is\b", "this", text)
    text = re.sub(r"\bo\s+th\s+e\s+r\b", "other", text)
    text = re.sub(r"\bO\s+th\s+e\s+r\b", "Other", text)
    text = re.sub(r"\bcondi-\s+tiens\b", "conditions", text)
    text = re.sub(r"\bo\^\s+diarrhea\b", "or diarrhea", text)
    text = re.sub(r"\bThe berea>\s+", "The bereaved ", text)

    # Normalize layout spaces but keep paragraph boundaries.
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s+\n", "\n", text)
    text = re.sub(r"\n\s+", "\n", text)

    for marker in HEADING_MARKERS:
        text = re.sub(rf"(?<!\n)\s+({re.escape(marker)})", rf"\n\n\1", text)

    # Put ICD/code-like entries and enumerated criteria on their own lines.
    text = re.sub(r"(?<!\n)\s+(\d{3}\.\d{1,2}\s+\([A-Z][0-9][0-9A-Z.]*\))", r"\n\1", text)
    text = re.sub(r"(?<!\n)\s+([A-Z]\.\s+(?=[A-ZÄÖÜ]))", r"\n\n\1", text)
    text = re.sub(r"(?<!\n)\s+(\d+\.\s+(?=[A-ZÄÖÜ]))", r"\n\1", text)

    # Add paragraph breaks after sentence ends when the next token looks like a heading.
    text = re.sub(
        r"([.!?])\s+((?:[A-ZÄÖÜ][A-Za-zÄÖÜäöüß/\-]+(?:\s+|$)){2,6})(?=\n|[A-ZÄÖÜ])",
        lambda m: m.group(1) + "\n\n" + m.group(2).strip() + " ",
        text,
    )

    # Reflow very long physical lines into readable paragraph lines.
    paragraphs = [p.strip() for p in re.split(r"\n{2,}", text) if p.strip()]
    wrapped: list[str] = []
    for paragraph in paragraphs:
        paragraph = re.sub(r"\s+", " ", paragraph).strip()
        if len(paragraph) <= 900:
            wrapped.append(paragraph)
            continue

        sentences = re.split(r"(?<=[.!?])\s+(?=[A-ZÄÖÜ0-9\"(])", paragraph)
        buf = ""
        for sentence in sentences:
            sentence = sentence.strip()
            if not sentence:
                continue
            if len(buf) + len(sentence) + 1 > 900 and buf:
                wrapped.append(buf.strip())
                buf = sentence
            else:
                buf = f"{buf} {sentence}".strip()
        if buf:
            wrapped.append(buf.strip())

    text = "\n\n".join(wrapped)
    text = re.sub(r"\n{3,}", "\n\n", text).strip() + "\n"
    return text


def main() -> None:
    parser = argparse.ArgumentParser(description="Conservatively clean noisy extracted text in-place.")
    parser.add_argument("path", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    original = args.path.read_text(encoding="utf-8", errors="ignore")
    cleaned = normalize_text(original)

    print(f"file: {args.path}")
    print(f"chars_before: {len(original)}")
    print(f"chars_after: {len(cleaned)}")
    print(f"lines_before: {len(original.splitlines())}")
    print(f"lines_after: {len(cleaned.splitlines())}")

    if not args.dry_run:
        args.path.write_text(cleaned, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
