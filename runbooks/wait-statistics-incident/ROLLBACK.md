# Wait Statistics Incident Analysis — ROLLBACK

## Kiedy
- na podstawie waita wdrożono zmianę i workload się pogarsza
- filtracja waitów ukryła istotny sygnał

## Procedura
1. Cofnij zmianę konfiguracyjną wynikającą z błędnej interpretacji.
2. Powtórz pomiar z poprawnym oknem i pełniejszym zestawem waitów.

## Walidacja
- nowa delta jest reprezentatywna
- metryki resource/workload są skorelowane
