# TempDB Emergency — RUNBOOK

## 1. Zidentyfikuj typ problemu

Capacity, version store, workspace, allocation latch, runaway query.

## 2. Zatrzymaj źródło wzrostu, jeśli bezpieczne

Np. kontrolowane zakończenie runaway query lub transakcji po ocenie impact.

## 3. Zapewnij capacity, jeśli konieczne

Rozszerz pliki/storage zgodnie z zatwierdzonym planem.

## 4. Napraw root cause

Query plan, transakcja, file configuration, versioning workload.

## 5. Obserwuj pełny cykl

Nie oceniaj tylko kilka minut po interwencji.
