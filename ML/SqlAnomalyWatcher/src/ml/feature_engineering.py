from __future__ import annotations

import numpy as np
import pandas as pd


def add_time_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    df["CaptureTime"] = pd.to_datetime(df["CaptureTime"])
    df = df.sort_values("CaptureTime").reset_index(drop=True)

    df["hour"] = df["CaptureTime"].dt.hour
    df["day_of_week"] = df["CaptureTime"].dt.dayofweek
    df["is_weekend"] = df["day_of_week"].isin([5, 6]).astype(int)

    return df


def add_diff_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    diff_cols = [
        "CpuPercent",
        "BatchRequestsPerSec",
        "UserConnections",
        "BlockedSessions",
        "DeadlocksPerMin",
        "AvgQueryDurationMs",
        "AvgLogicalReads",
        "TempdbUsedMb",
        "SignalWaitTimeMs",
        "PageLifeExpectancy",
    ]

    for col in diff_cols:
        df[f"{col}_diff"] = df[col].diff()

    return df


def add_rolling_features(df: pd.DataFrame, window: int = 3) -> pd.DataFrame:
    df = df.copy()

    rolling_cols = [
        "CpuPercent",
        "BatchRequestsPerSec",
        "AvgQueryDurationMs",
        "AvgLogicalReads",
        "TempdbUsedMb",
        "SignalWaitTimeMs",
        "PageLifeExpectancy",
    ]

    for col in rolling_cols:
        df[f"{col}_rolling_mean_{window}"] = df[col].rolling(window=window).mean()
        df[f"{col}_rolling_std_{window}"] = df[col].rolling(window=window).std()

    return df


def add_ratio_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    df["duration_per_batch"] = np.where(
        df["BatchRequestsPerSec"] > 0,
        df["AvgQueryDurationMs"] / df["BatchRequestsPerSec"],
        0,
    )

    df["reads_per_batch"] = np.where(
        df["BatchRequestsPerSec"] > 0,
        df["AvgLogicalReads"] / df["BatchRequestsPerSec"],
        0,
    )

    df["signal_wait_per_connection"] = np.where(
        df["UserConnections"] > 0,
        df["SignalWaitTimeMs"] / df["UserConnections"],
        0,
    )

    return df


def clean_feature_frame(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    df = df.replace([np.inf, -np.inf], np.nan)
    df = df.dropna().reset_index(drop=True)
    return df


def build_feature_frame(df: pd.DataFrame) -> pd.DataFrame:
    df = add_time_features(df)
    df = add_diff_features(df)
    df = add_rolling_features(df, window=3)
    df = add_ratio_features(df)
    df = clean_feature_frame(df)
    return df