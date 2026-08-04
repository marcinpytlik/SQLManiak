/*
    Relacyjny Renesans — Module Signing
    Nadawanie modułowi uprawnień przez certyfikat.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


/*
    Demo wymaga uruchomienia przez użytkownika z odpowiednimi uprawnieniami.
    Sekwencja:
    1. Utwórz certyfikat.
    2. Utwórz użytkownika z certyfikatu.
    3. Nadaj użytkownikowi wymagane uprawnienie.
    4. Podpisz procedurę.
*/
CREATE CERTIFICATE DemoModuleCertificate
    ENCRYPTION BY PASSWORD = 'Strong-Lab-Password-Only!'
    WITH SUBJECT = 'Relacyjny Renesans - module signing';
GO
