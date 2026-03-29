from __future__ import annotations

from pathlib import Path

import pandas as pd
from sqlalchemy import text

from src.config import OUTPUT_DIR
from src.ml.db import get_engine


def print_section(title: str) -> None:
    print("\n" + "=" * 80)
    print(title)
    print("=" * 80)


def load_explained_data(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"Nie znaleziono pliku: {csv_path}")
    return pd.read_csv(csv_path, parse_dates=["CaptureTime"])


def normalize_nullable_text(value):
    if pd.isna(value):
        return None
    text_value = str(value).strip()
    return text_value if text_value else None


def main() -> None:
    input_path = OUTPUT_DIR / "anomaly_explained_features.csv"

    print_section("1. ODCZYT DANYCH Z CSV")
    df = load_explained_data(input_path)
    print(df.head())
    print(f"\nLiczba rekordów wejściowych: {len(df)}")

    print_section("2. PRZYGOTOWANIE MODELRUN")
    model_name = "IsolationForest_v1_with_explanations"
    parameters_json = '{"contamination": 0.10, "n_estimators": 300, "explanations": true}'

    engine = get_engine()

    with engine.begin() as conn:
        model_run_insert = text("""
            INSERT INTO dbo.ModelRun
            (
                RunStartedAt,
                RunFinishedAt,
                RowsProcessed,
                ModelName,
                ParametersJson,
                Status,
                Notes
            )
            OUTPUT INSERTED.Id
            VALUES
            (
                SYSDATETIME(),
                SYSDATETIME(),
                :RowsProcessed,
                :ModelName,
                :ParametersJson,
                :Status,
                :Notes
            );
        """)

        model_run_id = conn.execute(
            model_run_insert,
            {
                "RowsProcessed": int(len(df)),
                "ModelName": model_name,
                "ParametersJson": parameters_json,
                "Status": "Completed",
                "Notes": "Pierwszy zapis scoringu anomalii do SQL Server",
            },
        ).scalar_one()

        print(f"Utworzono ModelRunId = {model_run_id}")

        print_section("3. INSERT DO dbo.AnomalyScore")

        insert_stmt = text("""
            INSERT INTO dbo.AnomalyScore
            (
                ModelRunId,
                TelemetrySnapshotId,
                CaptureTime,
                AnomalyFlag,
                AnomalyScore,
                KnownIncident,
                TopReason,
                TopReason1,
                TopReason2,
                TopReason3
            )
            VALUES
            (
                :ModelRunId,
                :TelemetrySnapshotId,
                :CaptureTime,
                :AnomalyFlag,
                :AnomalyScore,
                :KnownIncident,
                :TopReason,
                :TopReason1,
                :TopReason2,
                :TopReason3
            );
        """)

        inserted_count = 0

        for _, row in df.iterrows():
            top_reason_1 = normalize_nullable_text(row.get("TopReason1"))
            top_reason_2 = normalize_nullable_text(row.get("TopReason2"))
            top_reason_3 = normalize_nullable_text(row.get("TopReason3"))

            # Dla zgodności ze starą kolumną TopReason zapisujemy TopReason1
            top_reason_legacy = top_reason_1

            conn.execute(
                insert_stmt,
                {
                    "ModelRunId": model_run_id,
                    "TelemetrySnapshotId": int(row["Id"]),
                    "CaptureTime": row["CaptureTime"],
                    "AnomalyFlag": int(row["AnomalyFlag"]),
                    "AnomalyScore": float(row["AnomalyScore"]),
                    "KnownIncident": None,
                    "TopReason": top_reason_legacy,
                    "TopReason1": top_reason_1,
                    "TopReason2": top_reason_2,
                    "TopReason3": top_reason_3,
                },
            )
            inserted_count += 1

    print_section("4. ZAKOŃCZENIE")
    print(f"Zapisano {inserted_count} rekordów do dbo.AnomalyScore.")
    print("Write-back do SQL Server zakończony poprawnie.")


if __name__ == "__main__":
    main()