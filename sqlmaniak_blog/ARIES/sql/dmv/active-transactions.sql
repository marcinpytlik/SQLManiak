
-- dmv/active-transactions.sql
SELECT transaction_id, name, transaction_begin_time, transaction_state, transaction_uow
FROM sys.dm_tran_active_transactions;
