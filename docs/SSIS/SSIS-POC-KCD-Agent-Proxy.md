# POC: SSIS przez SQL Server Agent Proxy z obowiązkową Constrained Delegation

**Wersja:** 1.0 | **Data:** 2026-11-26  
**Status:** plan testów — NOT RUN  
**Zakres:** SQL Server 2022, SSISDB, SQL Agent, AD, SMB, FCI.

Dokument uzupełnia [SQL Server i SSIS bez Unconstrained Delegation](SSIS-bez-Unconstrained-Delegation.md).

## 1. Cel i ograniczenia

Chcę potwierdzić, że istniejący pakiet SSIS mogę uruchomić przez SQL Server Agent i dedykowane Proxy bez zależności od Unconstrained Delegation.

- Korzystam ze zwykłych kont domenowych AD User, a nie gMSA.
- Akceptuję obowiązkową Constrained Delegation (KCD) dla kont technicznych.
- Nie modyfikuję pakietu DTSX, aplikacji ani procedur składowanych.
- Nie implementuję jeszcze kolejki Request → Queue → Worker.
- Nie wymuszam failoveru FCI.
- Nie zmieniam obecnej konfiguracji kont usługowych podczas pierwszego testu.

Rozróżniam konfigurację KCD w AD od faktycznego wykorzystania delegacji. Konto Proxy może uzyskiwać dostęp do zasobów zdalnych z własnymi poświadczeniami. Nie zakładam jednak sukcesu bez testu. Microsoft dokumentuje ograniczenie SSISDB dotyczące constrained delegation w scenariuszu double hop i wskazuje lokalnego Agenta jako alternatywę [1].

## 2. Architektura

~~~mermaid
flowchart TD
 A[DBA - ręczne uruchomienie joba] --> B[SQL Server Agent]
 B --> C[Credential i Proxy - konto domenowe z KCD]
 C --> D[SSISDB - ta sama instancja FCI]
 D --> E[ISServerExec - istniejący pakiet DTSX]
 E --> F[SMB - udział UNC]
 E --> G[Zdalny SQL Server - jeśli dotyczy]
~~~

Katalog SSISDB i Agent umieszczam na tej samej instancji. Weryfikuję rzeczywistą tożsamość na serwerze docelowym, nie tylko ustawienie Run as.

## 3. Konta domenowe

W przykładach stosuję fikcyjną domenę EXAMPLE. Zapis Windows to DOMENA\konto lub konto@domena.

| Konto | Funkcja | Delegacja docelowa |
|---|---|---|
| EXAMPLE\svc_sqlserver | Database Engine | KCD |
| EXAMPLE\svc_sqlagent | SQL Agent, jeśli osobne konto | KCD |
| EXAMPLE\svc_ssis_test | Credential i Proxy | KCD |

Z administratorem AD uzgadniam konfigurację KCD, konkretne dozwolone SPN oraz wariant Kerberos only lub protocol transition. Nie rejestruję arbitralnych SPN na koncie Proxy. Przykładowe cele KCD to CIFS i MSSQLSvc, jeśli rzeczywiście odpowiadają wymaganym usługom. Samo skonfigurowanie tych celów nie dowodzi, że pakiet korzysta z delegacji.

Kontu Proxy nadaję minimalne uprawnienia do katalogu testowego (Share i NTFS), baz danych oraz projektu SSISDB. Weryfikuję prawo Log on as a batch job i pozostałe wymagania Agent/GPO na każdym węźle. Nie nadaję sysadmin, ssis_admin ani praw administratora lokalnego lub domenowego. Hasło przechowuję i rotuję zgodnie z polityką bezpieczeństwa.

## 4. Inwentaryzacja

### Active Directory

Wykonuję polecenia odczytowe z hosta wyposażonego w moduł ActiveDirectory.

~~~powershell
$accounts = 'svc_sqlserver', 'svc_sqlagent', 'svc_ssis_test'
foreach ($account in $accounts) {
    Get-ADUser -Identity $account -Properties @(
        'TrustedForDelegation',
        'TrustedToAuthForDelegation',
        'msDS-AllowedToDelegateTo',
        'ServicePrincipalName',
        'AccountNotDelegated'
    ) | Select-Object SamAccountName, Enabled, TrustedForDelegation,
        TrustedToAuthForDelegation, msDS-AllowedToDelegateTo,
        ServicePrincipalName, AccountNotDelegated | Format-List
}
~~~

| Właściwość | Interpretacja |
|---|---|
| TrustedForDelegation | False docelowo; True oznacza Unconstrained Delegation |
| msDS-AllowedToDelegateTo | Lista dozwolonych SPN klasycznej KCD |
| TrustedToAuthForDelegation | True zezwala na protocol transition; False może oznaczać Kerberos only |
| AccountNotDelegated | Dodatkowa ochrona tożsamości konta przed delegowaniem |

Nie utożsamiam TrustedToAuthForDelegation=False z brakiem KCD. Nie zmieniam flag ochronnych bez uzgodnienia.

### SQL Server

~~~sql
SELECT servicename, service_account, status_desc
FROM sys.dm_server_services;

SELECT SERVERPROPERTY('ServerName') AS InstanceName,
       SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS ActiveNode,
       SERVERPROPERTY('IsClustered') AS IsClustered;

SELECT j.name AS JobName, s.step_id, s.step_name, s.subsystem,
       p.name AS ProxyName
FROM msdb.dbo.sysjobs AS j
JOIN msdb.dbo.sysjobsteps AS s ON s.job_id = j.job_id
LEFT JOIN msdb.dbo.sysproxies AS p ON p.proxy_id = s.proxy_id
WHERE s.subsystem = 'SSIS';
~~~

Sprawdzam Connection Managers, Windows/SQL Authentication, parametry, referencje środowiska, wersję projektu, runtime 32/64-bit, UNC, zdalne źródła oraz dodatkowe przeskoki uwierzytelniania.

## 5. Bezpieczeństwo testu

Preferuję dane testowe i wydzielony katalog wyjściowy. Wykorzystuję istniejące parametry pakietu bez modyfikacji DTSX. Nie uruchamiam pakietu na danych produkcyjnych, jeśli grozi to ponownym przetwarzaniem operacji, nadpisaniem plików, usunięciem danych lub wysłaniem komunikatów. Jeżeli nie mogę odizolować skutków, wstrzymuję test do zatwierdzenia bezpiecznego zakresu.

## 6. Credential i Proxy

Skrypty wykonuję jako uprawniony DBA w kontrolowanej sesji. Przed wykonaniem sprawdzam, czy obiekty już istnieją. Hasło pobieram z zatwierdzonego źródła sekretów; nie zapisuję go w repozytorium ani historii poleceń.

~~~sql
USE master;
GO
CREATE LOGIN [EXAMPLE\svc_ssis_test] FROM WINDOWS;
GO
CREATE CREDENTIAL [SSIS_Test_Credential]
WITH IDENTITY = N'EXAMPLE\svc_ssis_test',
     SECRET = N'<SECRET_FROM_VAULT>';
GO
USE msdb;
GO
EXEC dbo.sp_add_proxy
    @proxy_name = N'SSIS_Test_Proxy',
    @credential_name = N'SSIS_Test_Credential',
    @enabled = 1;
GO
EXEC dbo.sp_grant_proxy_to_subsystem
    @proxy_name = N'SSIS_Test_Proxy',
    @subsystem_name = N'Dts';
GO
USE SSISDB;
GO
CREATE USER [EXAMPLE\svc_ssis_test]
FOR LOGIN [EXAMPLE\svc_ssis_test];
GO
~~~

W SSMS przechodzę do Integration Services Catalogs → SSISDB → folder → Projects → projekt → Properties → Permissions. Nadaję READ i EXECUTE na konkretnym projekcie oraz READ na wymaganym środowisku. Tworzę użytkowników w bazach źródłowych i docelowych, jeśli pakiet korzysta z Windows Authentication.

Job tworzę i uruchamiam jako DBA. Jeśli właściciel joba nie jest sysadmin, zapewniam mu odpowiednie prawa Agent oraz dostęp do proxy za pomocą sp_grant_login_to_proxy. Nie udostępniam proxy aplikacji.

~~~sql
SELECT p.name AS ProxyName, p.enabled,
       c.name AS CredentialName, c.credential_identity,
       s.subsystem
FROM msdb.dbo.sysproxies AS p
JOIN sys.credentials AS c ON c.credential_id = p.credential_id
JOIN msdb.dbo.sysproxysubsystem AS ps ON ps.proxy_id = p.proxy_id
JOIN msdb.dbo.syssubsystems AS s ON s.subsystem_id = ps.subsystem_id
WHERE p.name = N'SSIS_Test_Proxy';
~~~

## 7. Testowy job

| Parametr | Wartość |
|---|---|
| Name | TEST_SSIS_KCD_Proxy |
| Type | SQL Server Integration Services Package |
| Run as | SSIS_Test_Proxy |
| Package source | SSIS Catalog |
| Server | Ta sama instancja FCI, właściwy VNN/instancja |
| Package | Istniejący pakiet DTSX |
| Configuration | Parametry i środowisko testowe |
| Schedule | Brak |
| Retry attempts | 0 |

Wybieram właściwą referencję środowiska i runtime. Uruchamiam ręcznie:

~~~sql
EXEC msdb.dbo.sp_start_job
    @job_name = N'TEST_SSIS_KCD_Proxy';
~~~

Samo powodzenie sp_start_job oznacza zgłoszenie zadania, nie zakończenie pakietu.

## 8. Weryfikacja

### Historia Agent

~~~sql
SELECT TOP (30) j.name, h.step_id, h.step_name,
       h.run_status, h.run_date, h.run_time,
       h.run_duration, h.message
FROM msdb.dbo.sysjobhistory AS h
JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
WHERE j.name = N'TEST_SSIS_KCD_Proxy'
ORDER BY h.instance_id DESC;
~~~

Sprawdzam wynik kroku i całego zadania (step_id=0; run_status=1 oznacza sukces).

### SSISDB

~~~sql
SELECT TOP (30) execution_id, folder_name, project_name,
       package_name, executed_as_name, caller_name,
       status, start_time, end_time
FROM SSISDB.catalog.executions
ORDER BY execution_id DESC;

DECLARE @ExecutionId bigint = 123; -- Podstawiam rzeczywisty ID.
SELECT message_time, message_type, message_source_type, message
FROM SSISDB.catalog.operation_messages
WHERE operation_id = @ExecutionId
ORDER BY message_time, operation_message_id;
~~~

Oczekuję statusu 7 (Succeeded). Koreluję wykonanie z czasem joba i nazwą pakietu. Nie uznaję executed_as_name ani caller_name za samodzielny dowód tożsamości SMB.

### Serwer plików

Na serwerze docelowym sprawdzam sesje i pliki w trakcie wykonywania pakietu.

~~~powershell
Get-SmbSession |
    Where-Object ClientUserName -eq 'EXAMPLE\svc_ssis_test' |
    Select-Object ClientComputerName, ClientUserName, NumOpens, SessionId

Get-SmbOpenFile |
    Where-Object ClientUserName -eq 'EXAMPLE\svc_ssis_test' |
    Select-Object ClientComputerName, ClientUserName, Path, SessionId
~~~

Krótkie sesje mogą zakończyć się przed odczytem. Wykorzystuję również audyt 4624 (typ 3), 5140 i 5145, jeśli odpowiedni audyt jest włączony. Koreluję czas, konto, klienta, identyfikator logowania i ścieżkę. Sprawdzam poprawność pliku, jego zawartość i liczbę rekordów.

Dla zdalnego SQL Server weryfikuję login i schemat uwierzytelniania na tej instancji. Kerberos sam w sobie nie dowodzi użycia delegacji.

## 9. Macierz testów

| Test | Database Engine | Agent | Proxy | Uruchomienie |
|---|---|---|---|---|
| A | Unconstrained, jeśli stan bieżący | Stan bieżący | — | Aplikacja |
| B | Stan bieżący, bez zmian | Stan bieżący | KCD | Lokalny Agent + Proxy |
| C | KCD | KCD | KCD | Lokalny Agent + Proxy |
| D | KCD | KCD | — | Aplikacja |

Zaczynam od B. Baseline A mogę oprzeć na istniejących wiarygodnych wynikach. Nie powtarzam operacji biznesowej bez potrzeby.

Test C wykonuję w środowisku testowym lub osobnym zatwierdzonym oknie. Administrator AD konfiguruje KCD i usuwa Unconstrained Delegation na właściwych kontach. Nie usuwam SPN SQL Server. Uwzględniam replikację AD, ważność biletów i odnowienie kontekstów uwierzytelniania. Nie czyszczę globalnie cache Kerberos ani nie restartuję usług produkcyjnych bez uzgodnienia. Test D wykonuję tylko wtedy, gdy jest bezpieczny.

| Wynik | Wniosek |
|---|---|
| B PASS, C NOT RUN | Proxy działa, ale niezależność od Unconstrained nie została dowiedziona |
| B PASS, C PASS, potwierdzony dostęp zdalny | Badany pakiet działa bez Unconstrained Delegation w badanej konfiguracji |
| B PASS, C FAIL | Analizuję zależności od delegacji i różnice konfiguracji |
| B FAIL | Diagnozuję Proxy, pakiet i uprawnienia przed zmianą AD |
| C PASS, D FAIL | Rozważam zmianę sposobu uruchamiania |
| C PASS, D PASS | Badam, czy także dotychczasowy mechanizm nie wymaga Unconstrained |

Sukces C nie oznacza, że KCD była używana ani że jest konieczna. Nie wykonuję wariantu bez KCD, ponieważ polityka organizacji tego nie dopuszcza.

## 10. Diagnostyka

| Objaw | Co sprawdzam |
|---|---|
| Agent nie uruchamia kroku | Credential, hasło, GPO, prawa logowania, subsystem i proxy |
| Odmowa dostępu do SSISDB | Login, użytkownik, READ/EXECUTE projektu, READ środowiska |
| ANONYMOUS LOGON | Kontekst, Connection Manager, SPN, dodatkowy hop |
| Access Denied na UNC | Share ACL, NTFS ACL, tożsamość SMB, ścieżka |
| Błąd połączenia | DNS, port SQL lub TCP 445, firewall, TLS, sterowniki |
| Job OK, brak pliku | Parametry, przepływ sterowania, komunikaty SSIS, wynik biznesowy |
| Działa tylko na jednym węźle | Runtime, GPO, sieć, sterowniki, lokalne zależności |

Nie nadaję nadmiernych uprawnień ani nie włączam Unconstrained Delegation w celu maskowania błędów.

## 11. FCI

Nie wymuszam failoveru. Weryfikuję dostępność komponentów SSIS, sterowników, praw logowania, dostępu do UNC na wszystkich potencjalnych właścicielach instancji. Test aktywnego węzła nie potwierdza działania drugiego węzła. Test przełączenia przewiduję tylko w labie lub osobnym zatwierdzonym oknie.

## 12. Protokół POC

| Test | UTC | Job / Execution ID | Konto SMB | Wynik | Dowód |
|---|---|---|---|---|---|
| A | — | — | — | NOT RUN | — |
| B | — | — | — | NOT RUN | — |
| C | — | — | — | NOT RUN | — |
| D | — | — | — | NOT RUN | — |

- [ ] Inwentaryzuję konta i zależności pakietu.
- [ ] Uzgadniam konto AD z KCD i potwierdzam brak Unconstrained na Proxy.
- [ ] Nadaję minimalne uprawnienia i przygotowuję bezpieczny zakres.
- [ ] Tworzę Credential, Proxy, użytkownika SSISDB i job bez harmonogramu.
- [ ] Wykonuję B bez zmian istniejących kont.
- [ ] Potwierdzam historię Agent, SSISDB, wynik biznesowy i tożsamość zdalną.
- [ ] Uzgadniam C i potwierdzam stan delegacji po odnowieniu kontekstów.
- [ ] Wykonuję C i zapisuję dowody.
- [ ] Oceniam zasadność D i dalszej migracji.

## 13. Porządkowanie i rollback

Wyłączam job, sprawdzam brak aktywnego wykonania i archiwizuję dowody. Po zatwierdzeniu usuwam wyłącznie obiekty dedykowane POC, w kolejności zależności:

~~~sql
USE msdb;
GO
EXEC dbo.sp_delete_job @job_name = N'TEST_SSIS_KCD_Proxy';
EXEC dbo.sp_delete_proxy @proxy_name = N'SSIS_Test_Proxy';
GO
USE SSISDB;
GO
DROP USER [EXAMPLE\svc_ssis_test];
GO
USE master;
GO
DROP CREDENTIAL [SSIS_Test_Credential];
DROP LOGIN [EXAMPLE\svc_ssis_test];
GO
~~~

Przed usunięciem sprawdzam inne joby, użytkowników baz i mapowania. Wycofuję dedykowane uprawnienia SMB/NTFS oraz uzgadniam wycofanie konta AD. Nie usuwam współdzielonych obiektów. Ponowne włączenie Unconstrained Delegation nie jest automatycznym rollbackiem.

## 14. Decyzja po POC

Dopiero po sukcesie C rozważam kolejkę Request → Queue → Worker. Powtarzam test dla reprezentatywnych pakietów. Sukces jednego pakietu nie potwierdza gotowości całej instancji.

**Moim celem nie jest usunięcie obowiązkowej Constrained Delegation, lecz wyeliminowanie zależności od Unconstrained Delegation.**

## 15. Źródła

1. [Microsoft Learn — SSIS Catalog, double-hop scenarios](https://learn.microsoft.com/en-us/sql/integration-services/catalog/ssis-catalog?view=sql-server-ver16#ssisdb-catalog-and-delegation-in-double-hop-scenarios)
2. [Microsoft Learn — SQL Server Agent Jobs for Packages](https://learn.microsoft.com/en-us/sql/integration-services/packages/sql-server-agent-jobs-for-packages)
3. [Microsoft Learn — Create a SQL Server Agent Proxy](https://learn.microsoft.com/en-us/sql/ssms/agent/create-a-sql-server-agent-proxy)
4. [Microsoft Learn — catalog.executions](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executions-ssisdb-database)

Skrypty przedstawiam jako materiał do walidacji laboratoryjnej, nie potwierdzone wdrożenie.
