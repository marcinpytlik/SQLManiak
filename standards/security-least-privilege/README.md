# Standard: Security & Least Privilege

## Purpose

Zapewnić minimalne wymagane uprawnienia, ograniczyć zależność od ról uprzywilejowanych i utrzymać audytowalny model dostępu.

## Scope

- loginy serwerowe,
- users i role bazodanowe,
- konta aplikacyjne,
- konta usług,
- SQL Agent owner/proxy/credential,
- monitoring i automatyzacja DBA.

## Requirements

### Required

- Obowiązuje zasada least privilege.
- Uprawnienia są nadawane przez role tam, gdzie jest to praktyczne.
- Konta aplikacyjne nie są członkami `db_owner` bez zatwierdzonego wyjątku.
- Dostęp `sysadmin` jest ograniczony do kont rzeczywiście wymagających pełnej administracji.
- Właścicielami krytycznych baz/jobów nie są konta osobiste.
- Użytkownicy osieroceni są wykrywani i usuwani/naprawiani.
- `TRUSTWORTHY = OFF`, chyba że istnieje udokumentowany wyjątek.
- Klucze i certyfikaty wymagane do recovery są backupowane.
- TDE/szyfrowanie backupów jest stosowane zgodnie z polityką danych.
- Execution context SQL Agent jest jawnie kontrolowany przez owner/proxy/credential.

### Recommended

- Oddzielać role:
  - application runtime,
  - deployment,
  - monitoring,
  - DBA operations.
- Monitoring powinien korzystać z dedykowanego loginu z minimalnym zestawem praw.
- Dostępy administracyjne i wyjątki powinny mieć ownera, uzasadnienie i przegląd okresowy.
- Preferować gMSA dla usług Windows/SQL tam, gdzie środowisko to wspiera i jest to częścią architektury.

### Not allowed

- Nadawanie `sysadmin` jako szybkiej naprawy problemu permission.
- Konta współdzielone bez właściciela.
- Hasła/sekrety zapisane w repo.
- Trwałe konta osobiste jako owner jobów/baz.
- `TRUSTWORTHY ON` bez uzasadnienia.
- Szerokie GRANT-y bez określenia potrzeby biznesowej/technicznej.

## Default configuration

Nowy dostęp powinien być projektowany od:

```text
required action
→ required database/server scope
→ role
→ minimal permission set
→ validation
```

nie od wyboru szerokiej roli.

## Exceptions

Każdy wyjątek musi zawierać:

- principal,
- permission/role,
- uzasadnienie,
- ownera,
- ticket/change,
- termin przeglądu lub wygaśnięcia.

## Validation

- membership w server/database roles,
- explicit GRANT/DENY,
- orphaned users,
- database owner,
- TRUSTWORTHY,
- SQL Agent owner/proxy,
- stan TDE i kluczy/certyfikatów zgodnie z wymaganiami.

## Ownership

DBA + Security / właściciel systemu.

## Review cycle

- co najmniej kwartalnie,
- po migracji,
- po zmianie aplikacji,
- po zmianie zespołu/ownerów,
- po incydencie security.

## References

- [Database Standards](../../scripts/DBACentralRepository_v3/SQL_Server_Databases_13_Checklists_16_Standards.md)
- [Security Labs](../../labs/07-security/)
- [SQL Agent Troubleshooting](../../troubleshooting/sql-agent/)
