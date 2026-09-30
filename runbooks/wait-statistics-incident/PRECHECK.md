# Wait Statistics Incident Analysis — PRECHECK

1. Zdefiniuj From/To incydentu.
2. Zdobądź snapshot A/B lub monitoring delta.
3. Odfiltruj benign/background waits.
4. Rozdziel signal i resource wait.
5. Powiąż dominant waits z odpowiednim modułem.

## Evidence before
- incident window
- wait delta
- waiting tasks
- avg wait/task
- signal/resource waits

## Stop conditions
- dostępne są tylko stare cumulative waits i użytkownik chce z nich wyciągnąć bieżący RCA
- planowany fix opiera się wyłącznie na nazwie wait type
