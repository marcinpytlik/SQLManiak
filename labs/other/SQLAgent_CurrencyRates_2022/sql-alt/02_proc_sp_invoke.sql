-- sql-alt/02_proc_sp_invoke.sql
/*
ALTERNATYWA tylko dla środowisk wspierających sp_invoke_external_rest_endpoint:
- Azure SQL Database / Managed Instance (GA)
- SQL Server 2025 (preview) – wymaga włączenia: 
    EXEC sp_configure 'external rest endpoint enabled', 1; RECONFIGURE;
- Nadaj uprawnienie: 
    GRANT EXECUTE ANY EXTERNAL ENDPOINT TO <login/role>;
NBP API nie wymaga autoryzacji – można nie podawać @credential.
Dok: Microsoft Learn – sp_invoke_external_rest_endpoint.
*/

CREATE OR ALTER PROCEDURE dbo.usp_UpsertNbpRates_viaInvoke
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @retcode int, @response nvarchar(max);
    DECLARE @url nvarchar(4000) = N'https://api.nbp.pl/api/exchangerates/tables/A?format=json';
    -- Możesz dodać nagłówki jeśli potrzebne (NBP ich nie wymaga)
    DECLARE @headers nvarchar(4000) = N'{"Accept":"application/json"}';

    EXEC @retcode = sys.sp_invoke_external_rest_endpoint
        @url = @url,
        @method = N'GET',
        @headers = @headers,
        @response = @response OUTPUT;

    IF @retcode NOT BETWEEN 200 AND 299
    BEGIN
        THROW 50001, CONCAT('NBP API HTTP status: ', @retcode), 1;
    END

    -- @response ma format: {{ "response": {{...}}, "result": [...] }}
    DECLARE @json nvarchar(max) = JSON_QUERY(@response, '$.result');
    EXEC dbo.usp_UpsertNbpRatesFromJson @json = @json;
END
GO
