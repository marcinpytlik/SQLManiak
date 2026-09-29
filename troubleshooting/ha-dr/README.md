# Troubleshooting: HA / DR

HA/DR nie jest jednym mechanizmem.

W SQL Server trzeba najpierw ustalić, **która warstwa ochrony zawiodła**:

```text
WSFC / quorum
FCI
Availability Groups
listener / connectivity
replica synchronization
backup / restore
log shipping
replication
```

Najważniejsza zasada:

> **Nie diagnozuj „HA problem” jako jednego problemu. Najpierw rozpoznaj warstwę.**

---

# Diagnostic flow

```text
Availability / failover incident
            |
            v
What failed?
            |
   +--------+---------+-----------+
   |                  |           |
 WSFC/FCI             AG       DR path
   |                  |           |
   v                  v           v
quorum/node       role/sync    backup/log shipping
resources         listener     restore capability
network           queues       RPO/RTO
   |                  |           |
   +--------+---------+-----------+
            |
            v
        business impact
            |
            v
      restore service
            |
            v
       validate protection
```

---

# 1. Najpierw określ architekturę

Repo rozdziela:

## FCI

```text
Failover Cluster Instance
```

- HA na poziomie instancji,
- WSFC,
- współdzielony storage,
- jedna instancja przenoszona między węzłami.

## Availability Groups

```text
Always On Availability Groups
```

- ochrona na poziomie baz,
- repliki,
- synchronization,
- automatic/manual failover,
- opcjonalne readable secondaries.

## Backup / Restore

Ostatnia linia DR i recovery danych.

Powiązany moduł:

- [Backup / Restore](../backup-restore/)

Źródło przeglądowe:

- [SQL Server Components – HA/DR](../../docs/Inside_SQL_Server2022/19_SQLServer2022_Components.md)

---

# 2. First checks

1. Co jest niedostępne: instancja, listener, konkretna baza?
2. Czy problem dotyczy FCI czy AG?
3. Czy WSFC działa?
4. Czy quorum jest zachowane?
5. Jaki node jest właścicielem zasobów?
6. Jaka jest rola repliki AG?
7. Jaki jest stan synchronizacji baz?
8. Czy listener/VNN odpowiada?
9. Czy endpoint HADR działa?
10. Czy problem wystąpił po failover?
11. Czy backup/restore path nadal spełnia RPO/RTO?

---

# 3. Existing sources of truth

## FCI / WSFC

- [FCI Windows Server 2022 + SQL Server 2022](../../docs/FCI-Windows2022-SQL2022/)
- [FCI AddNode](../../docs/FCI-Windows2022-SQL2022/docs/howto/FCI-AddNode.md)
- [FCI Smoke Test](../../docs/FCI-Windows2022-SQL2022/scripts/tests/Smoke-Test.ps1)

## Monitoring

- [Zabbix HA prototypes](../../scripts/zabbix-mssql-monitoring/docs/inventory/02-prototypes-02.md)

Monitoring obejmuje m.in.:

- quorum state,
- quorum type,
- quorum members,
- replica connected state,
- replica role,
- synchronization health,
- log send queue,
- redo queue.

## Incident framework

- [PIOSEE](../../docs/PIOSEE/PIOSEE.md)

Repo zawiera przykład nieoczekiwanego failoveru FCI/AG z analizą:
- Event Viewer,
- cluster log,
- DMV HADR,
- network latency.

---

# 4. WSFC first

Dla FCI i wielu konfiguracji AG WSFC jest warstwą bazową.

Jeżeli klaster ma problem, SQL Server może być tylko symptomem.

Sprawdź:

```powershell
Get-Cluster
Get-ClusterNode
Get-ClusterGroup
Get-ClusterResource
Get-ClusterQuorum
```

Interesują Cię:

- node state,
- owner node,
- failed resources,
- quorum,
- witness,
- cluster networks.

---

# 5. Quorum

Repo monitoruje osobno:

```text
quorum state
quorum type
quorum members
number of quorum votes
```

Źródło:

- [Zabbix HA prototypes](../../scripts/zabbix-mssql-monitoring/docs/inventory/02-prototypes-02.md)

Quorum problem może spowodować niedostępność całego klastra.

Sprawdź:

- czy witness jest osiągalny,
- ile węzłów ma głos,
- czy członkowie quorum są online,
- czy po utracie node nadal istnieje większość.

---

# 6. FCI resource group

Dla FCI sprawdź grupę:

```text
SQL Server (<instance>)
```

oraz zasoby:

- SQL Server,
- SQL Server Agent,
- Network Name,
- IP Address,
- shared disks,
- zależności.

Problem może dotyczyć jednego resource, a nie całej instancji.

---

# 7. FCI owner node

Sprawdź:

```powershell
Get-ClusterGroup
```

i ustal, który node jest aktywny.

To ważne przy analizie:

- lokalnego TempDB,
- dostępności dysków,
- firewall,
- usług,
- ścieżek,
- lokalnych agentów.

Repo FCI jawnie rozróżnia lokalny TempDB i shared DATA/LOG.

---

# 8. Shared storage

FCI zależy od storage współdzielonego.

Sprawdź:

- stan Physical Disk resources,
- mount points / drive letters,
- connectivity storage,
- błędy System Event Log,
- latency,
- failover ownership.

Jeżeli storage jest wspólnym SPOF, sam failover node nie rozwiąże awarii storage.

---

# 9. Local TempDB in FCI

Repo FCI używa lokalnego:

```text
T:
```

dla TempDB na obu węzłach.

Po failover sprawdź:

- czy ścieżka istnieje na target node,
- czy konto SQL ma dostęp,
- czy rozmiar/config jest zgodny,
- czy instancja może utworzyć TempDB.

Problem lokalnego TempDB może uniemożliwić poprawny start SQL po failover.

---

# 10. FCI smoke test

Repo zawiera:

- [Smoke-Test.ps1](../../docs/FCI-Windows2022-SQL2022/scripts/tests/Smoke-Test.ps1)

Test robi:

```text
Move-ClusterGroup
        |
        v
wait
        |
        v
sqlcmd through VNN
        |
        v
SELECT @@SERVERNAME
```

To jest dobry wzorzec walidacji:

> failover nie jest zaliczony tylko dlatego, że grupa przeniosła się do innego node.

Trzeba potwierdzić połączenie przez nazwę wirtualną.

---

# 11. VNN / listener / DNS

Jeżeli zasoby SQL są online, ale klient nadal nie łączy się, sprawdź:

- DNS,
- VNN/listener,
- IP,
- TCP port,
- firewall,
- RegisterAllProvidersIP,
- MultiSubnetFailover po stronie klienta, jeśli dotyczy.

Rozdziel:

```text
SQL is online
```

od:

```text
application can connect
```

To nie jest to samo.

---

# 12. Availability Group role

Monitoring repo zwraca:

```text
Primary
Secondary
Resolving
```

dla replica role.

Stan:

```text
RESOLVING
```

jest ważnym symptomem problemów z:
- WSFC,
- connectivity,
- role transition.

Nie diagnozuj tylko na podstawie jednej bazy.

Sprawdź stan repliki i grupy.

---

# 13. Replica connected state

Monitoring Zabbix zawiera:

```text
replica connected state
```

Jeżeli secondary traci połączenie z primary, sprawdź:

- endpoint,
- firewall,
- DNS,
- network,
- service account,
- certificate, jeśli używany,
- SQL error log.

Repo katalogu błędów zawiera także:

```text
35250 – AG connection lost to replica
```

jako sygnał do diagnostyki endpoint/HADR/network.

---

# 14. Synchronization health

Monitoring repo obejmuje:

```text
synchronization_health
```

Nie wystarczy wiedzieć, że replica jest connected.

Baza może być:

- synchronized,
- synchronizing,
- not synchronizing,
- suspended.

Analizuj per baza.

---

# 15. Log send queue

Repo monitoruje:

```text
log_send_queue_size
```

To backlog logu na primary oczekujący na wysłanie do secondary.

Wzrost może wskazywać m.in. na:

- ograniczenie sieci,
- problem secondary,
- wysoką generację logu,
- endpoint/connectivity,
- throttling.

Korelacja jest ważniejsza niż pojedyncza wartość.

---

# 16. Redo queue

Repo monitoruje:

```text
redo_queue_size
```

To log już dostarczony do secondary, ale jeszcze niezastosowany.

Duży redo queue może oznaczać:

- secondary nie nadąża z redo,
- storage secondary,
- duży workload logowy,
- zasoby secondary.

To inny problem niż log send queue.

---

# 17. Log send vs redo

Uproszczony model:

```text
Primary
   |
   | log send queue
   v
network
   |
   v
Secondary
   |
   | redo queue
   v
database state
```

Jeżeli:

```text
log send queue ↑
redo queue low
```

patrz bardziej na transport.

Jeżeli:

```text
log send queue low
redo queue ↑
```

patrz bardziej na secondary redo/resources.

---

# 18. Synchronous vs asynchronous

Przy synchronous commit problemy secondary/network mogą wpływać na latency commitów primary.

Przy asynchronous commit większy backlog wpływa przede wszystkim na możliwe RPO przy failover.

Dlatego diagnostyka musi znać:

```text
availability mode
failover mode
```

Nie oceniaj backlogu bez kontekstu trybu repliki.

---

# 19. Automatic failover

Automatic failover wymaga spełnienia określonych warunków konfiguracji i zdrowia.

Po nieoczekiwanym failover nie kończ analizy na:

> AG zmieniło primary.

Ustal:

- dlaczego failover nastąpił,
- czy WSFC utracił node,
- czy resource health wykrył problem,
- czy był heartbeat timeout,
- czy wystąpił restart/usługa,
- czy sieć była niestabilna.

---

# 20. Cluster logs

Repo dokumentuje:

```powershell
cluster log /g
```

Źródło:

- [SQL Server Logs overview](../../docs/Inside_SQL_Server2022/03_SQLServer2022_LogsFull.md)

Przy problemach failover koreluj:

```text
Cluster log
Windows System/Application
SQL ERRORLOG
AG DMV
network evidence
```

---

# 21. Event 1135 / node lost communication

Repo PIOSEE zawiera przykład:

```text
Event 1135
Cluster node lost communication
```

oraz:

```text
heartbeat timeout
```

To przykład, gdzie SQL Server jest skutkiem problemu klastra/sieci.

Nie zwiększaj timeoutów bez zrozumienia jakości sieci.

---

# 22. HADR waits

Repo klasyfikuje:

```text
HADR_*
```

jako osobną kategorię waitów.

Źródło:

- [Wait categories wrapper](../../labs/08-dmv/scripts/per_certificate/05m_wrapper_dba.usp_top_waits_categories.sql)

Powiązany moduł:

- [Wait Statistics](../wait-statistics/)

HADR wait jest wskazówką, nie gotową diagnozą.

---

# 23. Failover validation

Po planowanym lub awaryjnym failover sprawdź:

## FCI

- grupa online,
- SQL resource online,
- Agent online,
- VNN/IP online,
- shared disks online,
- TempDB działa,
- aplikacja łączy się po VNN.

## AG

- primary role poprawna,
- secondary connected,
- synchronization health,
- bazy online,
- listener działa,
- send/redo queues maleją lub są stabilne.

---

# 24. Failback is a separate change

Nie rób automatycznego failback tylko dlatego, że poprzedni node wrócił.

Najpierw oceń:

- root cause,
- stabilność node,
- storage,
- network,
- patch level,
- business window.

Failback to osobna operacja z własnym ryzykiem.

---

# 25. HA is not DR

FCI zwykle chroni przed awarią node/instancji, ale niekoniecznie przed utratą shared storage.

AG zwiększa odporność przez kopię danych na innym SQL Server, ale nadal może wymagać backupów.

Dlatego:

```text
HA
!=
DR
```

i:

```text
AG
!=
backup
```

Powiązany moduł:

- [Backup / Restore](../backup-restore/)

---

# 26. RPO / RTO after failover

Po awarii sprawdź nie tylko techniczny stan.

Zapisz:

```text
incident start
service unavailable from
failover start
service restored
data loss
RPO achieved
RTO achieved
```

HA/DR ma sens tylko w odniesieniu do wymagań biznesowych.

---

# 27. Monitoring

Repo Zabbix już zbiera:

## WSFC

- quorum state,
- quorum type,
- quorum member state,
- votes.

## AG

- connected state,
- join state,
- operational state,
- recovery health,
- role,
- synchronization health.

## Per database

- log send queue,
- redo queue.

To jest bardzo dobra warstwa obserwowalności HA/DR.

---

# 28. Evidence to collect

Minimalny zestaw:

```text
Incident timestamp:
Business impact:

Architecture:
FCI / AG / both:

WSFC state:
Quorum type:
Quorum state:
Witness:
Node states:
Owner node:

Cluster resource states:
Failed resources:

FCI VNN/IP:
Shared storage:
TempDB path:

AG name:
Replica role:
Connected state:
Synchronization health:
Availability mode:
Failover mode:

Database state:
Log send queue:
Redo queue:

Listener:
DNS:
TCP connectivity:

SQL ERRORLOG:
Cluster log:
Windows Event Log:

Failover timestamp:
Recovery timestamp:

RPO:
RTO:
Data loss:
```

---

# 29. Czego nie robić

## Nie mieszaj FCI z AG

To inne warstwy ochrony.

## Nie diagnozuj tylko SQL Server

Problem może być w WSFC, storage, quorum, DNS lub network.

## Nie uznawaj resource ONLINE za pełny sukces

Sprawdź connectivity klienta.

## Nie zwiększaj heartbeat timeoutów w ciemno

Najpierw zbierz evidence sieciowe.

## Nie ignoruj send/redo queues po failover

Mogą pokazać, że secondary nadal nie nadąża.

## Nie wykonuj failback automatycznie

Najpierw ustal root cause i stabilność.

## Nie traktuj HA jako zamiennika backupu

Backup/restore pozostaje elementem DR.

---

# 30. Related troubleshooting

- [Backup / Restore](../backup-restore/)
- [Wait Statistics](../wait-statistics/)
- [I/O](../io/)
- [CPU](../cpu/)
- [SQL Agent](../sql-agent/)
- [Replication](../replication/)

---

# TL;DR

```text
HA/DR incident
      |
      v
Which layer?
      |
 +----+----+------+
 |         |      |
WSFC/FCI   AG    DR
 |         |      |
quorum    role   backup
node      sync   restore
storage   queues RPO/RTO
 |         |      |
 +----+----+------+
      |
      v
restore service
      |
      v
validate protection
      |
      v
root cause
```
