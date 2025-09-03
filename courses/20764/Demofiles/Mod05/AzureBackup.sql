

-- Create credential
CREATE CREDENTIAL [https://xxxx.blob.core.windows.net/aw2016]
	WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
		SECRET = 'sv=2015-04-05&sr=c&si=policy1&sig=sfRAah2c1LjNZAfH1YiJQH%2FPA1sBTjOdPvk8z9849aI%3D';

SELECT *
	FROM sys.credentials;



-- Backup the database
BACKUP DATABASE LogTest
TO URL = 'https://xxxx.blob.core.windows.net/aw2016/logtest.bak';
GO


