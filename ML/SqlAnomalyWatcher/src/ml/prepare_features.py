from __future__ import annotations

from pathlib import Path

import pandas as pd
from sqlalchemy import text

from src.ml.db import get_engine
from src.ml.feature_engineering import build_feature_frame
from src.config import OUTPUT_DIR


READ_QUERY = """
SELECT
    Id,
    CaptureTime,
    ServerName,
    InstanceName,
    CpuPercent,
    BatchRequestsPerSec,
    UserConnections,
    BlockedSessions,
    DeadlocksPerMin,
    AvgQueryDurationMs,
    AvgLogicalReads,
    TempdbUsedMb,
    SignalWaitTimeMs,
    PageLifeExpectancy
FROM dbo.TelemetrySnapshot
ORDER BY CaptureTime;
"""


def print_section(title: str) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def main() -> None:
    engine = get_engine()

    print_section("1. ODCZYT DANYCH Z SQL SERVER")
    df = pd.read_sql(text(READ_QUERY), engine)
    print(df.head())
    print(f"\nLiczba rekordów wejściowych: {len(df)}")

    print_section("2. BUDOWA FEATURE FRAME")
    feature_df = build_feature_frame(df)

    print(feature_df.head())
    print(f"\nLiczba rekordów po feature engineering: {len(feature_df)}")
    print(f"Liczba kolumn po feature engineering: {len(feature_df.columns)}")

    print_section("3. LISTA KOLUMN")
    for col in feature_df.columns:
        print(col)

    print_section("4. PODSTAWOWE STATYSTYKI")
    print(feature_df.describe(include="all"))

    OUTPUT_DIR.mkdir(exist_ok=True)

    output_path = OUTPUT_DIR / "prepared_features.csv"
    feature_df.to_csv(output_path, index=False)

    print_section("5. ZAKOŃCZENIE")
    print(f"Zapisano plik: {output_path}")


if __name__ == "__main__":
    main()