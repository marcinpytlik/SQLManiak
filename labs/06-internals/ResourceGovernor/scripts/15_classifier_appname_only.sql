:setvar DbName "TwojaBaza"
:setvar Group_Lab "wg_lab_noisy"
:setvar Group_Pro "wg_prod_friendly"
:setvar AppNameLabPattern "%LAB%"
:setvar AppNameProdPattern "%PROD%"

USE master;
GO

/* Classifier oparty WYŁĄCZNIE na APP_NAME().
   Warunek bezpieczeństwa: domyślna baza logowania = $(DbName).
   Użyj, gdy nie możesz klasyfikować po grupach AD. */

IF OBJECT_ID('master.dbo.ufn_rg_classifier', 'FN') IS NOT NULL
    DROP FUNCTION master.dbo.ufn_rg_classifier;
GO

CREATE FUNCTION master.dbo.ufn_rg_classifier()
RETURNS sysname
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @ret sysname = NULL;

    DECLARE @DbName     sysname       = N'$(DbName)';
    DECLARE @AppLabPat  nvarchar(100) = N'$(AppNameLabPattern)';
    DECLARE @AppProPat  nvarchar(100) = N'$(AppNameProdPattern)';
    DECLARE @GroupLab   sysname       = N'$(Group_Lab)';
    DECLARE @GroupPro   sysname       = N'$(Group_Pro)';
    
    IF DB_NAME() = @DbName
    BEGIN
        DECLARE @app nvarchar(128) = APP_NAME();
        IF @app IS NOT NULL
        BEGIN
            IF @app LIKE @AppLabPat
                RETURN @GroupLab;
            IF @app LIKE @AppProPat
                RETURN @GroupPro;
        END
    END

    RETURN @ret; -- NULL => default
END
GO

ALTER RESOURCE GOVERNOR WITH (CLASSIFIER_FUNCTION = master.dbo.ufn_rg_classifier);
ALTER RESOURCE GOVERNOR RECONFIGURE;
GO
