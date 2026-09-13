# Stage 4 - CmdExec Proxy as the execution proof

Cel tego etapu: potwierdzić pełny przepływ wykonawczy **SQL Agent -> CmdExec Proxy -> SQLLAB\poc-ssis-export -> PowerShell -> \\DC01\SSISLab$** bez `Unconstrained Delegation`.

## Dlaczego CmdExec zamiast SSIS na SQL64

Na `SQL64` SQL Agent ma subsystem `SSIS`, ale środowisko nie posiada pełnego zestawu komponentów developerskich/runtime object model wymaganych do bezpiecznego wygenerowania pakietu `.dtsx` bez SSDT, w szczególności `Microsoft.SqlServer.ManagedDTS.dll`.

Nie dokładamy dodatkowych komponentów tylko na potrzeby POC. Zamiast tego Stage 4 dowodzi najważniejszego elementu modelu bezpieczeństwa: **oddzielenia tożsamości aplikacji od tożsamości wykonawczej**.

Docelowo na środowisku z pełnym SSIS krok `CmdExec` można zastąpić krokiem `SSIS`, zachowując ten sam Credential i dedykowane konto wykonawcze.

## Założone nazwy

- serwer SQL/Agent: `SQL64`
- konto aplikacyjne: `SQLLAB\poc-ssis-app`
- konto wykonawcze: `SQLLAB\poc-ssis-export`
- Credential: `POC_SSIS_Export_Credential`
- CmdExec Proxy: `POC_Export_CmdExec_Proxy`
- test share: `\\DC01\SSISLab$`
- SQL Agent job: `POC_Secure_Export_Stage4`

## 1. Utwórz CmdExec Proxy

Uruchom jako administrator SQL Server:

```text
13-create-cmdexec-proxy.sql
```

Skrypt:

- korzysta z istniejącego `POC_SSIS_Export_Credential`,
- tworzy `POC_Export_CmdExec_Proxy`,
- przypisuje Proxy wyłącznie do subsystemu `CmdExec`,
- nie zmienia konta aplikacyjnego ani jego uprawnień.

Oczekiwany wynik:

```text
ProxyName            = POC_Export_CmdExec_Proxy
CredentialIdentity   = SQLLAB\poc-ssis-export
GrantedSubsystem     = CmdExec
```

## 2. Utwórz job testowy

Uruchom:

```text
14-create-stage4-job.sql
```

Job ma jeden krok `CmdExec` wykonywany przez `POC_Export_CmdExec_Proxy`. Krok uruchamia `powershell.exe`, który bez żadnych jawnie podanych poświadczeń zapisuje plik diagnostyczny do:

```text
\\DC01\SSISLab$
```

Poświadczenia do wykonania kroku pochodzą wyłącznie z Credential podpiętego do Proxy.

## 3. Uruchom test

Uruchom:

```text
15-test-stage4.sql
```

Oczekiwany wynik:

```text
JobOutcome = Succeeded
STAGE4_JOB_TEST_OK
```

Na `\\DC01\SSISLab$` powinien pojawić się plik:

```text
cmdexec-proxy-test-yyyyMMdd-HHmmss-fff.txt
```

W środku oczekujemy m.in.:

```text
MachineName=SQL64
WindowsIdentity=SQLLAB\poc-ssis-export
```

To jest bezpośredni dowód, że dostęp do zasobu SMB wykonuje konto techniczne, a nie `SQLLAB\poc-ssis-app` ani użytkownik, który ręcznie uruchomił job.

## Co dokładnie udowadnia Stage 4

```text
SQLLAB\poc-ssis-app
        |
        | Windows Authentication
        v
SQL Server
        |
        | kolejka / procedura
        v
SQL Agent
        |
        | Credential + CmdExec Proxy
        v
SQLLAB\poc-ssis-export
        |
        | bezpośrednie uwierzytelnienie SMB
        v
\\DC01\SSISLab$
```

Nie ma tu delegowania tożsamości aplikacji do kolejnego serwera.

## Relacja do docelowego SSIS

Na serwerze z pełnym środowiskiem SSIS docelowy executor może wyglądać tak:

```text
SQL Agent
  -> SSIS Proxy
  -> SQLLAB\poc-ssis-export
  -> pakiet SSIS
  -> \\FILESERVER\Export$
```

Zmienia się technologia wykonawcza, ale **nie zmienia się model tożsamości ani zasada least privilege**.

## Granica Stage 4

Stage 4 nie pobiera jeszcze rekordów z `dbo.ExportRequest`. Stage 5 połączy działający model wykonawczy z kolejką i doda statusy `NEW -> RUNNING -> COMPLETED/FAILED`, retry oraz kontrolę współbieżności.
