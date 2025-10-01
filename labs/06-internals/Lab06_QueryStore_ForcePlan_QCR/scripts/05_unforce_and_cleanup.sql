-- scripts/05_unforce_and_cleanup.sql
-- Zniesienie wymuszenia, czyszczenie QS (opcjonalne).
USE QS_Lab;
GO
-- EXEC sys.sp_query_store_unforce_plan @query_id = <q>, @plan_id = <p>;

-- Opcjonalne: reset QS (uwaga: kasuje historię!)
-- ALTER DATABASE QS_Lab SET QUERY_STORE CLEAR ALL;
