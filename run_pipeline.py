from datetime import timedelta
from pathlib import Path
import sys
from time import perf_counter


RUNNER_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = (
    RUNNER_DIR / "core-analytics"
    if (RUNNER_DIR / "core-analytics").is_dir()
    else RUNNER_DIR
)
sys.path.insert(0, str(PROJECT_ROOT))

from config.config import OUT_DIR
from pipeline.extract_categories import run as run_extract
from pipeline.merge_with_style import run as run_merge
from pipeline.pca_kmeans import run as run_cluster


STAGES = [
    ("Kategorien extrahieren", run_extract),
    ("Stilmerkmale mergen", run_merge),
    ("PCA + Clustering", run_cluster),
]


def format_duration(seconds: float) -> str:
    duration = timedelta(seconds=seconds)
    whole_seconds = int(duration.total_seconds())
    hours, remainder = divmod(whole_seconds, 3600)
    minutes, seconds_part = divmod(remainder, 60)
    tenths = int((seconds - int(seconds)) * 10)
    return f"{hours}:{minutes:02d}:{seconds_part:02d}.{tenths}"


def main():
    OUT_DIR.mkdir(exist_ok=True)
    pipeline_start = perf_counter()
    stage_times = []

    print("\n" + "=" * 50)
    print("   MILO.ONE PIPELINE STARTET")
    print("=" * 50 + "\n")

    for index, (name, stage) in enumerate(STAGES, start=1):
        print(f"[{index}/{len(STAGES)}] {name}...")
        stage_start = perf_counter()
        stage()
        stage_seconds = perf_counter() - stage_start
        stage_times.append((name, stage_seconds))
        print(f"[BENCH] {name}: {format_duration(stage_seconds)}")

    total_seconds = perf_counter() - pipeline_start

    print("\n" + "=" * 50)
    print("   PIPELINE ERFOLGREICH ABGESCHLOSSEN")
    print("=" * 50)
    for name, seconds in stage_times:
        print(f"{name:28} | {format_duration(seconds)}")
    print("-" * 50)
    print(f"{'PIPELINE GESAMTZEIT':28} | {format_duration(total_seconds)}")
    print(f"Ergebnisse liegen in: {OUT_DIR}")


if __name__ == "__main__":
    main()
