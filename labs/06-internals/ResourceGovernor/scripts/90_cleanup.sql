ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = NULL);
ALTER RESOURCE GOVERNOR RECONFIGURE;

DROP FUNCTION IF EXISTS master.dbo.ufn_rg_classifier;

IF EXISTS (SELECT 1 FROM sys.resource_governor_workload_groups WHERE name = N'wg_lab_noisy')
BEGIN
    ALTER WORKLOAD GROUP [wg_lab_noisy] USING [default];
END
IF EXISTS (SELECT 1 FROM sys.resource_governor_workload_groups WHERE name = N'wg_prod_friendly')
BEGIN
    ALTER WORKLOAD GROUP [wg_prod_friendly] USING [default];
END
ALTER RESOURCE GOVERNOR RECONFIGURE;

DROP WORKLOAD GROUP IF EXISTS [wg_lab_noisy];
DROP WORKLOAD GROUP IF EXISTS [wg_prod_friendly];

DROP RESOURCE POOL IF EXISTS [pool_lab_noisy];
DROP RESOURCE POOL IF EXISTS [pool_prod_friendly];

ALTER RESOURCE GOVERNOR RECONFIGURE;
