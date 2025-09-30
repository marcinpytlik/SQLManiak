# 🔒 SQL Server 2022 – Security Hardening

## Powinstalacyjne kroki bezpieczeństwa
- Wyłącz zbędne funkcje:
  - xp_cmdshell, OLE Automation, AdHoc Distributed Queries.
- Ustaw Surface Area Configuration tylko na potrzebne komponenty.
- Wymuś szyfrowanie połączeń (Force Encryption w SQL Server Configuration Manager).
- Włącz Transparent Data Encryption (TDE) dla baz krytycznych.
- Włącz Audyt SQL Server – failed logins, DDL changes.
- Ogranicz sysadmin role tylko do kont DBA.
