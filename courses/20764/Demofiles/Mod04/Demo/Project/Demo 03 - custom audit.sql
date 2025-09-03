-- Module 4 - Demo 3

-- Step 1 - create an audit
USE master;
GO
CREATE SERVER AUDIT Custom_Audit 
    TO FILE (FILEPATH='D:\Demofiles\Mod04\Audit\')
    WITH (QUEUE_DELAY = 5000);
GO
ALTER SERVER AUDIT Custom_Audit WITH (STATE = ON);
GO

-- Step 2 - create a server audit specification which includes the 
-- USER_DEFINED_AUDIT_GROUP action group
CREATE SERVER AUDIT SPECIFICATION UserDefinedEvents
FOR SERVER AUDIT Custom_Audit
ADD (USER_DEFINED_AUDIT_GROUP)
WITH (STATE = ON);
GO

-- Step 3 - call sp_audit_write directly
EXEC sp_audit_write @user_defined_event_id = 999, 
                    @succeeded = 1,
                    @user_defined_information = N'Example call to sp_audit_write';


-- Step 4 - demonstrate how a custom event appears in the audit 
SELECT user_defined_event_id, succeeded, user_defined_information
FROM sys.fn_get_audit_file ('D:\Demofiles\Mod04\Audit\Custom_Audit*',default,default)
WHERE user_defined_event_id = 999;

-- Step 5 - demonstrate the use of sp_audit_write in a stored procedure
USE salesapp1;
GO

CREATE PROC usp_OrderDetailDiscount
	@orderid int,
	@productid int,
	@discount numeric(4,3)
AS
	SET NOCOUNT ON

	IF @discount > 0.3
	BEGIN
		DECLARE @msg nvarchar(4000) = 
		  CONCAT('Order=',@orderid,':Product=',@productid,
		         ':discount=', @discount)

		
		EXEC sp_audit_write @user_defined_event_id = 998, 
				            @succeeded = 1,
						    @user_defined_information = @msg;
	END

	UPDATE Sales.OrderDetails
	SET discount = @discount
	WHERE orderid = @orderid
	AND productid = @productid
GO

-- Step 6 - call the stored procedure twice
-- the first call should not generate a custom audit event
-- the second call should generate a custom audit event
EXEC dbo.usp_OrderDetailDiscount @orderid = 10248,@productid =	11, @discount = 0.05
EXEC dbo.usp_OrderDetailDiscount @orderid = 10248,@productid =	42, @discount = 0.45

-- Step 7 - examine the audit data
SELECT user_defined_event_id, succeeded, user_defined_information
FROM sys.fn_get_audit_file ('D:\Demofiles\Mod04\Audit\Custom_Audit*',default,default)
WHERE user_defined_event_id = 998;

-- Step 8 - drop the audit
USE master;
GO
ALTER SERVER AUDIT Custom_Audit WITH (STATE = OFF);
DROP SERVER AUDIT Custom_Audit;
GO

ALTER SERVER AUDIT SPECIFICATION UserDefinedEvents WITH (STATE = OFF);
DROP SERVER AUDIT SPECIFICATION UserDefinedEvents
GO
