# POC: odczyt danych źródłowych przez SSIS i SQL Server Agent Proxy z Constrained Delegation

**Wersja:** 1.1 | **Data:** 2026-11-26  
**Status:** plan testów — NOT RUN  
**Zakres:** SQL Server 2022, SSISDB, SQL Agent, AD, SQL Server i Oracle jako źródła danych, FCI.

Dokument uzupełnia [SQL Server i SSIS bez Unconstrained Delegation](SSIS-bez-Unconstrained-Delegation.md).

## 1. Cel i ograniczenia

Chcę potwierdzić, że istniejący pakiet SSIS mogę uruchomić przez SQL Server Agent i dedykowane Proxy z obowiązkową KCD, odczytując dane z systemów źródłowych bez zależności od Unconstrained Delegation. Uprawnienia do źródeł ograniczam do odczytu. Nie zakładam, że cały pakiet jest pozbawiony operacji zapisu: jego ewentualne cele, staging i inne skutki analizuję osobno.

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
 E -->|Odczyt - Windows lub SQL Authentication| F[Źródłowy SQL Server]
 E -->|Odczyt - Oracle User lub Kerberos| G[Źródłowy Oracle na Unix/Linux]
~~~

Katalog SSISDB i Agent umieszczam na tej samej instancji. Weryfikuję rzeczywistą tożsamość na serwerze docelowym, nie tylko ustawienie Run as.

## 3. Konta domenowe

W przykładach stosuję fikcyjną domenę EXAMPLE. Zapis Windows to DOMENA\konto lub konto@domena.

| Konto | Funkcja | Delegacja docelowa |
|---|---|---|
| EXAMPLE\svc_sqlserver | Database Engine | KCD |
| EXAMPLE\svc_sqlagent | SQL Agent, jeśli osobne konto | KCD |
| EXAMPLE\svc_ssis_reader | Credential i Proxy | KCD |

Z administratorem AD uzgadniam klasyczną KCD i konkretne docelowe SPN. Preferuję Kerberos only, jeżeli polityka na to pozwala; nie włączam protocol transition bez uzasadnienia. Nie rejestruję arbitralnych SPN na koncie Proxy.

### 3.1. Atrybut msDS-AllowedToDelegateTo

Traktuję ten wielowartościowy atrybut jako listę usług, do których konto może delegować cudzą tożsamość, a nie listę serwerów, do których może się logować. Dla bezpośredniego połączenia z własnymi poświadczeniami KCD nie jest konieczna. Wypełniam listę wyłącznie zatwierdzonymi celami wymaganymi przez politykę organizacji.

| Źródło i uwierzytelnianie | Przykładowy cel KCD, jeśli uzasadniony |
|---|---|
| SQL Server / Windows Authentication | MSSQLSvc/sqlsource01.example.test:1433 |
| SQL Server / SQL Authentication | Nie dotyczy tego połączenia |
| Oracle / użytkownik i hasło Oracle | Nie dotyczy tego połączenia |
| Oracle / Kerberos z AD | oracle/oracle01.example.test (przykład; potwierdzam rzeczywisty principal) |

Weryfikuję SPN na właściwym koncie usługi, a dla FCI korzystam z VNN i rzeczywistego portu, nie z nazwy fizycznego węzła. Dla Oracle potwierdzam service principal i realm z administratorem Oracle/Kerberos; jeśli usługa należy do odrębnego realm, nie zakładam, że zwykły wpis w AD wystarczy.

~~~powershell
setspn -Q MSSQLSvc/sqlsource01.example.test:1433
# Tylko gdy Oracle korzysta z Kerberos i SPN jest rejestrowany w AD:
setspn -Q oracle/oracle01.example.test
Get-ADUser -Identity 'svc_ssis_reader' -Properties msDS-AllowedToDelegateTo |
    Select-Object -ExpandProperty msDS-AllowedToDelegateTo
~~~

Nie dodaję CIFS, ponieważ dostęp SMB nie jest częścią głównego POC. Jeżeli pakiet faktycznie korzysta z udziału, analizuję go osobno. Jeżeli żadne źródło nie wymaga Kerberos, nie wymyślam zastępczych SPN tylko po to, aby wypełnić atrybut; uzgadniam zgodną z polityką konfigurację z administratorem AD. Nie zmieniam AD samodzielnie.

Kontu Proxy nadaję minimalne uprawnienia do projektu SSISDB i odczytu wymaganych źródeł korzystających z Windows Authentication. Dla pozostałych źródeł ograniczam uprawnienia rzeczywistego konta bazodanowego. Nie nadaję praw zapisu w źródłach. Weryfikuję prawo Log on as a batch job i pozostałe wymagania Agent/GPO na każdym węźle. Nie nadaję sysadmin, ssis_admin ani praw administratora lokalnego lub domenowego. Hasło przechowuję i rotuję zgodnie z polityką bezpieczeństwa.

## 4. Inwentaryzacja

### Active Directory

Wykonuję polecenia odczytowe z hosta wyposażonego w moduł ActiveDirectory.

~~~powershell
$accounts = 'svc_sqlserver', 'svc_sqlagent', 'svc_ssis_reader'
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

Sprawdzam Connection Managers, mechanizm uwierzytelniania każdego źródła, parametry i ich nadpisania przez środowisko, wersję projektu, runtime 32/64-bit, zdalne źródła oraz dodatkowe przeskoki uwierzytelniania (np. linked server, Oracle DB link). Ustalam rzeczywisty driver, nazwę hosta, port, bazę lub Oracle service name. Nie zakładam, że konto Proxy zastąpi zapisane poświadczenia Connection Managera.

| Źródło | Typ i wersja | Host/port/service | Sterownik | Authentication | Oczekiwany login | Obiekty do odczytu |
|---|---|---|---|---|---|---|
| S1 | SQL Server | do uzupełnienia | do uzupełnienia | Windows/SQL | do uzupełnienia | do uzupełnienia |
| S2 | Oracle Unix/Linux | do uzupełnienia | do uzupełnienia | Oracle User/Kerberos | do uzupełnienia | do uzupełnienia |

### 4.1. SQL Server — uprawnienia do odczytu

Na każdej źródłowej instancji, jeśli pakiet korzysta z Windows Authentication, uzgadniam z DBA utworzenie loginu i użytkownika oraz SELECT na wymaganych obiektach. Poniższy przykład wykonuję tylko po sprawdzeniu, czy obiekty nie istnieją.

~~~sql
USE master;
GO
CREATE LOGIN [EXAMPLE\svc_ssis_reader] FROM WINDOWS;
GO
USE SourceDatabase;
GO
CREATE USER [EXAMPLE\svc_ssis_reader]
FOR LOGIN [EXAMPLE\svc_ssis_reader];
GO
GRANT SELECT ON OBJECT::dbo.SourceTable
TO [EXAMPLE\svc_ssis_reader];
GO
-- Alternatywnie, gdy zakres obejmuje cały zatwierdzony schemat:
-- GRANT SELECT ON SCHEMA::Export TO [EXAMPLE\svc_ssis_reader];
~~~

Nie nadaję INSERT, UPDATE, DELETE, ALTER, CONTROL, db_owner ani sysadmin. Preferuję konkretne obiekty zamiast db_datareader. Weryfikuję również uprawnienia odziedziczone przez grupy AD, role i public; sam GRANT SELECT nie usuwa wcześniej nadanych praw zapisu. Jeżeli pakiet odczytuje dane przez procedurę, analizuję jej działanie przed ewentualnym nadaniem EXECUTE — procedura może modyfikować dane mimo braku bezpośrednich praw DML. Dla SQL Authentication stosuję analogiczny zakres praw na rzeczywistym loginie SQL, nie na koncie Proxy.

### 4.2. Oracle na Unix/Linux — natywne uwierzytelnianie

Jeśli Connection Manager korzysta z użytkownika i hasła Oracle, konto domenowe odpowiada za uruchomienie SSIS, natomiast Oracle uwierzytelnia osobne konto bazodanowe. Nie dodaję SPN Oracle do KCD na potrzeby takiego połączenia.

Administrator Oracle nadaje istniejącemu dedykowanemu użytkownikowi minimalne prawa, przykładowo:

~~~sql
GRANT CREATE SESSION TO SSIS_READER;
GRANT SELECT ON APP_SCHEMA.CUSTOMERS TO SSIS_READER;
GRANT SELECT ON APP_SCHEMA.TRANSACTIONS TO SSIS_READER;
~~~

Sprawdzam role, uprawnienia systemowe, obiektowe, PUBLIC i ewentualne procedury. Nie nadaję szerokich SELECT ANY TABLE ani praw DML. Hasło przechowuję w parametrze wrażliwym SSISDB lub zatwierdzonym mechanizmie sekretów. Nie zmieniam pakietu tylko na potrzeby POC.

### 4.3. Oracle na Unix/Linux — Kerberos

Jeśli źródło używa Kerberos, uzgadniam konfigurację klienta i serwera, mapowanie principalu do użytkownika Oracle, realm, relacje zaufania i rzeczywisty service principal (często oracle/FQDN@REALM). Unix nie wyklucza Kerberos. Nie zakładam jednak obsługi tego mechanizmu przez każdy sterownik SSIS/Oracle. Sprawdzam zgodność konkretnej wersji providera, dostęp do właściwego cache poświadczeń i konfiguracji Oracle Net w kontekście Proxy. Plik keytab usługi pozostaje po stronie właściwego administratora; nie kopiuję go do SSIS ani repozytorium.

Jeżeli klient korzysta z własnego biletu konta Proxy, nie musi delegować tożsamości aplikacji. Jeśli pojawia się dodatkowy hop, analizuję go odrębnie. W Oracle nadaję zmapowanemu użytkownikowi minimalne prawa odczytu analogicznie do wariantu natywnego.

Dla obu wariantów Oracle weryfikuję klienta/driver, wersję i architekturę 32/64-bit, TNS_ADMIN, tnsnames.ora lub Easy Connect, sqlnet.ora, DNS, port listenera (1521 jest tylko przykładem), TLS/wallet jeśli wymagane, oraz dostęp do konfiguracji z konta wykonawcy na każdym węźle FCI.

## 5. Bezpieczeństwo testu

Preferuję dane testowe, ograniczony uzgodniony zakres odczytu i odizolowane miejsce docelowe, jeśli pakiet zapisuje wyniki. Uzgadniam obciążenie źródeł, limity czasu i okno testowe. Wykorzystuję istniejące parametry pakietu bez modyfikacji DTSX. Nie uruchamiam pakietu na danych produkcyjnych, jeśli grozi to ponownym przetwarzaniem operacji, nadpisaniem plików, usunięciem danych lub wysłaniem komunikatów. Jeżeli nie mogę odizolować skutków, wstrzymuję test do zatwierdzenia bezpiecznego zakresu.

## 6. Credential i Proxy

Skrypty wykonuję jako uprawniony DBA w kontrolowanej sesji. Przed wykonaniem sprawdzam, czy obiekty już istnieją. Hasło pobieram z zatwierdzonego źródła sekretów; nie zapisuję go w repozytorium ani historii poleceń.

~~~sql
USE master;
GO
CREATE LOGIN [EXAMPLE\svc_ssis_reader] FROM WINDOWS;
GO
CREATE CREDENTIAL [SSIS_Test_Credential]
WITH IDENTITY = N'EXAMPLE\svc_ssis_reader',
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
CREATE USER [EXAMPLE\svc_ssis_reader]
FOR LOGIN [EXAMPLE\svc_ssis_reader];
GO
~~~

W SSMS przechodzę do Integration Services Catalogs → SSISDB → folder → Projects → projekt → Properties → Permissions. Nadaję READ i EXECUTE na konkretnym projekcie oraz READ na wymaganym środowisku. Uprawnienia źródłowe nadaję zgodnie z sekcją 4. Uprawnienia do ewentualnego celu ograniczam niezależnie, zgodnie z funkcją pakietu.

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

Oczekuję statusu 7 (Succeeded). Koreluję wykonanie z czasem joba i nazwą pakietu. Nie uznaję executed_as_name ani caller_name za samodzielny dowód tożsamości w systemie źródłowym.

### 8.3. Źródłowy SQL Server

Na źródłowej instancji, podczas rzeczywistego wykonywania pakietu, sprawdzam sesje. Wymagam odpowiednich praw diagnostycznych (na SQL Server 2022 do DMV serwerowych m.in. VIEW SERVER PERFORMANCE STATE). Nie nadaję tych praw samemu kontu odczytowemu wyłącznie w celu diagnostyki.

~~~sql
SELECT s.session_id, s.login_name, s.original_login_name,
       s.host_name, s.program_name, c.auth_scheme,
       c.client_net_address, s.login_time
FROM sys.dm_exec_sessions AS s
JOIN sys.dm_exec_connections AS c ON c.session_id = s.session_id
WHERE s.is_user_process = 1
  AND (s.login_name = N'EXAMPLE\svc_ssis_reader'
       OR s.original_login_name = N'EXAMPLE\svc_ssis_reader');
~~~

Jeśli źródło korzysta z SQL Authentication, podstawiam właściwy login. Przy Windows Authentication oczekuję konta Proxy i Kerberos, jeśli wymaga tego polityka. KERBEROS nie dowodzi delegowania cudzych poświadczeń. Krótkie sesje mogą wymagać zatwierdzonego audytu logowań i odczytów zamiast jednorazowego DMV. Jeśli oczekiwanej sesji nie widzę, koreluję także sesje według czasu, hosta i aplikacji, aby nie przeoczyć innej tożsamości.

W ramach sesji rzeczywistego loginu (lub osobnego zatwierdzonego testu tego samego konta) sprawdzam efektywne prawa do przykładowego obiektu:

~~~sql
USE SourceDatabase;
SELECT ORIGINAL_LOGIN() AS LoginName, USER_NAME() AS DatabaseUser,
       HAS_PERMS_BY_NAME('dbo.SourceTable','OBJECT','SELECT') AS CanSelect,
       HAS_PERMS_BY_NAME('dbo.SourceTable','OBJECT','INSERT') AS CanInsert,
       HAS_PERMS_BY_NAME('dbo.SourceTable','OBJECT','UPDATE') AS CanUpdate,
       HAS_PERMS_BY_NAME('dbo.SourceTable','OBJECT','DELETE') AS CanDelete;
~~~

Oczekuję SELECT=1 i praw DML=0 na badanym obiekcie. NULL oznacza wynik nierozstrzygający. Sprawdzam wszystkie wymagane obiekty oraz inne ścieżki uprawnień; nie wykonuję prób modyfikacji produkcyjnych danych. Oddzielna sesja DBA nie zastępuje dowodu tożsamości pakietu.

### 8.4. Źródłowy Oracle

W sesji połączonej za pomocą tej samej konfiguracji klienta i uwierzytelniania sprawdzam:

~~~sql
SELECT SYS_CONTEXT('USERENV','SESSION_USER') AS SESSION_USER,
       SYS_CONTEXT('USERENV','AUTHENTICATION_METHOD') AS AUTH_METHOD,
       SYS_CONTEXT('USERENV','AUTHENTICATED_IDENTITY') AS AUTH_IDENTITY,
       SYS_CONTEXT('USERENV','OS_USER') AS OS_USER
FROM dual;
~~~

Oczekuję użytkownika Oracle lub tożsamości zmapowanej z Kerberos, zgodnie z konfiguracją. OS_USER nie jest samodzielnym dowodem uwierzytelnienia. Jeśli istniejący pakiet nie wykonuje tego zapytania, proszę DBA Oracle o korelację rzeczywistych sesji (np. V$SESSION/GV$SESSION i zatwierdzony audyt) z czasem, kontem i hostem SSIS. Nie modyfikuję DTSX na potrzeby diagnostyki.

Weryfikuję odczyt uzgodnionych obiektów, oczekiwaną liczbę rekordów i poprawność rezultatu pakietu, a uprawnienia do zapisu sprawdzam administracyjnie, bez prób DML na produkcji. Jeżeli pakiet zawiera dodatkowe operacje w źródle, nie klasyfikuję go jako read-only bez ich wyjaśnienia.

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
| B PASS, C PASS, potwierdzony odczyt wszystkich źródeł i tożsamość | Badany pakiet działa bez Unconstrained Delegation w badanej konfiguracji |
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
| Brak SELECT / ORA-01031 | Efektywne uprawnienia rzeczywistego użytkownika źródłowego |
| ORA-01017 / błąd Kerberos | Mechanizm uwierzytelniania, poświadczenia, mapowanie principalu, konfiguracja klienta |
| ORA-12154 / ORA-12514 | TNS_ADMIN, alias, service name, listener i konfiguracja dostępna dla Proxy |
| Błąd połączenia | DNS, port SQL lub Oracle listenera, firewall, TLS, sterowniki |
| Job OK, brak odczytu | Parametry, przepływ sterowania, komunikaty SSIS, rzeczywiste sesje źródłowe i wynik biznesowy |
| Działa tylko na jednym węźle | Runtime, GPO, sieć, sterowniki, lokalne zależności |

Nie nadaję nadmiernych uprawnień ani nie włączam Unconstrained Delegation w celu maskowania błędów.

## 11. FCI

Nie wymuszam failoveru. Weryfikuję dostępność komponentów SSIS, sterowników, praw logowania, dostępu do źródeł, konfiguracji Oracle Net oraz zgodności architektury sterowników na wszystkich potencjalnych właścicielach instancji. Test aktywnego węzła nie potwierdza działania drugiego węzła. Test przełączenia przewiduję tylko w labie lub osobnym zatwierdzonym oknie.

## 12. Protokół POC

| Test | UTC | Job / Execution ID | Tożsamości źródłowe | Wynik | Dowód |
|---|---|---|---|---|---|
| A | — | — | — | NOT RUN | — |
| B | — | — | — | NOT RUN | — |
| C | — | — | — | NOT RUN | — |
| D | — | — | — | NOT RUN | — |

- [ ] Inwentaryzuję konta i zależności pakietu.
- [ ] Uzgadniam konto AD z KCD i potwierdzam brak Unconstrained na Proxy.
- [ ] Inwentaryzuję uwierzytelnianie SQL Server i Oracle oraz zatwierdzone SPN.
- [ ] Nadaję minimalne uprawnienia odczytu i przygotowuję bezpieczny zakres.
- [ ] Tworzę Credential, Proxy, użytkownika SSISDB i job bez harmonogramu.
- [ ] Wykonuję B bez zmian istniejących kont.
- [ ] Potwierdzam historię Agent, SSISDB, odczyt i tożsamość na każdym źródle.
- [ ] Weryfikuję efektywne prawa odczytu i brak praw modyfikacji danych źródłowych.
- [ ] Uzgadniam C i potwierdzam stan delegacji po odnowieniu kontekstów.
- [ ] Wykonuję C i zapisuję dowody.
- [ ] Oceniam zasadność D i dalszej migracji.

### Kryteria odbioru i dowody per źródło

| Test | Źródło | Authentication | Rzeczywisty login | Odczyt / liczba rekordów | Prawa zapisu | Wynik |
|---|---|---|---|---|---|---|
| B | S1 SQL Server | do uzupełnienia | — | — | — | NOT RUN |
| B | S2 Oracle | do uzupełnienia | — | — | — | NOT RUN |
| C | S1 SQL Server | do uzupełnienia | — | — | — | NOT RUN |
| C | S2 Oracle | do uzupełnienia | — | — | — | NOT RUN |

Za PASS uznaję poprawne zakończenie joba i pakietu, rzeczywisty odczyt wszystkich wymaganych źródeł, zgodność tożsamości i wyników oraz potwierdzenie minimalnych praw. Dla C dodatkowo potwierdzam brak Unconstrained Delegation na wszystkich uczestniczących kontach, obowiązkową konfigurację KCD i odnowienie kontekstów. Nie oznaczam niewykonanego lub nieudokumentowanego testu jako PASS. Jeśli pakiet nie wykorzystuje danego typu źródła, oznaczam go N/A z uzasadnieniem.

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
DROP USER [EXAMPLE\svc_ssis_reader];
GO
USE master;
GO
DROP CREDENTIAL [SSIS_Test_Credential];
DROP LOGIN [EXAMPLE\svc_ssis_reader];
GO
~~~

Przed usunięciem sprawdzam inne joby, użytkowników baz i mapowania. Uzgadniam z DBA źródeł wycofanie wyłącznie dedykowanych uprawnień SQL Server i Oracle oraz z administratorem AD wycofanie konta. Nie usuwam współdzielonych loginów ani użytkowników. Zabezpieczam dowody bez danych biznesowych i sekretów. Nie usuwam współdzielonych obiektów. Ponowne włączenie Unconstrained Delegation nie jest automatycznym rollbackiem.

## 14. Decyzja po POC

Dopiero po sukcesie C rozważam kolejkę Request → Queue → Worker. Powtarzam test dla reprezentatywnych pakietów. Sukces jednego pakietu nie potwierdza gotowości całej instancji.

**Moim celem nie jest usunięcie obowiązkowej Constrained Delegation, lecz wyeliminowanie zależności od Unconstrained Delegation.**

## 15. Źródła

1. [Microsoft Learn — SSIS Catalog, double-hop scenarios](https://learn.microsoft.com/en-us/sql/integration-services/catalog/ssis-catalog?view=sql-server-ver16#ssisdb-catalog-and-delegation-in-double-hop-scenarios)
2. [Microsoft Learn — SQL Server Agent Jobs for Packages](https://learn.microsoft.com/en-us/sql/integration-services/packages/sql-server-agent-jobs-for-packages)
3. [Microsoft Learn — Create a SQL Server Agent Proxy](https://learn.microsoft.com/en-us/sql/ssms/agent/create-a-sql-server-agent-proxy)
4. [Microsoft Learn — catalog.executions](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executions-ssisdb-database)

5. [Microsoft Learn — ms-DS-Allowed-To-Delegate-To attribute](https://learn.microsoft.com/en-us/windows/win32/adschema/a-msds-allowedtodelegateto)
6. [Oracle Database Security Guide — Kerberos authentication](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/configuring-kerberos-authentication.html)

Skrypty przedstawiam jako materiał do walidacji laboratoryjnej, nie potwierdzone wdrożenie. Wersja Oracle, sterownik oraz sposób uwierzytelniania pozostają do potwierdzenia w inwentaryzacji. Wszystkie nazwy są przykładowe.
