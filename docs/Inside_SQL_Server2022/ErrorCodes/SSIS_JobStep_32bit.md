# SSIS w SQL Agent – 32-bit vs 64-bit i drivery

- Dla providerów dostępnych wyłącznie w 32-bit zaznacz **Use 32-bit runtime** w kroku joba SSIS albo użyj `dtexec /32`.
- Zainstaluj drivery x86/x64 zgodne z używaną architekturą.
- Konto usługi **SQL Server Agent** musi mieć dostęp do plików/udziałów/źródeł danych.

## Przykład CmdExec z `dtexec`:
```
dtexec /F "D:\SSIS\ImportData.dtsx" /Set \Package.Variables[User::Folder].Value;"\\FS\Share\Inbox" /Rep E /WarnAsError
```