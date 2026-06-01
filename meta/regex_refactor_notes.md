# Regex Refactor Notes

Scope: conservative regex/codebook audit before PCA preparation. No categories were created or split. Notes below mark only syntactic/logical regex issues or strong category-signal distortions identified during the audit.

| Kategorie | Problem-Ausdruck/Pattern | Minimaler pragmatischer Fix |
|---|---|---|
| affective_deflection | `\bigutanlage\s+für\s+deinen\s+hinweis\b` | Tippfehler korrigieren oder streichen |
| expressive_para_noise | `[!?]4,}` | Zu `[!?]{4,}` korrigieren |
| vulgar_speech | `\bhur[e\|en\|er\|erei\|ig]*\b` | Zeichenklasse zu Alternation umbauen: `\bhur(?:e|en|er|erei|ig)\b` |
| vulgar_speech | `\b(?i)musch(i\|is\|ia)\b` | Inline-Flag an den Anfang setzen: `(?i)\bmusch(?:i|is|ia)\b` |
| regulation_request | `\bbitte\s+(\|formuliere\|erklär\|sag)\s+es\s+(klar\|deutlich\|direkt)\b` | Leere Alternative entfernen |
| mortality_ritual_forensic | `\brisiko(s\|)\b` | Zu `\brisikos?\b` korrigieren |
| temporality_structural_process | mehrere `(?:...|)`-Formen | Leere Alternativen durch optionale Gruppen ersetzen |
| temporality_subjective_disturbed | `\beingefroren(?:e[rnm]?\|)\b` | Leere Alternative durch optionale Gruppe ersetzen |
| agental_tech_hybris | `\bapi\b`, `\bcurl\b`, `\bjson\b`, `\bport\s+[0-9]+\b` | In technische Kategorien verschieben oder streichen |
| aggressive_structure | `^[A-ZÄÖÜ][a-zäöü]+!\s*$` | Zu breit; streichen |
| llm_mechanical_reflexes | `—` | Zu breit; streichen |
| science_fiction | `\bcis\b`, `\bsw\b` | Zu breit; streichen |
| intensity_sexualized_contact | `\bumarmt\b` | In Körperkontakt-Kategorie verschieben oder streichen |
| nature_metaphorical_ideological | `alleinheit` | Vermutlichen Tippfehler zu `einsamkeit` oder `alleinsein` korrigieren |
