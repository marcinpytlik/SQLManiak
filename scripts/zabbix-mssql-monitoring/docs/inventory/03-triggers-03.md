# Inventory — triggery i trigger prototypes

Łącznie: **76**.

| Źródło | Trigger | Severity | Warunek | Opis |
|---|---|---|---|---|

> Część 3.

| prototype: MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': State | MSSQL: AG '{#GROUP_NAME}' Local DB '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `WARNING` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.local_db.state["{#DBNAME}"])>0` | Local availability database has a non-working state. |
| prototype: MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Synchronization health | MSSQL: AG '{#GROUP_NAME}' Local DB '{#DBNAME}': "{#DBNAME}" is Not healthy | `HIGH` | `last(...synchronization_health...)=0` | Local availability DB not synchronizing. |
| prototype: MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Synchronization health | MSSQL: AG '{#GROUP_NAME}' Local DB '{#DBNAME}': "{#DBNAME}" is Partially healthy | `AVERAGE` | `last(...synchronization_health...)=1` | Local availability DB partially healthy. |
| prototype: MSSQL Mirroring '{#DBNAME}': State | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `WARNING` | `last(...mirroring.state...)=3` | Pending failover. |
| prototype: MSSQL Mirroring '{#DBNAME}': State | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `HIGH` | `last(...mirroring.state...)=5` | Partners not synchronized. |
| prototype: MSSQL Mirroring '{#DBNAME}': State | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `INFO` | `state between 0 and 2` | Suspended/disconnected/synchronizing informational state. |
| prototype: MSSQL Mirroring '{#DBNAME}': Witness state | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" Witness is disconnected | `WARNING` | `last(...witness_state...)=2` | Mirroring witness disconnected. |
| prototype: MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Log queue size | MSSQL: AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Log queue size is growing | `HIGH` | latest log queue > previous and positive | Primary log send queue is growing. |
| prototype: MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Redo log queue size | MSSQL: AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Redo log queue size is growing | `HIGH` | latest redo queue > previous and positive | Secondary redo queue is growing. |
| discovery: Replication discovery | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is disconnected | `WARNING` | connected_state=0 with role context | Availability replica disconnected. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is {ITEM.VALUE} | `WARNING` | operational state pending/offline | Replica pending/offline. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is {ITEM.VALUE} | `AVERAGE` | operational_state=4 | Replica failed. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is {ITEM.VALUE} | `HIGH` | operational_state=5 | Replica failed, no quorum. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Recovery health | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} Recovery in progress | `INFO` | recovery_health=0 | At least one joined DB not Online. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Sync health | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is Not healthy | `AVERAGE` | synchronization_health=0 | At least one joined DB not synchronizing. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Sync health | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is Partially healthy | `WARNING` | synchronization_health=1 | Replica synchronization partially healthy. |
