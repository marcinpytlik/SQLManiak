USE TwojaBaza;
GO

CREATE OR ALTER TRIGGER dbo.trg_BlockDml_Parameters_ForLogin
ON dbo.Parameters
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- <<< TU USTAW LOGIN, KTÓRY MA BYĆ BLOKOWANY >>>
    DECLARE @BlockedLogin sysname = N'konto\domena';

    -- Kto naprawdę się zalogował (odporne na EXECUTE AS w tej samej sesji)
    DECLARE @OrigLogin sysname = ORIGINAL_LOGIN();

    IF @OrigLogin = @BlockedLogin
    BEGIN
        DECLARE @msg nvarchar(4000) =
            N'ZABLOKOWANO DML na dbo.Parameters dla loginu: ' + QUOTENAME(@OrigLogin) +
            N'. Server=' + @@SERVERNAME +
            N', Host=' + HOST_NAME() +
            N', User=' + SUSER_SNAME();

        -- Rzucamy błąd i cofamy transakcję
        RAISERROR (@msg, 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO