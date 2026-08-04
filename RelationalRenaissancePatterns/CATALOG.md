# Katalog wzorców


## 01-Schema-Evolution

- [Expand–Migrate–Contract](01-Schema-Evolution/01-Expand-Migrate-Contract/README.md) — `READY`
- [Dual Write](01-Schema-Evolution/02-Dual-Write/README.md) — `STARTER`
- [Shadow Column](01-Schema-Evolution/03-Shadow-Column/README.md) — `READY`
- [Backfill in Batches](01-Schema-Evolution/04-Backfill-in-Batches/README.md) — `READY`
- [Compatibility View](01-Schema-Evolution/05-Compatibility-View/README.md) — `STARTER`
- [Parallel Table](01-Schema-Evolution/06-Parallel-Table/README.md) — `STARTER`
- [Blue-Green Database Deployment](01-Schema-Evolution/07-Blue-Green-Database/README.md) — `ADVANCED`
- [Feature Flag for Schema Change](01-Schema-Evolution/08-Feature-Flag-Schema/README.md) — `ADVANCED`

## 02-Data-Modeling

- [Table per Hierarchy](02-Data-Modeling/01-TPH/README.md) — `STARTER`
- [Table per Type](02-Data-Modeling/02-TPT/README.md) — `STARTER`
- [Table per Concrete Type](02-Data-Modeling/03-TPC/README.md) — `STARTER`
- [Adjacency List](02-Data-Modeling/04-Adjacency-List/README.md) — `STARTER`
- [Closure Table](02-Data-Modeling/05-Closure-Table/README.md) — `STARTER`
- [Materialized Path](02-Data-Modeling/06-Materialized-Path/README.md) — `STARTER`
- [Polymorphic Association](02-Data-Modeling/07-Polymorphic-Association/README.md) — `STARTER`
- [Association Table](02-Data-Modeling/08-Association-Table/README.md) — `STARTER`
- [Subtype Table](02-Data-Modeling/09-Subtype-Table/README.md) — `STARTER`
- [Party Model](02-Data-Modeling/10-Party-Model/README.md) — `STARTER`

## 03-History-Audit

- [Audit Trail](03-History-Audit/01-Audit-Trail/README.md) — `STARTER`
- [Temporal Tables](03-History-Audit/02-Temporal-Tables/README.md) — `READY`
- [Effective Dating](03-History-Audit/03-Effective-Dating/README.md) — `STARTER`
- [Slowly Changing Dimension Type 1](03-History-Audit/04-SCD-Type-1/README.md) — `STARTER`
- [Slowly Changing Dimension Type 2](03-History-Audit/05-SCD-Type-2/README.md) — `STARTER`
- [Append-Only Model](03-History-Audit/06-Append-Only/README.md) — `STARTER`
- [Event Sourcing](03-History-Audit/07-Event-Sourcing/README.md) — `STARTER`
- [Snapshot Pattern](03-History-Audit/08-Snapshot/README.md) — `STARTER`

## 04-Deletion-Retention

- [Hard Delete](04-Deletion-Retention/01-Hard-Delete/README.md) — `STARTER`
- [Soft Delete](04-Deletion-Retention/02-Soft-Delete/README.md) — `READY`
- [Soft Delete with Filtered Unique Index](04-Deletion-Retention/03-Soft-Delete-Filtered-Unique/README.md) — `READY`
- [Archive then Delete](04-Deletion-Retention/04-Archive-Then-Delete/README.md) — `STARTER`
- [Tombstone Record](04-Deletion-Retention/05-Tombstone/README.md) — `STARTER`
- [Retention Policy](04-Deletion-Retention/06-Retention-Policy/README.md) — `STARTER`
- [Partition Switching for Purge](04-Deletion-Retention/07-Partition-Switching-Purge/README.md) — `STARTER`

## 05-Concurrency-Integrity

- [Optimistic Concurrency](05-Concurrency-Integrity/01-Optimistic-Concurrency/README.md) — `READY`
- [Pessimistic Concurrency](05-Concurrency-Integrity/02-Pessimistic-Concurrency/README.md) — `STARTER`
- [Compare and Swap](05-Concurrency-Integrity/03-Compare-And-Swap/README.md) — `STARTER`
- [Idempotent Write](05-Concurrency-Integrity/04-Idempotent-Write/README.md) — `STARTER`
- [Idempotency Key](05-Concurrency-Integrity/05-Idempotency-Key/README.md) — `READY`
- [Unique Constraint as Guard](05-Concurrency-Integrity/06-Unique-Constraint-Guard/README.md) — `STARTER`
- [Check Constraint as Domain Rule](05-Concurrency-Integrity/07-Check-Constraint-Domain/README.md) — `STARTER`
- [Application Lock](05-Concurrency-Integrity/08-Application-Lock/README.md) — `READY`
- [Queue-Based Serialization](05-Concurrency-Integrity/09-Queue-Serialization/README.md) — `STARTER`

## 06-Integration

- [Transactional Outbox](06-Integration/01-Transactional-Outbox/README.md) — `READY`
- [Inbox Pattern](06-Integration/02-Inbox/README.md) — `STARTER`
- [Change Data Capture](06-Integration/03-Change-Data-Capture/README.md) — `STARTER`
- [Change Tracking](06-Integration/04-Change-Tracking/README.md) — `STARTER`
- [Polling Publisher](06-Integration/05-Polling-Publisher/README.md) — `STARTER`
- [Saga Pattern](06-Integration/06-Saga/README.md) — `ADVANCED`
- [Compensating Transaction](06-Integration/07-Compensating-Transaction/README.md) — `STARTER`
- [Data Ownership per Service](06-Integration/08-Data-Ownership/README.md) — `STARTER`
- [Database per Service](06-Integration/09-Database-per-Service/README.md) — `ADVANCED`
- [Shared Database Anti-Pattern](06-Integration/10-Shared-Database-Antipattern/README.md) — `STARTER`
- [Anti-Corruption Layer](06-Integration/11-Anti-Corruption-Layer/README.md) — `STARTER`

## 07-Performance

- [Covering Index](07-Performance/01-Covering-Index/README.md) — `STARTER`
- [Filtered Index](07-Performance/02-Filtered-Index/README.md) — `READY`
- [Partitioning](07-Performance/03-Partitioning/README.md) — `STARTER`
- [Hot and Cold Data Separation](07-Performance/04-Hot-Cold-Separation/README.md) — `STARTER`
- [Archival Table](07-Performance/05-Archival-Table/README.md) — `STARTER`
- [Denormalization for Read](07-Performance/06-Denormalization-for-Read/README.md) — `STARTER`
- [Materialized Aggregate](07-Performance/07-Materialized-Aggregate/README.md) — `STARTER`
- [Indexed View](07-Performance/08-Indexed-View/README.md) — `STARTER`
- [Precomputed Summary](07-Performance/09-Precomputed-Summary/README.md) — `STARTER`
- [Read Model](07-Performance/10-Read-Model/README.md) — `STARTER`
- [Keyset Pagination](07-Performance/11-Keyset-Pagination/README.md) — `READY`
- [Write Sharding](07-Performance/12-Write-Sharding/README.md) — `ADVANCED`
- [Read Replicas](07-Performance/13-Read-Replicas/README.md) — `ADVANCED`
- [Queue Table Pattern](07-Performance/14-Queue-Table/README.md) — `STARTER`

## 08-Security

- [Module Signing](08-Security/01-Module-Signing/README.md) — `READY`
- [EXECUTE AS](08-Security/02-Execute-As/README.md) — `STARTER`
- [Ownership Chaining](08-Security/03-Ownership-Chaining/README.md) — `STARTER`
- [Row-Level Security](08-Security/04-Row-Level-Security/README.md) — `READY`
- [Dynamic Data Masking](08-Security/05-Dynamic-Data-Masking/README.md) — `STARTER`
- [Separate Migration and Runtime Accounts](08-Security/06-Separate-Migration-Runtime/README.md) — `STARTER`
- [Least Privilege](08-Security/07-Least-Privilege/README.md) — `STARTER`
- [Security Definer Procedure](08-Security/08-Security-Definer-Procedure/README.md) — `STARTER`
- [Column-Level Encryption](08-Security/09-Column-Encryption/README.md) — `STARTER`
- [Envelope Encryption](08-Security/10-Envelope-Encryption/README.md) — `STARTER`
- [Immutable Audit Log](08-Security/11-Immutable-Audit-Log/README.md) — `STARTER`