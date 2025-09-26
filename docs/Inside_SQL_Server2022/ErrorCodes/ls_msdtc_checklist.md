# MSDTC – checklista pod Msg 7391 (transakcje rozproszone)
- Włącz usługę **Distributed Transaction Coordinator** na obu serwerach.
- Skonfiguruj Network DTC Access.
- Otwórz porty firewall (RPC 135 + dynamiczne).
- Zadbaj o DNS/Kerberos (SPN, delegacja) dla scenariuszy „double hop”.
- Test: DTCTester lub BEGIN DISTRIBUTED TRANSACTION.