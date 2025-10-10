# ROLLBACK

Jeżeli migracja się nie powiedzie:
1. Przywróć bazy na A z backupów (DynamicsAX, DynamicsAX_model).
2. W AX ustaw ponownie stary serwer SSRS (A) i wykonaj redeploy raportów.
3. Przywróć klucz szyfrowania SSRS na A oraz pliki konfiguracyjne.
4. Zatrzymaj/wyłącz C do czasu ponownego podejścia.
