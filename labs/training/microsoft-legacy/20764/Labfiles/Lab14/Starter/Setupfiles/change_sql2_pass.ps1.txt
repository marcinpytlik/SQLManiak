$Service = Get-WmiObject -Class Win32_Service -Filter  "Name = 'MSSQL`$SQL2'"
$Service.Change($Null,$Null,$Null,$Null,$Null,$Null,$Null,"badpass",$Null,$Null,$Null)
