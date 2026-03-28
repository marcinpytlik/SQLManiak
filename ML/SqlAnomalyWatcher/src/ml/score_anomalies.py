from __future__ import annotations

from pathlib import Path

import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

from src.config import OUTPUT_DIR


FEATURE_COLUMNS = [
    "CpuPercent",
    "UserConnections",
    "BlockedSessions",
    "DeadlocksPerMin",
    "AvgQueryDurationMs",
    "AvgLogicalReads",
    "TempdbUsedMb",
    "PageLifeExpectancy",
    "CpuPercent_diff",
    "BatchRequestsPerSec_diff",
    "UserConnections_diff",
    "BlockedSessions_diff",
    "AvgQueryDurationMs_diff",
    "AvgLogicalReads_diff",
    "TempdbUsedMb_diff",
    "SignalWaitTimeMs_diff",
    "PageLifeExpectancy_diff",
    "CpuPercent_rolling_mean_3",
    "BatchRequestsPerSec_rolling_mean_3",
    "AvgQueryDurationMs_rolling_mean_3",
    "AvgLogicalReads_rolling_mean_3",
    "TempdbUsedMb_rolling_mean_3",
    "PageLifeExpectancy_rolling_mean_3",
    "duration_per_batch",
    "reads_per_batch",
    "hour",
    "day_of_week",
    "is_weekend",
]


def print_section(title: str) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def load_feature_data(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"Nie znaleziono pliku: {csv_path}")
    return pd.read_csv(csv_path, parse_dates=["CaptureTime"])


def validate_columns(df: pd.DataFrame, required_columns: list[str]) -> None:
    missing = [col for col in required_columns if col not in df.columns]
    if missing:
        raise ValueError(f"Brakuje kolumn w DataFrame: {missing}")


def build_model(contamination: float = 0.10) -> IsolationForest:
    return IsolationForest(
        n_estimators=300,
        contamination=contamination,
        random_state=42,
    )


def main() -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)

    input_path = OUTPUT_DIR / "prepared_features.csv"
    output_path = OUTPUT_DIR / "anomaly_scored_features.csv"
    top_output_path = OUTPUT_DIR / "top_anomalies.csv"

    print_section("1. ODCZYT FEATURE DATA")
    df = load_feature_data(input_path)
    print(df.head())
    print(f"\nLiczba rekordów wejściowych: {len(df)}")

    print_section("2. WALIDACJA KOLUMN")
    validate_columns(df, FEATURE_COLUMNS)
    print("Wszystkie wymagane kolumny są obecne.")

    print_section("3. WYBÓR CECH DO MODELU")
    X = df[FEATURE_COLUMNS].copy()
    print(X.head())
    print(f"\nLiczba kolumn modelowych: {len(FEATURE_COLUMNS)}")

    print_section("4. SKALOWANIE DANYCH")
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    print(f"Kształt X_scaled: {X_scaled.shape}")

    print_section("5. URUCHOMIENIE ISOLATION FOREST")
    model = build_model(contamination=0.10)
    model.fit(X_scaled)

    raw_predictions = model.predict(X_scaled)
    raw_scores = model.score_samples(X_scaled)

    df["AnomalyFlag"] = (raw_predictions == -1).astype(int)

    # Im większy wynik po odwróceniu, tym bardziej podejrzana próbka
    df["AnomalyScore"] = -raw_scores

    print("Rozkład AnomalyFlag:")
    print(df["AnomalyFlag"].value_counts())

    print_section("6. TOP ANOMALIE")
    top_anomalies = df[df["AnomalyFlag"] == 1].sort_values(
        "AnomalyScore",
        ascending=False,
    )

    preview_cols = [
        "Id",
        "CaptureTime",
        "CpuPercent",
        "UserConnections",
        "BlockedSessions",
        "AvgQueryDurationMs",
        "AvgLogicalReads",
        "TempdbUsedMb",
        "PageLifeExpectancy",
        "BatchRequestsPerSec_diff",
        "SignalWaitTimeMs_diff",
        "AnomalyFlag",
        "AnomalyScore",
    ]

    print(top_anomalies[preview_cols].head(20))

    print_section("7. ZAPIS WYNIKÓW")
    df.to_csv(output_path, index=False)
    top_anomalies.to_csv(top_output_path, index=False)

    print(f"Zapisano: {output_path}")
    print(f"Zapisano: {top_output_path}")

    print_section("8. ZAKOŃCZENIE")
    print("Pierwszy scoring anomalii zakończony poprawnie.")


if __name__ == "__main__":
    main()