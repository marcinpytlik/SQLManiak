# SQL Server Patching — RUNBOOK

## 1. Załóż patching window

Użyj msdb.dba.usp_StartSqlAgentPatchingWindow, jeżeli pakiet jest wdrożony.

## 2. Wyłącz zatwierdzone joby

Najpierw Preview, potem Execute. Zachowaj snapshot stanu.

## 3. Wykonaj patch

Zastosuj zatwierdzony CU/GDR/Windows patch zgodnie z kolejnością dla architektury.

## 4. Uruchom i sprawdź usługi

Potwierdź SQL Server, SQL Agent oraz komponenty wymagane przez środowisko.

## 5. Przywróć joby

Najpierw Preview restore, potem Execute; przywracaj tylko joby wcześniej włączone i wyłączone przez moduł.

## 6. Wykonaj smoke tests

Sprawdź connectivity, build, bazy, joby, monitoring, HA.

## Przejście do walidacji

Po wykonaniu procedury przejdź do [VALIDATION.md](VALIDATION.md).
