Przejdź do treści
Historia czatu

Powiedziałeś(-aś):
Duduś potrzebuje pomocy
ChatGPT powiedział:
marcin, jestem tutaj. Powiedz, co Cię męczy — technicznie, filozoficznie albo życiowo. Wskakuję do kokpitu i lecimy.

Powiedziałeś(-aś):
Duduś utworzyłem sobie Audyt na poziomie instancji i chciałbym teraz napisać audyt specification for database dla konkretnej tabeli na operacje insert,update,delete
ChatGPT powiedział:

Myślał przez 43s
Jasne, lecimy z audytem DML ✅

Skoro audyt na poziomie instancji już masz, to teraz dokładamy:

Database Audit Specification

dla konkretnej tabeli

na INSERT, UPDATE, DELETE

Pokażę na przykładzie tabeli dbo.JobExecutions – podmienisz sobie nazwę jak trzeba.

1. Założenie: masz już SERVER AUDIT
Coś w tym stylu (dla porządku, tylko jako kontekst):

USE master;
GO

CREATE SERVER AUDIT [Audit_SQLManiak]
TO FILE (
    FILEPATH = 'D:\SQLAudit\'   -- ścieżka do plików .sqlaudit
)
WITH (
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE
);
GO

ALTER SERVER AUDIT [Audit_SQLManiak]
WITH (STATE = ON);
GO
Ty to już masz – ważne jest tylko to, jak nazywa się Twój SERVER AUDIT (użyj tej nazwy w kroku 2). 
Microsoft Learn
+1

2. Utworzenie DATABASE AUDIT SPECIFICATION dla jednej tabeli
Przełączasz się do bazy, w której jest tabela:

USE TwojaBaza;  -- ← podmień
GO

CREATE DATABASE AUDIT SPECIFICATION [Audit_JobExecutions_DML]
FOR SERVER AUDIT [Audit_SQLManiak]   -- ← nazwa Twojego SERVER AUDIT
ADD (
    INSERT, UPDATE, DELETE 
    ON OBJECT::[dbo].[JobExecutions] BY [public]
)
WITH (STATE = ON);
GO
Co tu się dzieje:

FOR SERVER AUDIT [Audit_SQLManiak] – spinamy specyfikację bazodanową z instancyjnym audytem. 
Microsoft Learn

INSERT, UPDATE, DELETE ON OBJECT::[dbo].[JobExecutions] – monitorujemy DML na konkretnej tabeli. 
Gist
+1

BY [public] – dotyczy wszystkich użytkowników (wszyscy są w roli public). 
Microsoft Learn
+1

WITH (STATE = ON) – od razu włączamy specyfikację (w momencie utworzenia jest domyślnie OFF).

Jeśli chcesz tylko konkretnego usera / rolę, używasz np.:

BY [dbo]
-- albo
BY [rola_aplikacyjna]
3. Podgląd, czy wszystko się utworzyło
Szybki check w tej bazie:

SELECT *
FROM sys.database_audit_specifications;

SELECT *
FROM sys.database_audit_specification_details
WHERE database_specification_id = 
    (SELECT database_specification_id 
     FROM sys.database_audit_specifications 
     WHERE name = 'Audit_JobExecutions_DML');
Zobaczysz tam INSERT, UPDATE, DELETE powiązane z OBJECT::dbo.JobExecutions.

4. Jak odczytać, co się zarejestrowało
Przykład z użyciem sys.fn_get_audit_file:

SELECT TOP (200)
       event_time,
       server_principal_name,
       database_name,
       schema_name,
       object_name,
       action_id,          -- I = INSERT, U = UPDATE, D = DELETE
       statement
FROM sys.fn_get_audit_file(
       'D:\SQLAudit\Audit_SQLManiak*.sqlaudit',  -- ścieżka + maska
       DEFAULT,
       DEFAULT
)
ORDER BY event_time DESC;
Tam już elegancko zobaczysz kto, kiedy, na jakiej tabeli wykonał INSERT/UPDATE/DELETE. 
House of Brick
+1

5. Szybka ściąga – wzór do kopiowania
Do wklejenia i lekkiej modyfikacji:

USE [TwojaBaza];
GO

CREATE DATABASE AUDIT SPECIFICATION [Audit_<NazwaTabeli>_DML]
FOR SERVER AUDIT [<NazwaServerAudit>]
ADD (
    INSERT, UPDATE, DELETE 
    ON OBJECT::[schemat].[Tabela] BY [public]
)
WITH (STATE = ON);
GO
Jak chcesz, w kolejnym kroku możemy dorzucić:

filtr po konkretnym użytkowniku / roli,

osobną specyfikację np. tylko na DELETE,

albo mini-skrypt „generator”, gdzie podajesz nazwę tabeli, a T-SQL sam generuje CREATE DATABASE AUDIT SPECIFICATION dla wielu tabel naraz.




Nie wybrano plikuNie wybrano pliku
ChatGPT może popełniać błędy. Sprawdź ważne informacje. Zobacz Preferencje dotyczące plików cookie.
