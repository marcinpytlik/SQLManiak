function Run-Sql
{
    param(
    [string]$ServerInstance,
    [string]$Database,
    [string]$Query,
    [string]$EncryptionStatus,
    [Int32]$QueryTimeout=30
    )

    $conn=new-object System.Data.SqlClient.SQLConnection
    $conn.ConnectionString="Server={0};Database={1};Integrated Security=True;Column Encryption Setting={2};" -f $ServerInstance,$Database,$EncryptionStatus
    $conn.ConnectionString
    
    try 
    {
        $conn.Open()
        $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
        $cmd.CommandTimeout=$QueryTimeout
        $ds=New-Object system.Data.DataSet
        $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$da.fill($ds)
        $conn.Close()
    }
    catch
    {
        if (($conn) -and ($conn.state -ne [System.Data.ConnectionState]"Closed"))
        {$conn.Close()}
        throw $_
    }
    $ds.Tables[0]

}
$qry = "SELECT TOP 10 phone FROM Sales.Customers" 

"Query:"
$qry
"`nWith column encryption disabled in the connection string:"
Run-Sql localhost salesapp1 $qry "Disabled"
"`nWith column encryption enabled in the connection string:"
Run-Sql localhost salesapp1 $qry "Enabled"

"`nDone"

Pause
