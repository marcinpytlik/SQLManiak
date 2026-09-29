# DBCC CHECKDB / Corruption Recovery — RUNBOOK

## 1. Zabezpiecz evidence

Nie wykonuj pochopnych operacji zmieniających dane.

## 2. Oceń scope

Ustal bazy, obiekty i strony oraz business impact.

## 3. Wybierz recovery path

Preferuj restore bazy/pliku/strony zależnie od zakresu i RPO/RTO.

## 4. Wykonaj page restore, jeśli właściwy

Repo zawiera wzorzec RESTORE DATABASE ... PAGE='file:page' WITH NORECOVERY, następnie log restore i RECOVERY.

## 5. Zweryfikuj

Uruchom CHECKDB po recovery i smoke tests.

Po wykonaniu przejdź do [VALIDATION.md](VALIDATION.md).
