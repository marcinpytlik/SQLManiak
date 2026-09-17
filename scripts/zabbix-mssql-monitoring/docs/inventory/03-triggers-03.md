# Inwentarz — triggery i prototypy triggerów

Łącznie w szablonie: **76**.

> Część 3 z 3 — Availability Groups, mirroring i kolejki synchronizacji.

| Źródło | Trigger | Poziom | Warunek | Opis |
|---|---|---|---|---|
| prototype: MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': State | MSSQL: AG '{#GROUP_NAME}' Local DB '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `WARNING` | `last(/SQLManiak MSSQL by Zabbix agent 2/mssql.local_db.state["{#DBNAME}"])>0` | Lokalna baza Availability Group znajduje się w stanie innym niż roboczy. |
| prototype: MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Synchronization health | MSSQL: AG '{#GROUP_NAME}' Local DB '{#DBNAME}': "{#DBNAME}" is Not healthy | `HIGH` | `last(...synchronization_health...)=0` | Lokalna baza Availability Group nie synchronizuje się prawidłowo. |
| prototype: MSSQL AG '{#GROUP_NAME}' Local DB '{#DBNAME}': Synchronization health | MSSQL: AG '{#GROUP_NAME}' Local DB '{#DBNAME}': "{#DBNAME}" is Partially healthy | `AVERAGE` | `last(...synchronization_health...)=1` | Lokalna baza Availability Group jest tylko częściowo zdrowa pod względem synchronizacji. |
| prototype: MSSQL Mirroring '{#DBNAME}': State | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `WARNING` | `last(...mirroring.state...)=3` | Mirroring znajduje się w stanie oczekiwania na failover. |
| prototype: MSSQL Mirroring '{#DBNAME}': State | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `HIGH` | `last(...mirroring.state...)=5` | Partnerzy mirroringu nie są zsynchronizowani. |
| prototype: MSSQL Mirroring '{#DBNAME}': State | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" is {ITEM.VALUE} | `INFO` | stan między `0` i `2` | Informacyjny stan mirroringu, np. suspended, disconnected lub synchronizing. |
| prototype: MSSQL Mirroring '{#DBNAME}': Witness state | MSSQL: Mirroring '{#DBNAME}': "{#DBNAME}" Witness is disconnected | `WARNING` | `last(...witness_state...)=2` | Witness mirroringu jest rozłączony. |
| prototype: MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Log queue size | MSSQL: AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Log queue size is growing | `HIGH` | najnowsza wartość kolejki > poprzednia i > 0 | Kolejka wysyłania logu po stronie primary rośnie, czyli replika secondary nie nadąża z odbiorem rekordów logu. |
| prototype: MSSQL AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Redo log queue size | MSSQL: AG '{#GROUP_NAME}' Non-Local DB '*{#REPLICA_NAME}*{#DBNAME}': Redo log queue size is growing | `HIGH` | najnowsza wartość redo queue > poprzednia i > 0 | Kolejka redo po stronie secondary rośnie, czyli zastosowanie odebranych rekordów logu nie nadąża. |
| discovery: Replication discovery | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is disconnected | `WARNING` | `connected_state=0` z uwzględnieniem roli repliki | Replika Availability Group jest rozłączona. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is {ITEM.VALUE} | `WARNING` | stan operacyjny pending/offline | Replika znajduje się w stanie pending lub offline. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is {ITEM.VALUE} | `AVERAGE` | `operational_state=4` | Replika znajduje się w stanie failed. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Operational state | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is {ITEM.VALUE} | `HIGH` | `operational_state=5` | Replika jest w stanie failed i jednocześnie brak quorum. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Recovery health | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} Recovery in progress | `INFO` | `recovery_health=0` | Co najmniej jedna dołączona baza na replice nie jest jeszcze Online. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Sync health | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is Not healthy | `AVERAGE` | `synchronization_health=0` | Co najmniej jedna dołączona baza nie synchronizuje się prawidłowo. |
| prototype: MSSQL AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': Sync health | MSSQL: AG '{#GROUP_NAME}' Replica '{#REPLICA_NAME}': {#REPLICA_NAME} is Partially healthy | `WARNING` | `synchronization_health=1` | Kondycja synchronizacji repliki jest częściowo prawidłowa. |
