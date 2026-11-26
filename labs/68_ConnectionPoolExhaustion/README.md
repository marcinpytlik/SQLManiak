# Lab 68 — Connection Pool Exhaustion

Inspiracja: https://www.sqlserverscience.com/troubleshooting/connection-pool-exhaustion/

Wymagania: Docker Desktop, .NET 10 SDK, PowerShell, SSMS. Wyłącznie lokalny lab, konto sa, port 15468, baza tempdb, bez danych produkcyjnych.

```powershell
$env:LAB_PASSWORD = Read-Host 'Hasło SA dla labu' -MaskInput
docker compose up -d
docker compose logs -f sql
```
Po komunikacie o gotowości SQL Server przerwij śledzenie logu Ctrl+C. Następnie:

```powershell
dotnet restore
dotnet build
dotnet run --no-build -- baseline
dotnet run --no-build -- exhaustion
dotnet run --no-build -- transaction
```

W SSMS połącz się z 127.0.0.1,15468 jako sa (Trust Server Certificate tylko w labie). Uruchamiaj observe.sql podczas 30-sekundowych okien i po timeout. Każdy scenariusz działa w oddzielnym procesie. Użyj tego samego hasła przy ponownym uruchomieniu istniejącego kontenera.

Opcjonalnie w drugim terminalu, podstaw PID wypisany przez program:

```powershell
dotnet tool install --global dotnet-counters
dotnet-counters monitor --process-id <PID> --counters Microsoft.Data.SqlClient.EventSource
```

Oczekiwania (hipotezy, nie wyniki pomiarów): baseline: ponowne użycie SPID; exhaustion: 3 wypożyczone połączenia, prawdopodobnie sleeping, brak czwartego SPID, timeout około 5 s, po zwolnieniu sukces; transaction: sprawdzić, czy transakcja T-SQL przetrwa Dispose i kiedy znika. Nie zakładać zachowania starszego providera. Scenariusz transaction nie modyfikuje danych. Zapisuj UTC, SPID, liczbę sesji, aktywne requesty, transakcje, liczniki puli i czas próby.

Zakończenie: `docker compose down` oraz `Remove-Item Env:LAB_PASSWORD`. Wersja obrazu jest ruchoma; do publikacji zapisz @@VERSION i digest obrazu oraz rzeczywistą wersję SqlClient z programu. Nie używaj na produkcji.

Opcjonalny Extended Events: uruchom xe.sql przed eksperymentem, odczytaj ring_buffer według komentarza i usuń sesję po pomiarach. Zdarzenie login nie musi oznaczać nowego fizycznego połączenia; uwzględnij ponowne użycie SPID i dane DMV.
