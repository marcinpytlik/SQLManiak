# 🛠️ PIOSEE – Framework analizy incydentów

## P – Problem
Zdefiniowanie, co dokładnie jest nie tak.  
Konkret: komunikat błędu, objaw, metryka, której nie osiągamy.

---

## I – Information
Zbieramy wszystkie fakty.  
Logi, DMVs, alerty, screeny, numery błędów, metadane środowiska.  
Zero interpretacji – tylko czyste dane.

---

## O – Options
Tworzymy możliwe rozwiązania/scenariusze.  
Nie oceniamy jeszcze, po prostu katalogujemy.

---

## S – Select
Wybieramy najlepszą opcję – uwzględniając ryzyko, czas, wpływ na system i biznes.

---

## E – Execute
Realizujemy wybraną opcję:  
wdrożenie fixu, obejścia lub rollbacku.

---

## E – Evaluate
Oceniamy efekt.  
Czy problem faktycznie ustąpił? Jakie były skutki uboczne?  
Czy trzeba zmienić procedury albo dodać monitoring?

---

## 🎯 Przykład 1 – SQL Server (backup)
- **Problem**: długi czas backupu FULL na serwerze X.  
- **Information**: rozmiar bazy, parametry backupu, I/O waits, historia poprzednich backupów.  
- **Options**: kompresja, rozbicie na filegroupy, backup stripe, inny storage.  
- **Select**: test backup stripe + kompresja.  
- **Execute**: uruchomienie backupu z 4 plikami na różne ścieżki.  
- **Evaluate**: czas skrócony o 60%, obciążenie storage rozproszone. Dodajemy monitoring czasu backupu do Grafany.  

---

## 🎯 Przykład 2 – SQL Server FCI / AG
- **Problem**: nieoczekiwany failover w klastrze AlwaysOn AG. Użytkownicy zgłaszają chwilową niedostępność.  
- **Information**:  
  - Event Viewer: zdarzenie 1135 (Cluster node lost communication).  
  - Cluster log: heartbeat timeout.  
  - DMV `sys.dm_hadr_availability_replica_states`: stan jednej repliki = RESOLVING.  
  - Ping do NODE2 – chwilowe opóźnienia.  
- **Options**:  
  1. Restart węzła NODE2 i przywrócenie do AG.  
  2. Sprawdzenie i zwiększenie ustawień timeout w clusterze.  
  3. Analiza sieci – dedykowana karta heartbeat + izolacja ruchu.  
- **Select**: opcja 2 + 3 (zmiana parametru `SameSubnetDelay/SameSubnetThreshold` + konfiguracja osobnej karty heartbeat).  
- **Execute**:  
  - Ustawienie `SameSubnetDelay = 1` i `SameSubnetThreshold = 10`.  
  - Dodanie nowej karty sieciowej HB między NODE1 i NODE2.  
- **Evaluate**: brak kolejnych nieuzasadnionych failoverów przez 2 tygodnie. Monitoring Grafana pokazuje stabilne latency. Runbook zaktualizowany o procedurę testu heartbeat.  

---

👉 Dzięki przykładom widać, że PIOSEE działa zarówno w prostych incydentach (backup), jak i w bardziej złożonych scenariuszach (klaster FCI/AG).
