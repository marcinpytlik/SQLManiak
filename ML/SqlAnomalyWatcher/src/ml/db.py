from __future__ import annotations

from sqlalchemy import create_engine
from src.config import DB_SERVER, DB_DATABASE, DB_DRIVER, DB_TRUSTED_CONNECTION


def get_connection_string() -> str:
    return (
        f"mssql+pyodbc://@{DB_SERVER}/{DB_DATABASE}"
        f"?driver={DB_DRIVER.replace(' ', '+')}"
        f"&trusted_connection={DB_TRUSTED_CONNECTION}"
    )


def get_engine():
    return create_engine(get_connection_string())