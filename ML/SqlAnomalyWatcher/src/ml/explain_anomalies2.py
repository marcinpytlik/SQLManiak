from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from src.config import OUTPUT_DIR


# Minimalne bezwzględne odchylenie względne, żeby powód był pokazywany
MIN_ABS_DEVIATION = 0.05  # 5%

# Metryki, które chcemy tłumaczyć
CANDIDATE_METRICS = [
    "BatchRequestsPerSec",
    "AvgQueryDurationMs",
    "AvgLogicalReads",
    "TempdbUsedMb",
    "SignalWaitTimeMs",
    "PageLifeExpectancy",
]

# Opisy bardziej DBA-friendly
EXPLANATION_LABELS = {
    "BatchRequestsPerSec": "Workload / batch requests",
    "AvgQueryDurationMs": "Średni czas zapytań",
    "AvgLogicalReads": "Średnie logical reads",
    "TempdbUsedMb": "Zużycie tempdb",
    "SignalWaitTimeMs": "Wait pressure",
    "PageLifeExpectancy": "Page Life Expectancy",
}


def print_section(title: str) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def load_scored_data(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"Nie znaleziono pliku: {csv_path}")
    return pd.read_csv(csv_path, parse_dates=["CaptureTime"])


def calculate_relative_deviation(current: float, baseline: float) -> float:
    if pd.isna(current) or pd.isna(baseline):
        return np.nan

    if abs(baseline) < 1e-9:
        if abs(current) < 1e-9:
            return 0.0
        return 9999.0

    return (current - baseline) / abs(baseline)


def build_reason_text(metric_name: str, deviation: float) -> str:
    label = EXPLANATION_LABELS.get(metric_name, metric_name)
    percent = deviation * 100.0

    if percent > 0:
        return f"{label} wyższe od lokalnej normy (+{percent:.1f}%)"
    return f"{label} niższe od lokalnej normy ({percent:.1f}%)"


def explain_single_row(row: pd.Series) -> tuple[str, str, str]:
    candidates: list[tuple[str, float]] = []

    for metric in CANDIDATE_METRICS:
        rolling_col = f"{metric}_rolling_mean_3"

        if metric not in row.index or rolling_col not in row.index:
            continue

        current_value = row[metric]
        baseline_value = row[rolling_col]

        deviation = calculate_relative_deviation(current_value, baseline_value)

        if pd.isna(deviation):
            continue

        if abs(deviation) < MIN_ABS_DEVIATION:
            continue

        candidates.append((metric, deviation))

    if not candidates:
        return (
            "Brak silnego odchylenia względem rolling mean",
            "",
            "",
        )

    candidates.sort(key=lambda x: abs(x[1]), reverse=True)

    reasons = [build_reason_text(metric, deviation) for metric, deviation in candidates[:3]]

    while len(reasons) < 3:
        reasons.append("")

    return tuple(reasons[:3])


def main() -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)

    input_path = OUTPUT_DIR / "anomaly_scored_features.csv"
    output_path = OUTPUT_DIR / "anomaly_explained_features.csv"
    top_output_path = OUTPUT_DIR / "top_anomalies_explained.csv"

    print_section("1. ODCZYT WYNIKÓW SCORINGU")
    df = load_scored_data(input_path)
    print(df.head())
    print(f"\nLiczba rekordów wejściowych: {len(df)}")

    print_section("2. FILTR ANOMALII")
    anomalies_df = df[df["AnomalyFlag"] == 1].copy()
    print(f"Liczba anomalii: {len(anomalies_df)}")

    if anomalies_df.empty:
        print("Brak anomalii do wyjaśnienia.")
        df.to_csv(output_path, index=False)
        anomalies_df.to_csv(top_output_path, index=False)
        return

    print_section("3. BUDOWA TOPREASON")
    explanations = anomalies_df.apply(explain_single_row, axis=1, result_type="expand")
    explanations.columns = ["TopReason1", "TopReason2", "TopReason3"]

    anomalies_df = pd.concat([anomalies_df, explanations], axis=1)

    print(
        anomalies_df[
            [
                "Id",
                "CaptureTime",
                "AnomalyScore",
                "TopReason1",
                "TopReason2",
                "TopReason3",
            ]
        ].head(20)
    )

    print_section("4. MERGE Z PEŁNYM ZBIOREM")
    df = df.drop(columns=["TopReason1", "TopReason2", "TopReason3"], errors="ignore")

    df = df.merge(
        anomalies_df[["Id", "TopReason1", "TopReason2", "TopReason3"]],
        on="Id",
        how="left",
    )

    print_section("5. ZAPIS WYNIKÓW")
    df.to_csv(output_path, index=False)

    anomalies_df = anomalies_df.sort_values("AnomalyScore", ascending=False)
    anomalies_df.to_csv(top_output_path, index=False)

    print(f"Zapisano: {output_path}")
    print(f"Zapisano: {top_output_path}")

    print_section("6. ZAKOŃCZENIE")
    print("Explanation engine 6.1 zakończony poprawnie.")


if __name__ == "__main__":
    main()