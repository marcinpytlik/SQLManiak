# Troubleshooting: SQL Agent

SQL Server Agent jest warstwą wykonawczą dla wielu krytycznych procesów DBA:

- backupów,
- CHECKDB,
- maintenance,
- ETL,
- replikacji,
- monitoringu,
- raportów,
- automatyzacji operacyjnej.

Dlatego pytanie:

> „Job failed?”

to tylko pierwszy poziom diagnostyki.

Trzeba również odpowiedzieć:

- czy job w ogóle wystartował,
- czy schedule był aktywny,
- który krok zawiódł,
- pod jakim kontekstem security działał,
- czy retry coś zmienił,
- czy powiadomienie faktycznie wyszło,
- czy nie ma problemu z samym SQL Agent.

---

# Diagnostic flow

```text
Job missing / failed / long running
            |
            v
Is SQL Server Agent running?
            |
            v
Did the job start?
      +-----+-----+
      |           |
     NO          YES
      |           |
 schedule       which step?
 owner          |
 disabled       v
 Agent down   step output / message
                  |
                  v
            security context?
                  |
          owner / proxy / credential
                  |
                  v
              dependency?
                  |
      file / share / linked server / mail
                  |
                  v
              retry?
                  |
                  v
          notification sent?
                  |
                  v
             validate fix
```

---

# 1. First checks

1. Czy usługa SQL Server Agent działa?
2. Czy job jest `enabled = 1`?
3. Czy schedule jest włączony?
4. Czy job faktycznie miał się uruchomić?
5. Czy są wpisy w `msdb.dbo.sysjobhistory`?
6. Który krok zakończył się błędem?
7. Jaki był `run_status`?
8. Jaki komunikat zwrócił krok?
9. Czy problem dotyczy ownera, proxy albo credential?
10. Czy zewnętrzna zależność była dostępna?
11. Czy retry zadziałał?
12. Czy operator / Database Mail wysłał powiadomienie?

---

# 2. Existing sources of truth

## Daily health

- [DBA Daily Pack – Agent Jobs Health](../../tools/DBADaillyPack/sql/02_Agent_Jobs_Health.sql)

Skrypt pokazuje:

- failed runs z ostatnich 24h,
- joby z harmonogramem, które nie wykonały się od dłuższego czasu.

## Incident timeline

- [investigate.sql](../../scripts/t-sql/investigate.sql)

Skrypt potrafi odtworzyć historię jobów w zadanym oknie czasu.

## Job compliance / operational reporting

- [DBACentralRepository – Job Operational Reports](../../scripts/DBACentralRepository_v3/11_Create_Job_Operational_Report_Procedures.sql)

Repo monitoruje m.in.:

- failed executions,
- disabled jobs,
- jobs without schedule,
- jobs without notification,
- missing documentation,
- unauthorized changes.

## SQL Agent and Database Mail logs

- [SQL Server Logs – overview](../../docs/Inside_SQL_Server2022/03_SQLServer2022_LogsFull.md)

## Monitoring

- [Zabbix MSSQL monitoring](../../scripts/zabbix-mssql-monitoring/)

---

# 3. SQL Server Agent service

Zanim zaczniesz analizować job:

> upewnij się, że SQL Server Agent działa.

Jeżeli Agent nie działa:

- job nie wystartuje z harmonogramu,
- alerty SQL Agent nie zadziałają,
- operatorzy nie dostaną powiadomień z jobów,
- maintenance i backup automation mogą zostać pominięte.

Źródło logów:

```text
SQLAGENT.OUT
```

Repo dokumentuje, że zawiera m.in.:

- start/stop Agent,
- problemy z harmonogramami,
- operatorami,
- alertami.

---

# 4. Job enabled / disabled

Nie zakładaj, że brak wykonania oznacza awarię.

Sprawdź:

```text
msdb.dbo.sysjobs.enabled
```

DBACentralRepository ma osobny finding dla:

```text
DISABLED_JOBS
```

czyli jobów wyłączonych bez zaakceptowanego wyjątku.

To ważne, bo job może być wyłączony:

- świadomie podczas maintenance,
- przypadkowo,
- przez deployment,
- przez narzędzie patchingowe,
- po awarii.

---

# 5. Job did not run

Repo DBA Daily Pack ma heurystykę dla:

> jobs with schedule that have not executed in a while.

Analiza powinna rozdzielać:

```text
job failed
```

od:

```text
job never started
```

Dla „never started” sprawdź:

- job enabled,
- schedule enabled,
- przypięcie schedule do joba,
- next run,
- Agent service,
- restart Agent/hosta,
- zmiany w konfiguracji.

---

# 6. sysjobhistory

Główne źródło:

```text
msdb.dbo.sysjobhistory
```

Repo mapuje `run_status`:

```text
0 = Failed
1 = Succeeded
2 = Retry
3 = Canceled
4 = In-progress
```

Analizuj:

- `step_id = 0` — outcome całego joba,
- `step_id > 0` — konkretne kroki.

Najważniejsza zasada:

> znajdź **pierwszy rzeczywiście błędny krok**, nie zatrzymuj się na statusie całego joba.

---

# 7. Step message

Kolumna:

```text
message
```

w `sysjobhistory` często zawiera kluczowy kontekst:

- SQL error,
- PowerShell error,
- CmdExec exit code,
- SSIS failure,
- login failure,
- file/share problem,
- timeout.

Jeżeli komunikat jest skrócony lub niepełny, sprawdź również:

- output file kroku,
- SQL Agent log,
- ERRORLOG,
- log aplikacji/SSIS/PowerShell.

---

# 8. Long-running job

Nie każdy problem kończy się statusem Failed.

Job może:

```text
run forever
```

i formalnie nadal być aktywny.

Sprawdź:

- `msdb.dbo.sysjobactivity`,
- czas startu,
- obecny krok,
- aktywny request SQL,
- blocking,
- wait type,
- external process.

Powiązane:

- [Blocking](../blocking/)
- [Wait Statistics](../wait-statistics/)
- [CPU](../cpu/)
- [I/O](../io/)

---

# 9. Retry

Status:

```text
run_status = 2
```

oznacza retry.

Retry może być poprawnym mechanizmem odporności, ale:

> retry nie usuwa root cause.

Sprawdź:

- który krok retry'ował,
- ile razy,
- dlaczego,
- czy finalnie job zakończył się sukcesem,
- czy czas wykonania nie przekroczył SLA.

Repo zawiera też przykład świadomego scenariusza, gdzie część pracy wykonuje retry, ale finalny job jest oznaczony jako Failed.

---

# 10. Job owner

Owner joba ma znaczenie dla kontekstu bezpieczeństwa i zachowania kroków.

Sprawdź:

```text
msdb.dbo.sysjobs.owner_sid
```

Pytania:

- czy login ownera istnieje?
- czy jest enabled?
- czy ma wymagane prawa?
- czy job powinien mieć technicznego ownera zamiast konta użytkownika?
- czy po migracji login nie został osierocony?

Szczególnie po migracjach instancji owner może wskazywać login, który nie istnieje na nowym serwerze.

---

# 11. Proxy and Credential

Dla kroków PowerShell, CmdExec, SSIS i innych subsystemów kluczowe mogą być:

```text
Credential
Proxy
Subsystem
```

DBACentralRepository ma osobną kontrolę dla:

> jobs without proxy.

Sprawdź:

- czy proxy istnieje,
- czy credential istnieje,
- czy credential ma poprawne hasło,
- czy proxy ma dostęp do właściwego subsystemu,
- czy principal ma dostęp do proxy.

---

# 12. Security context

Nie diagnozuj:

```text
Access denied
```

wyłącznie z perspektywy swojego konta w SSMS.

Job może działać jako:

- SQL Agent service account,
- job owner,
- proxy/credential,
- login SQL,
- konto domenowe.

Zawsze ustal **rzeczywisty execution context**.

---

# 13. File system / share access

Typowy przypadek:

```text
job działa ręcznie
job fails w SQL Agent
```

często oznacza różnicę contextu bezpieczeństwa.

Sprawdź:

- NTFS ACL,
- share permissions,
- UNC path,
- konto SQL Agent/proxy,
- dostęp z serwera SQL.

Nie testuj tylko ze swojego desktopu.

---

# 14. Database context

Krok T-SQL może zawieść przez:

- złą database,
- database offline/restoring,
- brak user mapping,
- brak permission,
- default database loginu,
- zmianę nazwy bazy.

Repo ma SQLSTATE/Msg cheat sheet dla typowych komunikatów z jobów.

---

# 15. SQL Agent Error Log

Źródło:

```text
SQLAGENT.OUT
```

Użyj go gdy problem dotyczy:

- samego Agent,
- harmonogramów,
- operatorów,
- alertów,
- restartów,
- błędów infrastrukturalnych Agent.

To inna warstwa niż `sysjobhistory`.

---

# 16. Database Mail

Jeżeli job failed, ale alert nie przyszedł, problem może być oddzielny.

Repo dokumentuje:

```text
msdb.dbo.sysmail_event_log
msdb.dbo.sysmail_faileditems
```

Sprawdź osobno:

```text
job execution
```

i:

```text
notification delivery
```

Nie zakładaj, że brak maila oznacza brak błędu joba.

---

# 17. Operators and notifications

DBACentralRepository ma finding:

```text
JOBS_WITHOUT_NOTIFICATION
```

i rekomendację:

> przypisz aktywnego operatora i powiadomienie po błędzie.

Dla krytycznych jobów sprawdź:

- operator exists,
- operator enabled,
- email configured,
- notify_level_email,
- Database Mail works.

---

# 18. Critical jobs

Nie wszystkie joby mają ten sam poziom ryzyka.

Monitoring Zabbix w repo przewiduje osobne traktowanie krytycznych jobów.

Przykłady krytycznych:

- log backup,
- FULL backup,
- CHECKDB,
- replication agents,
- business-critical ETL,
- DR sync/maintenance.

Severity alertu powinna uwzględniać **impact**, nie tylko sam status Failed.

---

# 19. Missed schedule

Missed run jest często ważniejszy niż failed run.

Przykład:

```text
backup job never started
```

nie wygeneruje zwykłego „job failed”.

Dlatego monitoring powinien obejmować:

- failed,
- canceled,
- retry,
- no recent run,
- disabled,
- schedule disabled.

DBA Daily Pack i Zabbix w repo już idą w tym kierunku.

---

# 20. Job dependencies

SQL Agent nie ma automatycznie pełnej wiedzy o biznesowych zależnościach.

Przykład:

```text
Job A -> file export
Job B -> import file
Job C -> report
```

Jeżeli A failed, B może również failed lub — gorzej — zakończyć się sukcesem na starych danych.

Dokumentuj:

- upstream dependencies,
- downstream dependencies,
- expected artifacts,
- data freshness.

---

# 21. Job outcome can be misleading

Job może być oznaczony jako Succeeded, mimo że:

- krok wykonał `RAISERROR` z niską severity,
- PowerShell przechwycił wyjątek bez exit code,
- CmdExec zwrócił 0 mimo błędu logicznego,
- aplikacja wewnątrz joba zapisała błąd tylko do własnego logu.

Dlatego walidacja krytycznego joba powinna obejmować rezultat biznesowy/techniczny.

---

# 22. SQL Agent after migration

Po migracji instancji sprawdź:

- job owners,
- proxies,
- credentials,
- operators,
- Database Mail profiles,
- linked servers,
- file paths,
- shares,
- PowerShell modules,
- SSIS catalog/packages,
- schedules.

Sam skrypt joba może być identyczny, ale środowisko wykonawcze już nie.

---

# 23. Evidence to collect

Minimalny zestaw:

```text
Server:
Job name:
Job ID:

Job enabled:
Schedule enabled:
Expected run time:
Actual start time:
Actual end time:

Job outcome:
Failed step:
Step subsystem:
Step command:
Run status:
Retry count:
Message:

Job owner:
Proxy:
Credential:
Execution context:

SQL Agent service status:
SQLAGENT.OUT evidence:

Database Mail status:
Operator:
Notification status:

Related SQL request:
Blocking/waits:
External dependency:

Recent deployment/change:
Business impact:
```

---

# 24. Validation

Po poprawce sprawdź:

1. czy job startuje zgodnie z schedule,
2. czy przechodzi każdy krok,
3. czy rezultat techniczny jest poprawny,
4. czy retry count jest zgodny z oczekiwaniem,
5. czy downstream dependencies działają,
6. czy operator dostaje powiadomienie,
7. czy monitoring widzi prawidłowy status.

Nie kończ na:

```text
RunStatus = Succeeded
```

jeżeli job miał wytworzyć backup, plik, raport lub zmianę danych.

Zweryfikuj artifact/output.

---

# 25. Czego nie robić

## Nie diagnozuj tylko statusu całego joba

Znajdź pierwszy błędny krok.

## Nie zakładaj, że brak job history oznacza brak problemu

Job mógł w ogóle nie wystartować.

## Nie testuj dostępu tylko swoim kontem

Sprawdź execution context SQL Agent/proxy.

## Nie traktuj retry jako rozwiązania

Retry może tylko ukryć problem przejściowy.

## Nie zakładaj, że brak maila oznacza brak błędu

Database Mail jest osobnym komponentem.

## Nie używaj kont użytkowników jako trwałych ownerów krytycznych jobów

Migracje i odejście użytkownika mogą powodować problemy operacyjne.

## Nie ignoruj disabled jobs

Wyłączony job to potencjalnie cichy brak procesu.

---

# 26. Related troubleshooting

- [Backup / Restore](../backup-restore/)
- [Replication](../replication/)
- [Blocking](../blocking/)
- [Wait Statistics](../wait-statistics/)
- [CPU](../cpu/)
- [I/O](../io/)

---

# TL;DR

```text
Job problem
   |
   v
Agent running?
   |
   v
Job enabled?
   |
   v
Schedule enabled?
   |
   v
Did it start?
   |
   v
Which step failed?
   |
   v
What execution context?
   |
   v
Owner / proxy / credential
   |
   v
External dependency?
   |
   v
Retry?
   |
   v
Notification delivered?
   |
   v
Validate real output
```
