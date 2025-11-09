# SQL Client w Kubernetes – Problemy, Źródła i Rekomendacje
**Dotyczy:** `.NET`, `System.Data.SqlClient`, `Microsoft.Data.SqlClient`, `SQL Server`, `Kubernetes`, `Linux containers`

---

## 1. Dlaczego `System.Data.SqlClient` powoduje problemy w Kubernetes
`System.Data.SqlClient` jest oficjalnie w **maintenance mode**. Nie otrzymuje już nowych funkcji ani pełnego wsparcia dla:
- kontenerów Linux,
- Kubernetes (DNS, SNAT, scaling),
- TLS/SSL na OpenSSL,
- certyfikatów CA,
- nowoczesnych scenariuszy typu Always On + MultiSubnetFailover.

`Microsoft.Data.SqlClient` jest rozwijany aktywnie i zawiera poprawki dla:
- TLS/handshake na Linux,
- certyfikatów CA,
- DNS resolverów w kontenerach,
- connection pooling w mikroserwisach,
- Azure/AAD/Always Encrypted.

**Rekomendacja:** stosować `Microsoft.Data.SqlClient` 5.x/5.2+.

---

## 2. Typowe problemy w Kubernetes + SQL Server

### 2.1 TLS / certyfikaty
Kontenery, szczególnie Alpine/musl, często nie mają pełnego zestawu CA – powoduje to błędy:
- handshake failure,
- chain validation error,
- fallback do `TrustServerCertificate=True`.

### 2.2 DNS / resolver (Alpine/musl)
Znane problemy z opóźnieniami i timeoutami przy otwieraniu połączeń, szczególnie gdy:
- aplikacja używa `TransparentNetworkIPResolution=True`,
- resolver w kontenerze jest powolny lub niestabilny.

### 2.3 SNAT / port exhaustion
Przy wielu podach i krótkich połączeniach powstaje zjawisko:
- wyczerpywania portów SNAT,
- błędy `10054`, `10053`, `17830`.

### 2.4 Idle timeout (Load Balancer / firewall)
Load balancer zrywa „bezczynne” połączenia SQL → następne zapytanie trafia na martwy socket.

### 2.5 Connection storms przy autoskalowaniu
Nagły przyrost podów = setki jednoczesnych `SqlConnection.Open()` → możliwy:
- THREADPOOL starvation,
- kolejki zadań w SQL,
- liczne `17830` i `10054`.

---

## 3. Rekomendowane ustawienia w Kubernetes

### 3.1 Stabilny connection string
```
Server=tcp:sql-listener.dom.local,1433;
Initial Catalog=AppDb;
User ID=app_user;Password=•••;
Encrypt=True;
TrustServerCertificate=False;
MultiSubnetFailover=True;
TransparentNetworkIPResolution=False;
Pooling=True;
Min Pool Size=20;
Max Pool Size=200;
Connect Timeout=15;
```

### 3.2 Obraz kontenera
Unikać Alpine/musl przy SQL Client.  
Minimalne wymaganie: zainstalowane CA certificates.

### 3.3 Autoskalowanie
- HPA z łagodnym ramp-upem.
- Warm-up connection pool (Min Pool Size).
- Retry z backoffem i jitterem.

### 3.4 Load Balancer / firewall
- Podnieść idle timeout.
- Włączyć TCP keepalive w OS.

---

## 4. Źródła i dokumentacja

### 4.1 Status System.Data.SqlClient
- https://github.com/dotnet/SqlClient/issues/593
- https://learn.microsoft.com/dotnet/framework/data/adonet/sql/introduction

### 4.2 TLS / certyfikaty / Linux
- Problemy z TLS handshake na Linux  
  https://github.com/dotnet/SqlClient/issues/593
- CA chain issues  
  https://github.com/dotnet/SqlClient/issues/978  
  https://github.com/dotnet/SqlClient/issues/1312
- Instalowanie certyfikatów CA w Linux  
  https://learn.microsoft.com/dotnet/standard/security/certificates#installing-certificates-on-linux

### 4.3 DNS / resolver / TransparentNetworkIPResolution
- Zalecenie wyłączenia TransparentNetworkIPResolution w kontenerach  
  https://github.com/dotnet/SqlClient/issues/593#issuecomment-712518198
- DNS lookup latency  
  https://github.com/dotnet/SqlClient/issues/1300
- Dokumentacja parametru  
  https://learn.microsoft.com/dotnet/api/system.data.sqlclient.sqlconnectionstringbuilder.transparentnetworkipresolution

### 4.4 SNAT / port exhaustion
- Microsoft: TCP SNAT port exhaustion  
  https://learn.microsoft.com/azure/load-balancer/load-balancer-outbound-connections#snat
- Kubernetes networking  
  https://kubernetes.io/docs/concepts/services-networking/

### 4.5 Idle timeout (LB/firewall)
- Azure LB idle timeout  
  https://learn.microsoft.com/azure/load-balancer/load-balancer-tcp-idle-timeout
- Dead sockets in pool  
  https://github.com/dotnet/SqlClient/issues/1271

### 4.6 Always On / MultiSubnetFailover
- https://learn.microsoft.com/dotnet/api/microsoft.data.sqlclient.sqlconnectionstringbuilder.multisubnetfailover
- https://learn.microsoft.com/sql/connect/jdbc/connecting-to-always-on-availability-groups

### 4.7 Problemy przy autoskalowaniu
- https://techcommunity.microsoft.com/t5/sql-server-support/worker-thread-exhaustion/ba-p/3180138
- https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/

### 4.8 Problemy Alpine/musl
- https://github.com/dotnet/SqlClient/issues/1300
- https://github.com/dotnet/runtime/issues/24009

### 4.9 Migracja na Microsoft.Data.SqlClient
- https://learn.microsoft.com/dotnet/api/microsoft.data.sqlclient
- https://learn.microsoft.com/dotnet/framework/data/adonet/sql/introduction

---

## 5. Podsumowanie
- `System.Data.SqlClient` = legacy, brak pełnego wsparcia kontenerów.  
- Kubernetes eksponuje problemy: DNS, TLS, idle timeout, SNAT, scaling.  
- `Microsoft.Data.SqlClient` jest obecnym, wspieranym providerem.  
- Rekomendowane: TLS aktywny, resolver stabilny, `TransparentNetworkIPResolution=False`, pooling dostrojony pod skalę, unikaj Alpine.
