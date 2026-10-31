# SQLManiak Index Maintenance

Automatyzacja konserwacji indeksów SQL Server 2022+.

## Model
- Okresowy audyt indeksów (LIMITED i selektywnie SAMPLED).
- Planowanie operacji na kolejne okna serwisowe.
- PowerShell jako wykonawca kolejki, nie mechanizm kwalifikacji.
- Bez bezwarunkowego REBUILD i bez automatycznego zatrzymywania backupów.

## Etap 1 — centralna baza
1. `001_CreateDatabase.sql` — utworzenie bazy SQLManiakIndexMaintenance.
2. `002_CreateCoreSchema.sql` — podstawowy rejestr instancji, baz i przebiegów audytów.

Uruchamiaj skrypty w kolejności numerycznej po dostosowaniu do lokalnych standardów. Nie uruchamiają żadnej przebudowy indeksów.

## Kolejne kroki
Wyniki audytu na poziomie partycji, kwalifikacja operacji, kolejka, historia wykonania, PowerShell.
