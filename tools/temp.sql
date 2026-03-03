Tak, marcin — da się go przyspieszyć i to całkiem sensownie.
Patrząc na ten skrypt, największe hamulce są nie w „magii SQL”, tylko w kilku bardzo konkretnych miejscach.

Co najbardziej go spowalnia
1) Robisz INSERT do archiwum + potem osobny DELETE

Czyli dla każdej tabeli:

najpierw czytasz dane do archiwum,

potem jeszcze raz czytasz te same dane, żeby usunąć.

To jest podwójna robota dla I/O.

Lepszy wariant: użyć DELETE ... OUTPUT deleted... INTO ...
Wtedy:

usuwasz,

i w tym samym przebiegu zapisujesz do tabeli archiwalnej.

To zwykle daje bardzo zauważalny zysk.

2) Batch TOP(@topValue) = 50

To jest bardzo mało.
Przy 50 rekordach:

koszt pętli,

TRUNCATE,

PRINT,

WAITFOR,

osobne operacje na 3 tabelach

zjadają dużo czasu w stosunku do faktycznej pracy.

Jeśli środowisko wytrzyma, testuj:

500

1000

5000

Nie od razu „na pałę 50000”, bo log transakcyjny potrafi wtedy zrobić teatr.

3) WAITFOR DELAY '00:00:00.50'

Pół sekundy po każdej iteracji to jest gigantyczny hamulec, jeśli masz dużo batchy.

Przykład:

10 000 batchy × 0,5 s = 5000 sekund samego czekania.

Jeśli nie musisz specjalnie dławić obciążenia:

zmniejsz do 00:00:00.05

albo wyłącz całkiem podczas okna serwisowego.

4) Indeks, który tworzysz, wygląda podejrzanie

Na screenie widać coś w stylu:

create index ix_CreatedDate on Disposition(CreatedDate)

a niżej filtrujesz po:

WHERE srpnCreateDate < @archBusinessDate

Jeśli to są różne kolumny, to ten indeks jest prawie bezużyteczny dla głównego filtra.

To jest bardzo ważne:
indeks powinien wspierać realny predykat, czyli raczej coś w stylu:

(srpnCreateDate, Id) INCLUDE (SRPNTransactionId)

Wtedy SQL Server szybciej wybierze batch kandydatów.

5) NOLOCK przy wyborze rekordów do kasowania

Tu bym był ostrożny.

NOLOCK może:

czytać brudne dane,

pominąć rekordy,

odczytać coś dwa razy.

Przy archiwizacji/usuwaniu to bywa zły pomysł, bo możesz mieć niespójność.
To nie tyle spowalnia, co może robić ciche bagno.

6) Temp table

Masz ##tmpDisposition (globalna temp table).
Jeśli to leci z jednej sesji, lepiej użyć lokalnej:

#tmpDisposition

I dać jej sensowną definicję:

PRIMARY KEY na Id

osobny indeks na SRPNTransactionId

Bo teraz używasz:

Id do DispositionStatus

SRPNTransactionId do Disposition i Message

Czyli jedna kolumna indeksowana to trochę za mało.

Największy zysk: przerobić na DELETE ... OUTPUT
Zamiast:

INSERT INTO ... SELECT ...

DELETE FROM ...

zrobić:
DELETE ds
OUTPUT
    deleted.RowVersion,
    deleted.CreatedDate,
    deleted.LastModDate,
    deleted.Status,
    deleted.Description,
    deleted.DispositionId
INTO dbo.DispositionStatus_Arch
(
    RowVersion,
    CreatedDate,
    LastModDate,
    Status,
    Description,
    DispositionId
)
FROM dbo.DispositionStatus ds
JOIN #tmpDisposition t
    ON ds.DispositionId = t.Id;

To samo dla:

Disposition

Message

To jest najgrubszy performance win w tym skrypcie.

Jakie indeksy sprawdzić / dodać
Na tabeli głównej Disposition

Pod wybór batcha:

CREATE INDEX IX_Disposition_srpnCreateDate_Id
ON dbo.Disposition(srpnCreateDate, Id)
INCLUDE (SRPNTransactionId);
Na DispositionStatus

Pod join do kasowania:

CREATE INDEX IX_DispositionStatus_DispositionId
ON dbo.DispositionStatus(DispositionId);
Na Message

Pod join do kasowania:

CREATE INDEX IX_Message_TransactionId
ON dbo.[Message](TransactionId);

Bez tych indeksów serwer może robić niepotrzebne skany i wtedy całość muli jak wózek po piasku.

Dodatkowe uwagi
PRINT

Przy dużej liczbie iteracji też trochę kosztuje.
Nie jest to największy problem, ale można ograniczyć.

Brak transakcji na batch

Warto dać transakcję na jedną iterację pętli, żeby:

archiwizacja i delete były atomowe,

nie zrobić duplikatów w archiwum przy błędzie w połowie.

CONVERT(VARCHAR(10), DATEADD(...), 111)

To jest dziwne i niepotrzebne. Lepiej po prostu:

SET @archBusinessDate = DATEADD(WEEK, -4, GETDATE());

Mniej kombinacji, mniej niejasności.

Co bym zrobił w praktyce od razu

Zwiększył @topValue z 50 do 500 lub 1000.

Zmniejszył albo wyłączył WAITFOR.

Zamienił INSERT+DELETE na DELETE OUTPUT INTO.

Sprawdził, czy indeks jest na właściwej kolumnie filtrowania (srpnCreateDate, nie przypadkiem CreatedDate).

Dodał indeksy na kolumnach joinów (DispositionId, TransactionId).

Zmienił ##tmpDisposition na #tmpDisposition + PK/indeks.

Najkrótszy werdykt

Tak — da się go znacząco przyspieszyć.
Największy efekt dadzą:

DELETE ... OUTPUT,

większy batch,

mniejszy WAITFOR,

poprawne indeksy.

Jeśli chcesz, mogę ci od razu przepisać ten skrypt na szybszą wersję produkcyjną:

z DELETE OUTPUT,

z lokalną temp table,

z parametrami @BatchSize i @DelayMs,

i z sekcją „weryfikacja ile poszło do archiwum / ile usunięto”.

to poproszę o pełną wersję skryptu
Myślał przez 34s

Jasne, marcin — poniżej masz pełną, szybszą wersję tego skryptu, przepisaną tak, żeby:

robić archiwizację i usuwanie w jednym przebiegu (DELETE ... OUTPUT)

używać lokalnej temp table zamiast ##

działać batchami

mieć kontrolowany delay

mieć transakcję na jeden batch

ograniczyć zbędne skany

Założenie jest takie, że tabele archiwalne mają tę samą strukturę kolumn co źródłowe (albo przynajmniej zgodną z deleted.*).
Jeśli w archiwum masz inną strukturę, wtedy trzeba będzie rozpisać kolumny jawnie.

Pełna wersja
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =========================================================
   PARAMETRY
   ========================================================= */
DECLARE @BatchSize           INT = 1000;   -- testuj: 500 / 1000 / 5000
DECLARE @DelayMs             INT = 100;    -- 100 ms; ustaw 0 jeśli bez pauzy
DECLARE @WeeksBack           INT = 4;      -- ile tygodni wstecz archiwizujemy
DECLARE @Continue            BIT = 1;

DECLARE @ArchBusinessDate    DATETIME;
DECLARE @RowsPicked          INT = 0;
DECLARE @DispositionRows     INT = 0;
DECLARE @DispositionStatusRows INT = 0;
DECLARE @MessageRows         INT = 0;
DECLARE @DeletedRows         INT = 0;
DECLARE @LoopNo              INT = 0;

SET @ArchBusinessDate = DATEADD(WEEK, -@WeeksBack, GETDATE());

/* =========================================================
   OPCJONALNIE: INDEKSY WSPIERAJĄCE
   Uwaga: odkomentuj po weryfikacji nazw kolumn i jeśli ich nie ma
   ========================================================= */
/*
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_Disposition_srpnCreateDate_Id'
      AND object_id = OBJECT_ID(N'dbo.Disposition')
)
BEGIN
    CREATE INDEX IX_Disposition_srpnCreateDate_Id
        ON dbo.Disposition(srpnCreateDate, Id)
        INCLUDE (SRPNTransactionId);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_DispositionStatus_DispositionId'
      AND object_id = OBJECT_ID(N'dbo.DispositionStatus')
)
BEGIN
    CREATE INDEX IX_DispositionStatus_DispositionId
        ON dbo.DispositionStatus(DispositionId);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = N'IX_Message_TransactionId'
      AND object_id = OBJECT_ID(N'dbo.[Message]')
)
BEGIN
    CREATE INDEX IX_Message_TransactionId
        ON dbo.[Message](TransactionId);
END;
GO
*/

/* =========================================================
   TEMP TABLE
   ========================================================= */
IF OBJECT_ID('tempdb..#tmpDisposition') IS NOT NULL
    DROP TABLE #tmpDisposition;

CREATE TABLE #tmpDisposition
(
    Id                BIGINT       NOT NULL,
    SRPNTransactionId VARCHAR(50)  NOT NULL,
    CONSTRAINT PK_tmpDisposition PRIMARY KEY CLUSTERED (Id)
);

CREATE NONCLUSTERED INDEX IX_tmpDisposition_SRPNTransactionId
    ON #tmpDisposition(SRPNTransactionId);

/* =========================================================
   PĘTLA BATCHY
   ========================================================= */
WHILE @Continue = 1
BEGIN
    SET @LoopNo = @LoopNo + 1;
    SET @RowsPicked = 0;
    SET @DispositionRows = 0;
    SET @DispositionStatusRows = 0;
    SET @MessageRows = 0;
    SET @DeletedRows = 0;

    TRUNCATE TABLE #tmpDisposition;

    /* -----------------------------------------------------
       WYBÓR BATCHA
       READPAST = omijaj zablokowane
       UPDLOCK/ROWLOCK = stabilniejszy wybór do kasowania
       ----------------------------------------------------- */
    INSERT INTO #tmpDisposition (Id, SRPNTransactionId)
    SELECT TOP (@BatchSize)
           d.Id,
           d.SRPNTransactionId
    FROM dbo.Disposition AS d WITH (READPAST, UPDLOCK, ROWLOCK)
    WHERE d.srpnCreateDate < @ArchBusinessDate
      AND d.SRPNTransactionId IS NOT NULL
      -- jeśli chcesz dodatkowo filtrować po statusach, odkomentuj:
      -- AND d.OurCurrentStatus IN
      -- (
      --     'WYKONANY',
      --     'RACHUNEK_ODRZUCONY',
      --     'ODRZUCONY',
      --     'WYCOFANY',
      --     'ZLECONE_WYCOFANIE',
      --     'ODRZUCONA_BLOKADA'
      -- )
    ORDER BY d.Id;

    SET @RowsPicked = @@ROWCOUNT;

    IF @RowsPicked = 0
    BEGIN
        PRINT 'Brak kolejnych rekordów do archiwizacji/usunięcia. Koniec.';
        BREAK;
    END;

    PRINT 'Batch #' + CONVERT(VARCHAR(20), @LoopNo)
        + ' | przygotowano: ' + CONVERT(VARCHAR(20), @RowsPicked)
        + ' | data graniczna: ' + CONVERT(VARCHAR(23), @ArchBusinessDate, 121);

    BEGIN TRY
        BEGIN TRAN;

        /* =================================================
           1) DISPOSITIONSTATUS -> ARCH + DELETE
           ================================================= */
        DELETE ds
        OUTPUT deleted.*
        INTO dbo.DispositionStatus_Arch
        FROM dbo.DispositionStatus AS ds
        INNER JOIN #tmpDisposition AS t
            ON ds.DispositionId = t.Id;

        SET @DispositionStatusRows = @@ROWCOUNT;

        /* =================================================
           2) DISPOSITION -> ARCH + DELETE
           ================================================= */
        DELETE d
        OUTPUT deleted.*
        INTO dbo.Disposition_Arch
        FROM dbo.Disposition AS d
        INNER JOIN #tmpDisposition AS t
            ON d.SRPNTransactionId = t.SRPNTransactionId;

        SET @DispositionRows = @@ROWCOUNT;

        /* =================================================
           3) MESSAGE -> ARCH + DELETE
           ================================================= */
        DELETE m
        OUTPUT deleted.*
        INTO dbo.Message_Arch
        FROM dbo.[Message] AS m
        INNER JOIN #tmpDisposition AS t
            ON m.TransactionId = t.SRPNTransactionId;

        SET @MessageRows = @@ROWCOUNT;

        SET @DeletedRows = @DispositionStatusRows + @DispositionRows + @MessageRows;

        COMMIT TRAN;

        PRINT '  DispositionStatus: ' + CONVERT(VARCHAR(20), @DispositionStatusRows);
        PRINT '  Disposition      : ' + CONVERT(VARCHAR(20), @DispositionRows);
        PRINT '  Message          : ' + CONVERT(VARCHAR(20), @MessageRows);
        PRINT '  Razem usunięto   : ' + CONVERT(VARCHAR(20), @DeletedRows);
        PRINT '------------------------------------------------------------';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        PRINT 'BŁĄD w batch #' + CONVERT(VARCHAR(20), @LoopNo)
            + ' | Error ' + CONVERT(VARCHAR(20), @ErrNum)
            + ' | Line ' + CONVERT(VARCHAR(20), @ErrLine)
            + ' | ' + @ErrMsg;

        THROW;
    END CATCH;

    /* -----------------------------------------------------
       DELAY
       ----------------------------------------------------- */
    IF @DelayMs > 0
    BEGIN
        DECLARE @Delay VARCHAR(12);

        SET @Delay =
            '00:00:' +
            RIGHT('00' + CONVERT(VARCHAR(2), (@DelayMs / 1000)), 2) +
            '.' +
            RIGHT('000' + CONVERT(VARCHAR(3), (@DelayMs % 1000)), 3);

        WAITFOR DELAY @Delay;
    END
END

/* =========================================================
   PODSUMOWANIE
   ========================================================= */
PRINT 'Zakończono przetwarzanie.';
PRINT 'Sprawdź ewentualnie liczbę rekordów w tabelach _Arch.';
GO
Dlaczego ta wersja będzie szybsza

Największe zyski są z tych zmian:

DELETE ... OUTPUT zamiast osobnego INSERT i osobnego DELETE

mniej odczytów tych samych danych

większy batch niż 50

mniejszy delay

lokalna temp table #tmpDisposition

transakcja tylko na jeden batch, a nie na cały świat

Bardzo ważne przed odpaleniem

Sprawdź 3 rzeczy, bo tu SQL Server potrafi wbić szpilę bez ostrzeżenia:

Czy dbo.Disposition_Arch, dbo.DispositionStatus_Arch, dbo.Message_Arch mają zgodny układ kolumn z tabelami źródłowymi.
Jeśli nie, trzeba zrobić wersję z jawnie wypisanymi kolumnami.

Czy typ SRPNTransactionId to na pewno VARCHAR(50).
Jeśli masz inny typ/długość, popraw w #tmpDisposition.

Czy kolejność usuwania jest poprawna względem FK.
W tej wersji zostawiłem logikę zgodną z twoim skryptem:

DispositionStatus

Disposition

Message

Co bym ustawił na start

Na pierwsze bezpieczne testy:

DECLARE @BatchSize INT = 500;
DECLARE @DelayMs   INT = 100;

A w oknie serwisowym można spróbować:

DECLARE @BatchSize INT = 2000;
DECLARE @DelayMs   INT = 0;
Rzecz, którą jeszcze można zrobić lepiej

Jeśli chcesz, mogę ci teraz przygotować wersję ultra-bezpieczną, która:

najpierw robi SELECT COUNT(*) ile rekordów kwalifikuje się do archiwizacji,

zapisuje log do tabeli technicznej (start batcha, koniec batcha, error),

ma parametr @DryRun = 1, żeby tylko pokazać co by usunęła, ale nic nie kasować.

To już byłby wariant „produkcyjny, nie-partyzancki”.

To przepisz to i dodaj select count(*) oraz @DryRun=1
Myślał przez kilka sekund

Jasne, marcin — poniżej masz przepisany wariant produkcyjniejszy z:

@DryRun = 1 → tylko symulacja, nic nie usuwa

sekcją SELECT COUNT(*) przed startem

liczeniem:

ile rekordów w Disposition kwalifikuje się do batchowania,

ile powiązanych rekordów jest w DispositionStatus,

ile powiązanych rekordów jest w Message

nadal z batchami i transakcją

w trybie @DryRun = 0 działa już realne DELETE ... OUTPUT

Dodałem też jawne podsumowanie, żeby było widać, co skrypt zamierza zrobić, zanim zacznie kopać.

Pełna wersja z @DryRun
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET QUOTED_IDENTIFIER ON;
GO

/* =========================================================
   PARAMETRY
   ========================================================= */
DECLARE @BatchSize             INT = 1000;   -- testuj: 500 / 1000 / 5000
DECLARE @DelayMs               INT = 100;    -- 0 = bez pauzy
DECLARE @WeeksBack             INT = 4;      -- ile tygodni wstecz
DECLARE @DryRun                BIT = 1;      -- 1 = tylko symulacja, 0 = wykonaj DELETE + archiwum

DECLARE @ArchBusinessDate      DATETIME;
DECLARE @RowsPicked            INT = 0;
DECLARE @DispositionRows       INT = 0;
DECLARE @DispositionStatusRows INT = 0;
DECLARE @MessageRows           INT = 0;
DECLARE @DeletedRows           INT = 0;
DECLARE @LoopNo                INT = 0;

/* =========================================================
   LICZNIKI WSTĘPNE
   ========================================================= */
DECLARE @CandidateDispositionCount       BIGINT = 0;
DECLARE @CandidateDispositionStatusCount BIGINT = 0;
DECLARE @CandidateMessageCount           BIGINT = 0;

SET @ArchBusinessDate = DATEADD(WEEK, -@WeeksBack, GETDATE());

/* =========================================================
   TEMP TABLE
   ========================================================= */
IF OBJECT_ID('tempdb..#tmpDisposition') IS NOT NULL
    DROP TABLE #tmpDisposition;

CREATE TABLE #tmpDisposition
(
    Id                BIGINT       NOT NULL,
    SRPNTransactionId VARCHAR(50)  NOT NULL,
    CONSTRAINT PK_tmpDisposition PRIMARY KEY CLUSTERED (Id)
);

CREATE NONCLUSTERED INDEX IX_tmpDisposition_SRPNTransactionId
    ON #tmpDisposition(SRPNTransactionId);

/* =========================================================
   WSTĘPNA ANALIZA - ILE REKORDÓW WCHODZI W ZAKRES
   ========================================================= */
;WITH Candidates AS
(
    SELECT
        d.Id,
        d.SRPNTransactionId
    FROM dbo.Disposition AS d
    WHERE d.srpnCreateDate < @ArchBusinessDate
      AND d.SRPNTransactionId IS NOT NULL
      -- jeśli chcesz filtrować po statusach, odkomentuj:
      -- AND d.OurCurrentStatus IN
      -- (
      --     'WYKONANY',
      --     'RACHUNEK_ODRZUCONY',
      --     'ODRZUCONY',
      --     'WYCOFANY',
      --     'ZLECONE_WYCOFANIE',
      --     'ODRZUCONA_BLOKADA'
      -- )
)
SELECT
    @CandidateDispositionCount = COUNT_BIG(*)
FROM Candidates;

;WITH Candidates AS
(
    SELECT
        d.Id,
        d.SRPNTransactionId
    FROM dbo.Disposition AS d
    WHERE d.srpnCreateDate < @ArchBusinessDate
      AND d.SRPNTransactionId IS NOT NULL
      -- AND d.OurCurrentStatus IN (...)
)
SELECT
    @CandidateDispositionStatusCount = COUNT_BIG(*)
FROM dbo.DispositionStatus AS ds
INNER JOIN Candidates AS c
    ON ds.DispositionId = c.Id;

;WITH Candidates AS
(
    SELECT
        d.Id,
        d.SRPNTransactionId
    FROM dbo.Disposition AS d
    WHERE d.srpnCreateDate < @ArchBusinessDate
      AND d.SRPNTransactionId IS NOT NULL
      -- AND d.OurCurrentStatus IN (...)
)
SELECT
    @CandidateMessageCount = COUNT_BIG(*)
FROM dbo.[Message] AS m
INNER JOIN Candidates AS c
    ON m.TransactionId = c.SRPNTransactionId;

/* =========================================================
   PODSUMOWANIE WSTĘPNE
   ========================================================= */
SELECT
    @ArchBusinessDate AS ArchBusinessDate,
    @BatchSize AS BatchSize,
    @DelayMs AS DelayMs,
    @WeeksBack AS WeeksBack,
    @DryRun AS DryRun,
    @CandidateDispositionCount AS CandidateDispositionCount,
    @CandidateDispositionStatusCount AS CandidateDispositionStatusCount,
    @CandidateMessageCount AS CandidateMessageCount,
    (@CandidateDispositionCount + @CandidateDispositionStatusCount + @CandidateMessageCount) AS CandidateTotalRows;

PRINT '============================================================';
PRINT 'TRYB: ' + CASE WHEN @DryRun = 1 THEN 'DRY RUN (bez usuwania)' ELSE 'EXECUTION (archiwizacja + delete)' END;
PRINT 'Data graniczna: ' + CONVERT(VARCHAR(23), @ArchBusinessDate, 121);
PRINT 'Disposition do przetworzenia: ' + CONVERT(VARCHAR(30), @CandidateDispositionCount);
PRINT 'DispositionStatus do przetworzenia: ' + CONVERT(VARCHAR(30), @CandidateDispositionStatusCount);
PRINT 'Message do przetworzenia: ' + CONVERT(VARCHAR(30), @CandidateMessageCount);
PRINT '============================================================';

/* =========================================================
   JEŚLI NIC NIE MA DO ZROBIENIA, TO WYJDŹ
   ========================================================= */
IF @CandidateDispositionCount = 0
BEGIN
    PRINT 'Brak rekordów kwalifikujących się do archiwizacji/usunięcia.';
    RETURN;
END;

/* =========================================================
   PĘTLA BATCHY
   ========================================================= */
WHILE 1 = 1
BEGIN
    SET @LoopNo = @LoopNo + 1;
    SET @RowsPicked = 0;
    SET @DispositionRows = 0;
    SET @DispositionStatusRows = 0;
    SET @MessageRows = 0;
    SET @DeletedRows = 0;

    TRUNCATE TABLE #tmpDisposition;

    /* -----------------------------------------------------
       WYBÓR BATCHA
       ----------------------------------------------------- */
    INSERT INTO #tmpDisposition (Id, SRPNTransactionId)
    SELECT TOP (@BatchSize)
           d.Id,
           d.SRPNTransactionId
    FROM dbo.Disposition AS d WITH (READPAST, UPDLOCK, ROWLOCK)
    WHERE d.srpnCreateDate < @ArchBusinessDate
      AND d.SRPNTransactionId IS NOT NULL
      -- jeśli chcesz filtrować po statusach, odkomentuj:
      -- AND d.OurCurrentStatus IN
      -- (
      --     'WYKONANY',
      --     'RACHUNEK_ODRZUCONY',
      --     'ODRZUCONY',
      --     'WYCOFANY',
      --     'ZLECONE_WYCOFANIE',
      --     'ODRZUCONA_BLOKADA'
      -- )
    ORDER BY d.Id;

    SET @RowsPicked = @@ROWCOUNT;

    IF @RowsPicked = 0
    BEGIN
        PRINT 'Brak kolejnych rekordów do przetwarzania. Koniec.';
        BREAK;
    END;

    /* -----------------------------------------------------
       POLICZ, CO TEN BATCH OBEJMUJE
       ----------------------------------------------------- */
    SELECT
        @DispositionStatusRows = COUNT_BIG(*)
    FROM dbo.DispositionStatus AS ds
    INNER JOIN #tmpDisposition AS t
        ON ds.DispositionId = t.Id;

    SELECT
        @DispositionRows = COUNT_BIG(*)
    FROM dbo.Disposition AS d
    INNER JOIN #tmpDisposition AS t
        ON d.SRPNTransactionId = t.SRPNTransactionId;

    SELECT
        @MessageRows = COUNT_BIG(*)
    FROM dbo.[Message] AS m
    INNER JOIN #tmpDisposition AS t
        ON m.TransactionId = t.SRPNTransactionId;

    SET @DeletedRows = @DispositionStatusRows + @DispositionRows + @MessageRows;

    PRINT 'Batch #' + CONVERT(VARCHAR(20), @LoopNo)
        + ' | kandydaci w #tmp: ' + CONVERT(VARCHAR(20), @RowsPicked)
        + ' | Status: ' + CONVERT(VARCHAR(20), @DispositionStatusRows)
        + ' | Disposition: ' + CONVERT(VARCHAR(20), @DispositionRows)
        + ' | Message: ' + CONVERT(VARCHAR(20), @MessageRows)
        + ' | Razem: ' + CONVERT(VARCHAR(20), @DeletedRows);

    /* -----------------------------------------------------
       DRY RUN - TYLKO POKAŻ, NIC NIE RÓB
       ----------------------------------------------------- */
    IF @DryRun = 1
    BEGIN
        -- Podgląd przykładowych rekordów z batcha
        SELECT TOP (20)
            t.Id,
            t.SRPNTransactionId
        FROM #tmpDisposition AS t
        ORDER BY t.Id;

        -- Przerwij po pierwszym batchu w dry run,
        -- żeby nie mielić całej tabeli bez sensu
        PRINT 'DRY RUN zakończony po pierwszym batchu (bez usuwania).';
        BREAK;
    END;

    /* -----------------------------------------------------
       TRYB REALNY
       ----------------------------------------------------- */
    BEGIN TRY
        BEGIN TRAN;

        /* ================================================
           1) DISPOSITIONSTATUS -> ARCH + DELETE
           ================================================ */
        DELETE ds
        OUTPUT deleted.*
        INTO dbo.DispositionStatus_Arch
        FROM dbo.DispositionStatus AS ds
        INNER JOIN #tmpDisposition AS t
            ON ds.DispositionId = t.Id;

        SET @DispositionStatusRows = @@ROWCOUNT;

        /* ================================================
           2) DISPOSITION -> ARCH + DELETE
           ================================================ */
        DELETE d
        OUTPUT deleted.*
        INTO dbo.Disposition_Arch
        FROM dbo.Disposition AS d
        INNER JOIN #tmpDisposition AS t
            ON d.SRPNTransactionId = t.SRPNTransactionId;

        SET @DispositionRows = @@ROWCOUNT;

        /* ================================================
           3) MESSAGE -> ARCH + DELETE
           ================================================ */
        DELETE m
        OUTPUT deleted.*
        INTO dbo.Message_Arch
        FROM dbo.[Message] AS m
        INNER JOIN #tmpDisposition AS t
            ON m.TransactionId = t.SRPNTransactionId;

        SET @MessageRows = @@ROWCOUNT;

        SET @DeletedRows = @DispositionStatusRows + @DispositionRows + @MessageRows;

        COMMIT TRAN;

        PRINT '  REAL DELETE wykonany';
        PRINT '  DispositionStatus: ' + CONVERT(VARCHAR(20), @DispositionStatusRows);
        PRINT '  Disposition      : ' + CONVERT(VARCHAR(20), @DispositionRows);
        PRINT '  Message          : ' + CONVERT(VARCHAR(20), @MessageRows);
        PRINT '  Razem            : ' + CONVERT(VARCHAR(20), @DeletedRows);
        PRINT '------------------------------------------------------------';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrLine INT = ERROR_LINE();
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();

        PRINT 'BŁĄD w batch #' + CONVERT(VARCHAR(20), @LoopNo)
            + ' | Error ' + CONVERT(VARCHAR(20), @ErrNum)
            + ' | Line ' + CONVERT(VARCHAR(20), @ErrLine)
            + ' | ' + @ErrMsg;

        THROW;
    END CATCH;

    /* -----------------------------------------------------
       DELAY
       ----------------------------------------------------- */
    IF @DelayMs > 0
    BEGIN
        DECLARE @Delay VARCHAR(12);

        SET @Delay =
            '00:00:' +
            RIGHT('00' + CONVERT(VARCHAR(2), (@DelayMs / 1000)), 2) +
            '.' +
            RIGHT('000' + CONVERT(VARCHAR(3), (@DelayMs % 1000)), 3);

        WAITFOR DELAY @Delay;
    END
END

PRINT 'Zakończono działanie skryptu.';
GO
Co robi @DryRun = 1

W tym trybie skrypt:

liczy wszystkie rekordy w zakresie

pokazuje podsumowanie

buduje pierwszy batch

liczy ile rekordów w tym batchu dotkną:

DispositionStatus

Disposition

Message

pokazuje TOP (20) z #tmpDisposition

nie wykonuje żadnego DELETE

kończy po pierwszym batchu

To jest celowe, żebyś nie mielił całej bazy „na sucho” przez pół dnia. Symulacja ma być szybka i konkretna, nie filozoficzna.

Gdy chcesz realnie wykonać

Zmieniasz tylko:

DECLARE @DryRun BIT = 0;

I wtedy poleci:

DELETE ... OUTPUT ... INTO archiwum

batch po batchu

z pauzą @DelayMs

Dwie ważne uwagi techniczne
1) COUNT_BIG vs INT

W licznikach użyłem COUNT_BIG, bo przy większych tabelach to bezpieczniejsze.
Potem wkładam wynik do BIGINT, żeby nie wywalić się na limicie INT.

2) OUTPUT deleted.*

To działa tylko wtedy, gdy:

tabela archiwalna ma zgodny układ kolumn,

kolejność kolumn też pasuje.

Jeśli nie pasuje, trzeba zrobić wersję z jawnie wypisanymi kolumnami dla każdej tabeli. To jest trochę dłuższe, ale bardziej pancerne.

Co bym zrobił jako pierwszy test

Najpierw:

DECLARE @BatchSize INT = 500;
DECLARE @DelayMs   INT = 0;
DECLARE @DryRun    BIT = 1;

Zobaczysz:

czy liczby się zgadzają,

czy batch łapie właściwe rekordy,

czy joiny nie robią niespodzianek.

Dopiero potem: