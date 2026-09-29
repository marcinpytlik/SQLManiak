# Transactional Replication Incident Recovery — RUNBOOK

## 1. Napraw zależność

Usuń connectivity/permission/storage/schema problem.

## 2. Uruchom właściwego agenta

Nie restartuj wszystkiego bez potrzeby.

## 3. Obserwuj backlog

Pending powinien maleć.

## 4. Zweryfikuj dane

Sprawdź krytyczne artykuły i latency.

## 5. Reinit tylko jeśli konieczne

Zaplanuj snapshot/reseed jako osobną kontrolowaną operację.

Po wykonaniu przejdź do [VALIDATION.md](VALIDATION.md).
