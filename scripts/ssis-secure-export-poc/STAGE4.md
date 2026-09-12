# Stage 4 - SSIS package executed from File System through SQL Agent Proxy

Cel tego etapu: potwierdzić pełny przepływ wykonawczy **SQL Agent -> SSIS Proxy -> lokalny pakiet .dtsx -> \\DC01\SSISLab$** bez użycia SSISDB i bez delegowania tożsamości konta aplikacyjnego.

## Założone nazwy POC

- serwer SQL/Agent: `SQL64`
- konto wykonawcze: `SQLLAB\poc-ssis-export`
- Credential: `POC_SSIS_Export_Credential`
- Proxy: `POC_SSIS_Export_Proxy`
- lokalny katalog pakietu na SQL64: `C:\SSIS\POC`
- package: `WriteShareTest.dtsx`
- package variable: `User::OutputShare`
- test share: `\\DC01\SSISLab$`
- SQL Agent job: `POC_SSIS_Secure_Export_Stage4`

## 1. Utwórz katalog dla pakietu na SQL64

Jako administrator systemu na `SQL64`:

```powershell
New-Item -ItemType Directory -Path 'C:\SSIS\POC' -Force
```

Konto `SQLLAB\poc-ssis-export` potrzebuje tylko prawa odczytu i wykonania do katalogu/pakietu. Nie potrzebuje Modify do `C:\SSIS\POC`.

Przykład:

```powershell
$path = 'C:\SSIS\POC'
icacls $path /grant 'SQLLAB\poc-ssis-export:(OI)(CI)(RX)'
```

## 2. Utwórz minimalny pakiet SSIS

Utwórz Integration Services Project w Visual Studio / SSDT. Projekt służy wyłącznie do zbudowania pojedynczego pakietu - nie wdrażamy go do SSISDB.

W pakiecie `WriteShareTest.dtsx`:

1. Dodaj zmienną pakietową `User::OutputShare` typu `String`.
2. Ustaw jej wartość na `\\DC01\SSISLab$`.
3. Dodaj `Script Task`.
4. W `ReadOnlyVariables` wskaż `User::OutputShare`.
5. W Script Task podmień zawartość `Main()` kodem z pliku `stage4-script-task-main.cs`.
6. Ustaw `ProtectionLevel` pakietu tak, aby pakiet nie wymagał sekretu zależnego od profilu dewelopera. Dla tego POC pakiet nie zawiera żadnych sekretów.

Po zapisaniu projektu skopiuj gotowy `WriteShareTest.dtsx` na `SQL64` do:

```text
C:\SSIS\POC\WriteShareTest.dtsx
```

## 3. Test pakietu lokalnie - opcjonalny

Jeżeli chcesz zweryfikować sam pakiet przed SQL Agentem, uruchom go ręcznie na SQL64 jako administrator. Ten test nie potwierdza jeszcze działania Proxy - potwierdza jedynie poprawność pakietu.

Docelowy test bezpieczeństwa wykonujemy wyłącznie przez SQL Agent.

## 4. Utwórz SQL Agent Job

Uruchom jako administrator SQL Server:

```text
14-create-stage4-job.sql
```

Skrypt:

- sprawdza obecność `POC_SSIS_Export_Proxy`,
- sprawdza przypisanie Proxy do subsystemu `SSIS`,
- sprawdza obecność pakietu `C:\SSIS\POC\WriteShareTest.dtsx`,
- tworzy job `POC_SSIS_Secure_Export_Stage4`,
- tworzy krok typu `SSIS`,
- ustawia uruchamianie kroku przez `POC_SSIS_Export_Proxy`,
- uruchamia pakiet ze źródła `File system`.

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
```

oraz na `\\DC01\SSISLab$` powinien pojawić się plik:

```text
ssis-proxy-test-yyyyMMdd-HHmmss-fff.txt
```

W środku powinny znaleźć się m.in.:

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
