from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

OUTPUT_DIR = BASE_DIR / "output"
SQL_DIR = BASE_DIR / "sql"

DB_SERVER = "syriusz"
DB_DATABASE = "SqlAnomalyWatcherDb"
DB_DRIVER = "ODBC Driver 17 for SQL Server"

DB_TRUSTED_CONNECTION = "yes"