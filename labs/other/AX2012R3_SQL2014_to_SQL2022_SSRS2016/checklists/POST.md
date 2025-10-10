# Checklist: POST (B + C)

- [ ] DBCC CHECKDB czyste na DynamicsAX i DynamicsAX_model.
- [ ] Poziom zgodności ustawiony (na start 120), Query Store (opcjonalnie).
- [ ] SSRS 2016 na C skonfigurowany, bazy ReportServer na B (opcjonalnie).
- [ ] Przywrócony klucz szyfrowania SSRS na C (jeśli przenoszono ReportServer).
- [ ] AX przełączony na nowy serwer SSRS (C).
- [ ] Wykonany redeploy wszystkich raportów AX.
- [ ] Raporty testowe działają (SalesInvoice, SalesOrder).
- [ ] Monitoring ExecutionLog3 – statusy Success.
