-- Module 4 - Demo 5

-- Step 1 - create a new table with data masks
USE salesapp1;
GO
CREATE TABLE HR.EmployeePersonalData
(empid int NOT NULL PRIMARY KEY,
salary int  MASKED WITH (FUNCTION = 'default()') NOT NULL,
email_address varchar(255)  MASKED WITH (FUNCTION = 'email()')  NULL,
voice_mail_pin smallint MASKED WITH (FUNCTION = 'random(0, 9)') NULL,
company_credit_card_number varchar(30) MASKED WITH (FUNCTION = 'partial(0,"XXXX-",4)') NULL,
home_phone_number varchar(30) NULL
);
GO
-- grant permission to a low-privilege user
GRANT SELECT ON HR.EmployeePersonalData TO test_user;
GO
-- insert test data 
INSERT HR.EmployeePersonalData
(empid, salary, email_address, voice_mail_pin, company_credit_card_number, home_phone_number)
VALUES (1,25000,'emp1@adventure-works.net',9991,'9999-5656-4433-2211', '1234-567890'),
(2,35000,'qx3e@adventure-works.org',1151,'9999-7676-5566-3141', '2345-314253'),
(3,35000,'zn4456@adventure-works.net',6514,'9999-7676-5567-2444', '3456-777266')

-- Step 2 - demonstrate that an adminstrator can see the unmasked data
SELECT * FROM HR.EmployeePersonalData

-- Step 3 - demonstrate that a user with only SELECT permission sees masked data  
EXECUTE AS USER = 'test_user'
SELECT * FROM HR.EmployeePersonalData
REVERT
GO
-- Step 4 - alter the home_phone_number column to add a mask
ALTER TABLE HR.EmployeePersonalData 
ALTER COLUMN home_phone_number
ADD MASKED WITH (FUNCTION = 'partial(4,"-XXX",0)');
GO

-- Step 5 - demonstrate the new mask  
EXECUTE AS USER = 'test_user'
SELECT home_phone_number FROM HR.EmployeePersonalData
REVERT
GO

-- Step 6 - remove the mask from the salary column
ALTER TABLE HR.EmployeePersonalData 
ALTER COLUMN salary
DROP MASKED;
GO

-- Step 7 - demonstrate that salary is now unmasked 
EXECUTE AS USER = 'test_user'
SELECT salary FROM HR.EmployeePersonalData
REVERT
GO

-- Step 8 - grant the UNMASK permission to the test user
GRANT UNMASK TO test_user;

-- Step 9 - demonstrate that the UNMASK permission disables masking
EXECUTE AS USER = 'test_user'
SELECT * FROM HR.EmployeePersonalData
REVERT
GO

-- Step 10 - remove test table
DROP TABLE HR.EmployeePersonalData;
GO
