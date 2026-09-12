# Stage 4 - SSIS package executed from File System through SQL Agent Proxy

Cel tego etapu: potwierdzić pełny przepływ wykonawczy **SQL Agent -> SSIS Proxy -> lokalny pakiet .dtsx -> \\DC01\SSISLab$** bez użycia SSISDB i bez delegowania tożsamości konta aplikacyjnego.

## Założone nazwy POC

- serwer SQL/Agent: `SQL64`
- konto wykonawcze: `SQLLAB\poc-ssis-export`
- Credential: `POC_SSIS_Export_Credential`
- Proxy: `POC_SSIS_Export_Proxy`
- lokalny katalog pakietu na SQL64: `C:\SSIS\POC`
- package: `WriteShareTest.dtsx`
- test share: `\\DC01\SSISLab$`
- SQL Agent job: `POC_SSIS_Secure_Export_Stage4`

## Ważne

Pakiet `.dtsx` nie jest już przechowywany w repo jako ręcznie napisany XML. Taki plik może być niezgodny z konkretną wersją runtime SSIS.

Pakiet generujemy bez Visual Studio / SSDT **bezpośrednio na SQL64** przy użyciu zainstalowanego `Microsoft.SqlServer.Dts.Runtime`.

## 1. Utwórz katalog dla pakietu na SQL64

Jako administrator systemu na `SQL64`:

```powershell
New-Item -ItemType Directory -Path 'C:\SSIS\POC' -Force
```

Konto `SQLLAB\poc-ssis-export` potrzebuje tylko prawa odczytu i wykonania do katalogu/pakietu:

```powershell
icacls 'C:\SSIS\POC' /grant 'SQLLAB\poc-ssis-export:(OI)(CI)(RX)'
```

## 2. Wygeneruj poprawny pakiet przy użyciu runtime SSIS

Uruchom na `SQL64` w **Windows PowerShell 5.1 (`powershell.exe`)**, nie w PowerShell 7:

```powershell
.\13-generate-stage4-package.ps1
```

Domyślnie skrypt zapisuje:

```text
C:\SSIS\POC\WriteShareTest.dtsx
```

oraz konfiguruje zapis pliku testowego do:

```text
\\DC01\SSISLab$
```

Generator:

- lokalizuje zainstalowany `Microsoft.SqlServer.ManagedDTS.dll`,
- tworzy obiekt `Microsoft.SqlServer.Dts.Runtime.Package`,
- dodaje `STOCK:ExecuteProcessTask`,
- zapisuje pakiet przez `Application.SaveToXml`,
- natychmiast ładuje zapisany plik ponownie przez ten sam runtime,
- kończy się `PACKAGE_GENERATION_OK` tylko wtedy, gdy pakiet można poprawnie załadować.

Oczekiwany wynik:

```text
PACKAGE_GENERATION_OK
Package      : C:\SSIS\POC\WriteShareTest.dtsx
Output share : \\DC01\SSISLab$
Package name : WriteShareTest
Tasks        : 1
```

## 3. Sprawdź plik

```powershell
Test-Path 'C:\SSIS\POC\WriteShareTest.dtsx'
```

Oczekiwane:

```text
True
```

Nie uruchamiaj pakietu ręcznie jako administrator, jeżeli celem jest test tożsamości Proxy. Właściwy test wykonujemy przez SQL Agent.

## 4. Utwórz SQL Agent Job

Uruchom jako administrator SQL Server:

```text
14-create-stage4-job.sql
```

Skrypt:

- sprawdza obecność `POC_SSIS_Export_Proxy`,
- sprawdza przypisanie Proxy do subsystemu `SSIS`,
- tworzy job `POC_SSIS_Secure_Export_Stage4`,
- tworzy krok typu `SSIS`,
- ustawia uruchamianie kroku przez `POC_SSIS_Export_Proxy`,
- uruchamia `C:\SSIS\POC\WriteShareTest.dtsx` ze źródła `File system`.

Nie jest wymagane `SSISDB`.

## 5. Test pełnego toru

Uruchom:

```text
15-test-stage4.sql
```

Skrypt uruchamia job, czeka na zakończenie do 120 sekund i pokazuje historię SQL Agent.

Oczekiwany rezultat:

```text
JobOutcome = Succeeded
STAGE4_JOB_TEST_OK
```

Na `\\DC01\SSISLab$` powinien pojawić się plik:

```text
ssis-proxy-test-yyyyMMdd-HHmmss-fff.txt
```

W środku oczekujemy:

```text
MachineName=SQL64
WindowsIdentity=SQLLAB\poc-ssis-export
```

Jeżeli `WindowsIdentity` wskazuje `SQLLAB\poc-ssis-export`, mamy bezpośrednie potwierdzenie, że pakiet działa pod dedykowanym kontem technicznym, a nie pod kontem aplikacyjnym.

## Granica Stage 4

Stage 4 **nie pobiera jeszcze rekordów z `dbo.ExportRequest`**. Potwierdzamy tylko:

```text
SQL Agent
  -> SSIS Proxy
  -> SQLLAB\poc-ssis-export
  -> C:\SSIS\POC\WriteShareTest.dtsx
  -> \\DC01\SSISLab$
```

Dopiero Stage 5 połączy kolejkę z workerem/jobem i będzie zmieniał statusy `NEW -> RUNNING -> COMPLETED/FAILED`.
