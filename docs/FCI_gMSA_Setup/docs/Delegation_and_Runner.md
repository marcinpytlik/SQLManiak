
# Delegation & Runner (automatyzacja SPN)

## Uprawnienia do SPN
Aby pipeline mógł zarejestrować SPN dla `MSSQLSvc/VNN...` na koncie `sqlsvc_fci01$`:
- Konto, na którym działa **self-hosted Windows runner**, musi mieć prawo **modyfikacji atrybutu SPN** tego konta gMSA.
- Najprościej: deleguj uprawnienie **"Write servicePrincipalName"** na obiekcie `CN=sqlsvc_fci01,...` dla konta usługi runnera (lub użyj Domain Admin).

## Self-hosted Windows runner
- Dołącz maszynę z runnerem do domeny.
- Zainstaluj runner z etykietą, np. `windows-domain`.
- Uruchom usługę runnera na koncie domenowym, które ma powyższe uprawnienia.

## Dane wejściowe pipeline
- `domain` – np. `sqlmaniak.lab`
- `gmsa` – `sqlsvc_fci01` (bez `$`)
- `vnn_fqdn` – `SQLPROD.sqlmaniak.lab`
- `port` – zwykle `1433`

> Agent SQL **nie wymaga SPN** – rejestrujemy je tylko dla gMSA silnika.
