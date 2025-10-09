# Rollback playbook (powrót do A)

> Używaj tylko jeśli po przełączeniu na C wystąpił krytyczny problem.

1. Na **B** cofnij przekierowanie:
   ```sql
   EXEC sp_redirect_publisher
     @original_publisher    = N'ServerA',
     @publisher_db          = N'TwojaBaza',
     @redirected_publisher  = N'ServerA';
   ```
   Zweryfikuj:
   ```sql
   EXEC sp_get_redirected_publisher
     @publisher = N'ServerA', @publisher_db = N'TwojaBaza';
   ```

2. Na **A** uruchom ponownie agenty (Log Reader, Distribution) powiązane z publikacją.

3. Odblokuj ruch do bazy na A. Sprawdź przepływ replikacji i brak zaległych komend.

4. Zanotuj przyczynę rollbacku, zrzuty błędów i zakres naprawczy.
