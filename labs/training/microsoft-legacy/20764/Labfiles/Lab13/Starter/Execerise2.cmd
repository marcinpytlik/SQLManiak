SET SUBDIR=%~dp0

SQLCMD -E -i %SUBDIR%Setupfiles\SetupExercise2.sql > %SUBDIR%Setupfiles\Exercise2.txt

