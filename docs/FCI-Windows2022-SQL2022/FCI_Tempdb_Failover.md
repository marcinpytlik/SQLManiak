# TempDB i failover w klastrze FCI (SQL Server 2022)

## Co się dzieje przy przełączeniu roli

- **Node1 → Node2**: usługa SQL na Node1 zamyka się → wszystkie sesje i operacje w `tempdb` są ubijane.  
- Po starcie SQL na Node2 `tempdb` jest **tworzona od zera**.

### Praktyczne konsekwencje

- **Zawartość znika**:  
  - tymczasowe tabele (`#`),  
  - zmienne tabelaryczne,  
  - version store (RCSI/SI),  
  - worktables dla sort/hash,  
  - bufor dla ONLINE index rebuild.  
  → Klient dostaje błędy/rollback i musi ponowić zapytania.

- **Pliki**: przy starcie SQL odtwarza `tempdb` z ostatnio skonfigurowaną liczbą i rozmiarem plików (nie z bazy `model`).  

- **Alokacja danych**: pliki `tempdb.mdf` i `*.ndf` są od razu alokowane do docelowego rozmiaru.  
  - Jeśli konto SQL ma prawo **Perform volume maintenance tasks (IFI)** → alokacja natychmiastowa.  

- **Plik loga (`templog.ldf`)**: zawsze zerowany przy starcie.  
  - Zbyt duży log = wydłużony czas startu.  

- **Ścieżka**:  
  - musi istnieć wskazany katalog i prawidłowe uprawnienia, niezależnie czy to dysk lokalny czy współdzielony.  
  - przy **lokalnym tempdb**: identyczna litera/katalog na każdym węźle.  
  - brak ścieżki/ACL lub miejsca → SQL na Node2 nie wstanie, klaster oznaczy zasób jako *failed*.  

---

## Wpływ na czas przełączenia

- **Szybko**:
  - tempdb sensownie wstępnie powiększona,  
  - szybki lokalny SSD/NVMe,  
  - konto SQL z prawem IFI.  

- **Wolno**:
  - bardzo duży `templog.ldf` (czas zerowania),  
  - tempdb rośnie dopiero autogrow po starcie,  
  - brak IFI.  

---

## Dobre praktyki (dla FCI)

1. **Lokalnie trzymaj tempdb** – wydajność i izolacja I/O, ale ścieżki/ACL muszą być identyczne na wszystkich węzłach.  
2. **Pre-size**: ustaw stałe rozmiary plików (równe między sobą), autogrow w MB (np. 256–1024 MB).  
3. **Liczba plików**: zwykle 4–8 równych plików.  
   - nie więcej niż liczba schedulers / rdzeni NUMA na węźle (rozsądek > dogmaty).  
4. **IFI**: przyznaj konto SQL prawo *Perform volume maintenance tasks*.  
5. **Testuj failover**: sprawdzaj w `ERRORLOG` czas tworzenia tempdb po przełączeniu.  
