# Inventory — discovery i item prototypes

Łącznie discovery rules: **10**.

> Część 2 z 2.

## Non-local database discovery

- Key: `mssql.non.local.db.discovery`
- Typ: `DEPENDENT`
- Prototypes: **2**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Log queue size | `mssql.non-local_db.log_send_queue_size["{#GROUP_NAME}*{#REPLICA_NAME}*{#DBNAME}"]` | dependent z `mssql.nonlocal.db.get[...]` | Log records on primary not yet sent to secondary databases. |
| MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Redo log queue size | `mssql.non-local_db.redo_queue_size["{#GROUP_NAME}*{#REPLICA_NAME}*{#DBNAME}"]` | dependent z `mssql.nonlocal.db.get[...]` | Log records on secondary not yet redone. |

## Quorum discovery

- Key: `mssql.quorum.discovery`
- Typ: `DEPENDENT`
- Prototypes: **2**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL Cluster '{#CLUSTER_NAME}': Quorum state | `mssql.quorum.state.[{#CLUSTER_NAME}]` | dependent z `mssql.quorum.get[...]` | WSFC quorum state. |
| MSSQL Cluster '{#CLUSTER_NAME}': Quorum type | `mssql.quorum.type.[{#CLUSTER_NAME}]` | dependent z `mssql.quorum.get[...]` | WSFC quorum type. |

## Quorum members discovery

- Key: `mssql.quorum.member.discovery`
- Typ: `DEPENDENT`
- Prototypes: **3**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL Cluster member '{#MEMBER_NAME}': Member state | `mssql.quorum_members.member_state.[{#MEMBER_NAME}]` | dependent z `mssql.quorum.member.get[...]` | Online/offline member state. |
| MSSQL Cluster member '{#MEMBER_NAME}': Member type | `mssql.quorum_members.member_type.[{#MEMBER_NAME}]` | dependent z `mssql.quorum.member.get[...]` | WSFC node / disk / file-share / cloud witness type. |
| MSSQL Cluster member '{#MEMBER_NAME}': Number of quorum votes | `mssql.quorum_members.number_of_quorum_votes.[{#MEMBER_NAME}]` | dependent z `mssql.quorum.member.get[...]` | Number of quorum votes. |

## Replication discovery

- Key: `mssql.replica.discovery`
- Typ: `DEPENDENT`
- Prototypes: **7**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Connected state | `mssql.replica.connected_state["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Secondary-to-primary connection state. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Is local | `mssql.replica.is_local["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Whether availability replica is local. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Join state | `mssql.replica.join_state["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Replica join state. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | `mssql.replica.operational_state["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Current operational state. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Recovery health | `mssql.replica.recovery_health["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Rollup of database recovery health. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Role | `mssql.replica.role["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Resolving / Primary / Secondary role. |
| MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Sync health | `mssql.replica.synchronization_health["{#GROUP_NAME}_{#REPLICA_NAME}"]` | dependent z `mssql.replica.get[...]` | Availability-replica synchronization health. |

## MSSQL filegroup discovery

- Key: `mssql.filegroup.discovery`
- Typ: `DEPENDENT`
- Prototypes: **4**

| Prototype | Key | Jak | Co mierzy / sens |
|---|---|---|---|
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': allocated size | `mssql.db.filegroup.allocated_mb["{#DBNAME}","{#FILEGROUP}"]` | dependent z `sqlmaniak_filegroups` | Internal allocated filegroup space. |
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': used size | `mssql.db.filegroup.used_mb["{#DBNAME}","{#FILEGROUP}"]` | dependent z `sqlmaniak_filegroups` | Internal used filegroup space. |
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': free size | `mssql.db.filegroup.free_mb["{#DBNAME}","{#FILEGROUP}"]` | dependent z `sqlmaniak_filegroups` | Allocated-but-unused filegroup space, not filesystem free. |
| MSSQL DB '{#DBNAME}' FG '{#FILEGROUP}': used | `mssql.db.filegroup.used_pct["{#DBNAME}","{#FILEGROUP}"]` | dependent z `sqlmaniak_filegroups` | Percent of allocated filegroup space used. |
