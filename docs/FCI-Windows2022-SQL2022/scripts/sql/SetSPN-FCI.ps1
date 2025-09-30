param([string]$Vnn='SQLSRV-FCI',[string]$Account='sqlmaniak\gmsa_sql$',[int]$Port=1433,[string]$Domain='sqlmaniak.blog')
setspn -S ("MSSQLSvc/{0}:{1}" -f $Vnn,$Port) $Account
setspn -S ("MSSQLSvc/{0}.{1}:{2}" -f $Vnn,$Domain,$Port) $Account
