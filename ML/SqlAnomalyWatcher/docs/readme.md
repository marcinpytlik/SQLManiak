# SqlAnomalyWatcher

Projekt do wykrywania anomalii w metrykach SQL Server.

## Stack
- Python
- SQL Server
- scikit-learn
- matplotlib
- PowerShell
- VS Code

## Cel
Zbieranie metryk telemetrycznych z SQL Server, wykrywanie anomalii i generowanie raportów.

## Etapy
- Sprint 0: struktura projektu
- Sprint 1: baza danych i schema
- Sprint 2: collector metryk
- Sprint 3: feature engineering
- Sprint 4: anomaly detection

#.\scripts\collect-loop-logged.ps1 -Iterations 360 -DelaySeconds 60
# po zebraniu wykonać
#.\.venv\Scripts\python.exe -m src.ml.prepare_features
#.\.venv\Scripts\python.exe -m src.ml.score_anomalies
#Import-Csv .\output\top_anomalies.csv | Select-Object -First 20