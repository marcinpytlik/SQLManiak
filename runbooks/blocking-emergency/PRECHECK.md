# Blocking Emergency Mitigation — PRECHECK

1. Zidentyfikuj head blocker.
2. Zapisz session/request/transaction duration.
3. Zapisz wait_type, wait_resource, SQL text i plan.
4. Ustal login/host/application i business owner.
5. Oceń, czy blocker wykonuje aktywną pracę czy jest idle in transaction.

## Evidence before
- blocking chain
- head blocker SQL/plan
- transaction age
- affected sessions
- incident timestamp

## Stop conditions
- nie wiadomo, jaki proces biznesowy wykonuje blocker
- rollback po KILL może być długi i wpływ nie jest znany
- brak autoryzacji do przerwania transakcji
