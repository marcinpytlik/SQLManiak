REM - Get current directory
SET SUBDIR=%~dp0

REM Remove AdventureWorks folder
RmDir %SUBDIR%AdventureWorks /S /Q

REM Recreate Adventureworks folder
MkDir %SUBDIR%AdventureWorks