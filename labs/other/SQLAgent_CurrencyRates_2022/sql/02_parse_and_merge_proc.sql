-- sql/02_parse_and_merge_proc.sql
SET NOCOUNT ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_UpsertNbpRatesFromJson
    @json nvarchar(max)
AS
BEGIN
    SET NOCOUNT ON;
    -- Oczekiwany JSON z NBP (tables/A):
    -- [ { "table":"A","no":"197/A/NBP/2025","effectiveDate":"2025-10-10","rates":[{"currency":"...","code":"THB","mid":0.1125}, ...] } ]

    ;WITH t AS (
        SELECT
            table_id       = JSON_VALUE(r.value, '$.table'),
            table_no       = JSON_VALUE(r.value, '$.no'),
            effective_date = TRY_CAST(JSON_VALUE(r.value, '$.effectiveDate') AS date),
            rates_json     = JSON_QUERY(r.value, '$.rates')
        FROM OPENJSON(@json) AS r
    ),
    rates AS (
        SELECT
            t.table_id,
            t.table_no,
            t.effective_date,
            code     = JSON_VALUE(x.value, '$.code'),
            currency = JSON_VALUE(x.value, '$.currency'),
            rate     = TRY_CAST(JSON_VALUE(x.value, '$.mid') AS decimal(18,6))
        FROM t
        CROSS APPLY OPENJSON(t.rates_json) AS x
    )
    MERGE dbo.ExchangeRates AS dst
    USING (
        SELECT *
        FROM rates
        WHERE table_id = 'A'      -- Ten projekt obsługuje tabelę A (kursy średnie)
          AND effective_date IS NOT NULL
          AND code IS NOT NULL
    ) AS src
    ON  dst.table_id = src.table_id
    AND dst.code = src.code
    AND dst.effective_date = src.effective_date
    AND dst.table_no = src.table_no
    WHEN MATCHED AND dst.rate <> src.rate THEN
        UPDATE SET dst.rate = src.rate
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (table_id, table_no, effective_date, code, currency, rate)
        VALUES (src.table_id, src.table_no, src.effective_date, src.code, src.currency, src.rate)
    WHEN NOT MATCHED BY SOURCE AND dst.table_id = 'A' AND dst.effective_date = (
        SELECT DISTINCT effective_date FROM rates
    )
    THEN
        -- nic: pozostawiamy wcześniejsze tabele_no w historii
        DO NOTHING;

    -- prosta telemetria
    DECLARE @rows INT = @@ROWCOUNT;
    PRINT CONCAT('usp_UpsertNbpRatesFromJson: MERGE affected rows = ', @rows);
END
GO
