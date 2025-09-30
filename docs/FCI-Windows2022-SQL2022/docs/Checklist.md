# Checklisty A4 – FCI Windows 2022 + SQL Server 2022

## Pre-Install
- [ ] Członkostwo w tej samej domenie AD, synchronizacja czasu/NTP.
- [ ] DNS: rekordy dla CNO i planowanego VNN.
- [ ] Zainstalowana rola Failover Clustering + narzędzia.
- [ ] Storage współdzielony widoczny z każdego węzła (offline na sekundarnych przed instalacją SQL).
- [ ] Zaplanowany layout: Data, Log, Backups; TempDB lokalnie (ścieżki identyczne).
- [ ] Przygotowane konta usług (gMSA) i uprawnienia NTFS.
- [ ] Test-Cluster zakończony bez krytycznych błędów.

## Install
- [ ] New FCI na pierwszym węźle – feature'y, VNN/IP, ścieżki Data/Log, TempDB lokalnie.
- [ ] Add Node na kolejnych węzłach – ścieżki TempDB istnieją.
- [ ] Skonfigurowany Quorum (FSW/Cloud).

## Post-Install
- [ ] Ustawione progi heartbeat (SameSubnet/CrossSubnet).
- [ ] Preferred Owners ustawione.
- [ ] Anti-Affinity dla wielu instancji (jeśli dotyczy).
- [ ] Ręczny test failoveru + weryfikacja aplikacji/klientów.
- [ ] Monitoring i alerty (Eventy 1135/1205, ERRORLOG, pojemność dysków).

## Utrzymanie
- [ ] Kwartalny test HA (procedura z runbooka).
- [ ] Patchowanie przez CAU (remote-updating) z „drain roles”.
- [ ] Przegląd logów i trendów I/O/storage.
