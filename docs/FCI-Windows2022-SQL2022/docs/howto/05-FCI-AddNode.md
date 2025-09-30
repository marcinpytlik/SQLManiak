# SQL Server 2022 FCI — dołączanie drugiego węzła (**AddNode**)

Minimalny INI: `scripts/sql/Install-FCI-AddNode.ini`  
Uruchom na **NODE2**:
```powershell
D:\setup.exe /ConfigurationFile="C:\Temp\Install-FCI-AddNode.ini"
```
Po instalacji: wykonaj **smoke test** (`scripts/tests/Smoke-Test.ps1`).
