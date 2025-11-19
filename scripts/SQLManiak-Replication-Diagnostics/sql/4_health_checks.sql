-- 4) Health publikacji/subskrypcji + zaległe komendy
-- Wpisz parametry ręcznie lub użyj .config/env.json przez VS Code tasks
DECLARE @publisher sysname = @@SERVERNAME;

-- a) Stan publikacji (transakcyjna)
EXEC sp_replmonitorhelppublication @publisher = @publisher;

-- b) Stan subskrypcji (transakcyjna)
EXEC sp_replmonitorhelpsubscription @publisher = @publisher, @publication_type = 0; -- 0=tran, 1=merge
