/*
    Relacyjny Renesans — Application Lock
    Synchronizacja procesów przez sp_getapplock.

    Skrypt demonstracyjny. Uruchamiaj w środowisku laboratoryjnym.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO


BEGIN TRANSACTION;

DECLARE @Result int;
EXEC @Result = sys.sp_getapplock
    @Resource = N'InvoiceNumber:2026',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 5000;

IF @Result < 0
BEGIN
    ROLLBACK;
    THROW 50001, 'Nie udało się uzyskać blokady aplikacyjnej.', 1;
END;

PRINT N'Bezpieczna sekcja krytyczna';

COMMIT;
GO
