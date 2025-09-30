# STORAGE — iSCSI Target (DATA/LOG)

Na VM **STORAGE** uruchom:
```powershell
.\scripts\storage\New-Iscsi-FciDisks.ps1 -Path 'E:\iSCSI' -DataSizeGB 100 -LogSizeGB 60 -Node1IP 192.168.11.2 -Node2IP 192.168.11.3
```
Na **NODE1/NODE2**:
```powershell
.\scripts\guest\Connect-Iscsi-And-Init.ps1 -StorIP 192.168.11.4 -Initialize:($env:COMPUTERNAME -eq 'NODE1')
```
