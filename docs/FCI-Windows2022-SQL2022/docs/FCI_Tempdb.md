# Tempdb w klastrze FCI (Windows Server 2022 + SQL Server 2022)

## Domyślny i rekomendowany wariant

Najlepszym defaultem dla FCI na Windows Server 2022 z SQL Server 2022 jest:
- **`tempdb` → lokalny SSD/NVMe na każdym węźle**
- **dane i logi baz użytkownika → współdzielony storage**

Microsoft wspiera taki układ oficjalnie już od SQL Server 2012.  
Kluczowy wymóg: **identyczna ścieżka musi istnieć na każdym węźle**.  
Przy failoverze `tempdb` i tak jest tworzona od zera, więc nie potrzebuje współdzielonego wolumenu.

Źródło: [Microsoft Learn](https://learn.microsoft.com/)  

---

## Dlaczego lokalnie?

- **Wydajność**: mniej latencji, mniej kontencji na SAN → I/O dla danych i logów użytkownika zostaje odciążone.  
  (Źródło: Brent Ozar Unlimited®)  

- **Wsparcie**: instalator i konfiguracja FCI akceptują lokalny dysk dla `tempdb`.  
  Warunek: ścieżka musi istnieć na każdym węźle — w przeciwnym wypadku zasób SQL nie wystartuje po failoverze.  
  (Źródło: Microsoft Learn)  

---

## Kiedy rozważyć współdzielony storage dla tempdb?

- Bardzo specyficzne środowiska, np. **Azure VMs z FCI**, gdzie operacyjnie prostsze jest trzymanie wszystkiego na współdzielonym dysku.  
- W scenariuszach „tempdb-heavy” w Azure można używać **ephemeral/local SSD dla `tempdb`**, ale:  
  - wymaga to dodatkowego monitoringu dostępności i wolnego miejsca,  
  - awaria lokalnego dysku nie jest osobnym zasobem klastra.  

Źródło: [Azure docs](https://docs.azure.cn)  

---

## Pułapki i dobre praktyki

- **Ścieżki**: utwórz np. `T:\SQL\TempDB\` na każdym węźle.  
  Brak katalogu = SQL nie wystartuje, klaster uzna zasób za nieaktywny i spróbuje failover.  
  (Źródło: Microsoft Learn)  

- **Nośnik**: lokalny dysk powinien być szybki (SSD/NVMe). Microsoft zaleca szybkie lokalne implementacje.  

- **Uprawnienia**: konto usługi SQL musi mieć prawa do folderu na każdym węźle.  
  Przy gMSA konfiguracja jest prostsza.  

- **Monitoring**: alerty na wolne miejsce, `tempdb full`, wersjonowanie (RCSI/SI), alokacje GAM/SGAM/PFS.  

- **Zmiana po instalacji**: można przenieść `tempdb` poleceniami:
  ```sql
  ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, FILENAME = 'T:\SQL\TempDB\tempdb.mdf');
  ALTER DATABASE tempdb MODIFY FILE (NAME = templog, FILENAME = 'T:\SQL\TempDB\templog.ldf');
  ```
  Następnie **restart SQL Server**.  
  Pamiętaj, aby katalogi istniały na wszystkich węzłach przed restartem.  

---

## Diagram FCI – tempdb lokalnie, dane/logi na współdzielonym storage

      +-------------------+           +-------------------+
      |     NODE1         |           |     NODE2         |
      |-------------------|           |-------------------|
      | SQL Server        |           | SQL Server        |
      |                   |           |                   |
      |  TempDB -> [C:\ / D:\ Local SSD/NVMe]             |
      |                   |           |                   |
      +---------+---------+           +---------+---------+
                |                               |
                |      (Failover Cluster)       |
                +---------------+---------------+
                                |
                                v
                  +-------------------------------+
                  |  Shared Storage (SAN / CSV)   |
                  |  - User Databases MDF/NDF     |
                  |  - Transaction Logs LDF       |
                  +-------------------------------+

Legenda:
- TempDB: zawsze lokalnie, musi być identyczna ścieżka na każdym węźle.
- Dane/logi: na współdzielonym storage widocznym dla całego klastra.

---

## Diagram FCI – tempdb na współdzielonym storage (wariant alternatywny)

      +-------------------+           +-------------------+
      |     NODE1         |           |     NODE2         |
      |-------------------|           |-------------------|
      | SQL Server        |           | SQL Server        |
      |                   |           |                   |
      |  TempDB -> Shared Storage     |  TempDB -> Shared Storage
      |                   |           |                   |
      +---------+---------+           +---------+---------+
                |                               |
                |      (Failover Cluster)       |
                +---------------+---------------+
                                |
                                v
                  +-------------------------------+
                  |  Shared Storage (SAN / CSV)   |
                  |  - User Databases MDF/NDF     |
                  |  - Transaction Logs LDF       |
                  |  - TempDB (MDF/LDF)           |
                  +-------------------------------+

Uwagi:
- Historycznie (np. przed SQL 2012) **tempdb na współdzielonym storage** była standardem.  
- Wciąż bywa stosowane w specyficznych środowiskach (np. niektóre konfiguracje w chmurze).  
- Minus: dodatkowa latencja i ryzyko kontencji na SAN.  

---

## TempDB lokalnie vs. na współdzielonym storage – porównanie

| Kryterium                | TempDB lokalnie (SSD/NVMe)                           | TempDB na współdzielonym storage (SAN/CSV)            |
|---------------------------|-----------------------------------------------------|------------------------------------------------------|
| **Wydajność**             | Bardzo wysoka – niska latencja, brak kontencji I/O  | Niższa – większa latencja, współdzielone I/O z danymi |
| **Oficjalne wsparcie**    | Tak (od SQL Server 2012) – rekomendowany wariant    | Tak – starsze podejście, nadal możliwe               |
| **Failover**              | TempDB tworzona od zera na każdym węźle             | TempDB istnieje na SAN, ale i tak jest resetowana     |
| **Ścieżki / konfiguracja**| Wymóg identycznych ścieżek na każdym węźle          | Jeden katalog na SAN wystarcza                       |
| **Ryzyko operacyjne**     | Dysk lokalny musi być zawsze dostępny; potrzebny monitoring | SAN jest zasobem klastra – mniej ryzyka lokalnego, ale większe obciążenie I/O |
| **Zastosowania**          | 90% środowisk produkcyjnych – najlepsza praktyka    | Specyficzne środowiska (np. chmura, Azure VM FCI)    |
| **Rekomendacja**          | ✅ Domyślny wybór                                   | ⚠️ Tylko w uzasadnionych przypadkach                  |
