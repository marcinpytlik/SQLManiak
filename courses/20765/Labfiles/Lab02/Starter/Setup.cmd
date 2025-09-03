@ECHO OFF
ECHO Preparing the lab environment...

MD D:\Labfiles\Lab02\datafiles > NUL
MD D:\Labfiles\Lab02\logfiles > NUL

SUBST L: D:\Labfiles\Lab02\datafiles
SUBST M: D:\Labfiles\Lab02\logfiles

MD L:\SQLTEST\Logs > NUL
MD M:\SQLTEST\Data > NUL






