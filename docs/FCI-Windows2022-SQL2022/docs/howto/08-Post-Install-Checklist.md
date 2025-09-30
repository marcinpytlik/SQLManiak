# Post‑install checklist (skrót)

- [ ] SPN dla VNN (jeśli setup nie ustawił):
  ```powershell
  setspn -S MSSQLSvc/SQLSRV-FCI:1433 sqlmaniak\gmsa_sql$
  setspn -S MSSQLSvc/SQLSRV-FCI.sqlmaniak.blog:1433 sqlmaniak\gmsa_sql$
  ```
- [ ] Wymuś TCP 1433 i zrestartuj zasób SQL: `scripts/sql/Set-StaticTcp1433.ps1`
- [ ] Włącz IFI/LPIM/TLS wg polityki
- [ ] Failover w obie strony i pomiar RTO (ADR)
