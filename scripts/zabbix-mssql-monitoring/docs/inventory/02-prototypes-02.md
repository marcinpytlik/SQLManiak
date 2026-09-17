# Inwentarz — reguły wykrywania i prototypy itemów

Łącznie reguł wykrywania: **10**.

> Część 2 z 2 — non-local DB, quorum, repliki i filegroupy.

## Wykrywanie baz non-local w Availability Groups

- Klucz: `mssql.non.local.db.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **2**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Log queue size | `mssql.non-local_db.log_send_queue_size["{#GROUP_NAME}*{#REPLICA_NAME}*{#DBNAME}"]` | item zależny od `mssql.nonlocal.db.get[...]` | Rozmiar kolejki rekordów logu na primary, które nie zostały jeszcze wysłane do bazy secondary. |
| MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Redo log queue size | `mssql.non-local_db.redo_queue_size["{#GROUP_NAME}*{#REPLICA_NAME}*{#DBNAME}"]` | item zależny od `mssql.nonlocal.db.get[...]` | Rozmiar kolejki rekordów logu na secondary, które zostały odebrane, ale nie zostały jeszcze zastosowane przez redo. |

## Wykrywanie quorum

- Klucz: `mssql.quorum.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **2**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL Cluster '{#CLUSTER_NAME}': Quorum state | `mssql.quorum.state.[{#CLUSTER_NAME}]` | item zależny od `mssql.quorum.get[...]` | Aktualny stan quorum Windows Server Failover Cluster. |
| MSSQL Cluster '{#CLUSTER_NAME}': Quorum type | `mssql.quorum.type.[{#CLUSTER_NAME}]` | item zależny od `mssql.quorum.get[...]` | Typ konfiguracji quorum WSFC. |

## Wykrywanie członków quorum

- Klucz: `mssql.quorum.member.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **3**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL Cluster member '{#MEMBER_NAME}': Member state | `mssql.quorum_members.member_state.[{#MEMBER_NAME}]` | item zależny od `mssql.quorum.member.get[...]` | Stan członka quorum, np. online lub offline. |
| MSSQL Cluster member '{#MEMBER_NAME}': Member type | `mssql.quorum_members.member_type.[{#MEMBER_NAME}]` | item zależny od `mssql.quorum.member.get[...]` | Typ członka quorum, np. węzeł WSFC, dysk, file-share witness lub cloud witness. |
| MSSQL Cluster member '{#MEMBER_NAME}': Number of quorum votes | `mssql.quorum_members.number_of_quorum_votes.[{#MEMBER_NAME}]` | item zależny od `mssql.quorum.member.get[...]` | Liczba głosów quorum przypisana do danego członka. |

## Wykrywanie replik Availability Groups

- Klucz: `mssql.replica.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **7**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Connected state | `mssql.replica.connected_state["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Stan połączenia repliki secondary z primary. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Is local | `mssql.replica.is_local["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Informacja, czy dana replika Availability Group jest lokalna dla monitorowanej instancji. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Join state | `mssql.replica.join_state["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Stan dołączenia repliki do Availability Group. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | `mssql.replica.operational_state["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Aktualny stan operacyjny repliki. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Recovery health | `mssql.replica.recovery_health["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Zbiorcza kondycja recovery baz należących do repliki. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Role | `mssql.replica.role["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Rola repliki: Resolving, Primary albo Secondary. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Sync health | `mssql.replica.synchronization_health["{#GROUP_NAME}_{#REPLICA_NAME}"]` | item zależny od `mssql.replica.get[...]` | Kondycja synchronizacji repliki Availability Group. |

## Wykrywanie filegroupów MSSQL

- Klucz: `mssql.filegroup.discovery`
- Typ: `DEPENDENT`
- Liczba prototypów: **4**

| Prototyp | Klucz | Sposób zbierania | Co mierzy / znaczenie |
|---|---|---|---|
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': allocated size | `mssql.db.filegroup.allocated_mb["{#DBNAME}","{#FILEGROUP}"]` | item zależny od `sqlmaniak_filegroups` | Łączna zaalokowana przestrzeń plików należących do filegroupy. |
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': used size | `mssql.db.filegroup.used_mb["{#DBNAME}","{#FILEGROUP}"]` | item zależny od `sqlmaniak_filegroups` | Przestrzeń faktycznie używana wewnątrz filegroupy. |
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': free size | `mssql.db.filegroup.free_mb["{#DBNAME}","{#FILEGROUP}"]` | item zależny od `sqlmaniak_filegroups` | Przestrzeń zaalokowana w plikach filegroupy, ale jeszcze niewykorzystana przez obiekty bazy. Nie jest to wolne miejsce na filesystemie. |
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': used | `mssql.db.filegroup.used_pct["{#DBNAME}","{#FILEGROUP}"]` | item zależny od `sqlmaniak_filegroups` | Procent wykorzystania aktualnie zaalokowanej przestrzeni filegroupy. |
