Set-StrictMode -Version Latest

function New-DBACentralSqlConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Server')]
        [string]$ServerInstance,

        [Parameter(Mandatory, Position = 1)]
        [Alias('Database')]
        [string]$DatabaseName,

        [Parameter(Position = 2)]
        [System.Management.Automation.PSCredential]$Credential,

        [string]$ApplicationName = 'DBACentralRepository',

        [int]$ConnectTimeoutSeconds = 15,

        [bool]$Encrypt = $false,

        [bool]$TrustServerCertificate = $true
    )

    $builder =
        New-Object System.Data.SqlClient.SqlConnectionStringBuilder

    $builder['Data Source'] = $ServerInstance
    $builder['Initial Catalog'] = $DatabaseName
    $builder['Application Name'] = $ApplicationName
    $builder['Connect Timeout'] = $ConnectTimeoutSeconds
    $builder['Encrypt'] = $Encrypt
    $builder['TrustServerCertificate'] = $TrustServerCertificate

    if ($null -eq $Credential) {
        $builder['Integrated Security'] = $true
    }
    else {
        $builder['Integrated Security'] = $false
        $builder['User ID'] = $Credential.UserName
        $builder['Password'] =
            $Credential.GetNetworkCredential().Password
    }

    return New-Object System.Data.SqlClient.SqlConnection(
        $builder.ConnectionString
    )
}


function Add-DBACentralSqlParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlCommand]$Command,

        [hashtable]$Parameters = @{}
    )

    foreach ($key in $Parameters.Keys) {
        $value = $Parameters[$key]

        if ($null -eq $value) {
            $value = [DBNull]::Value
        }

        [void]$Command.Parameters.AddWithValue(
            '@' + $key,
            $value
        )
    }
}


function Invoke-DBACentralDataTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Server')]
        [string]$ServerInstance,

        [Parameter(Mandatory, Position = 1)]
        [Alias('Database')]
        [string]$DatabaseName,

        [Parameter(Mandatory, Position = 2)]
        [Alias('Query')]
        [string]$Sql,

        [Parameter(Position = 3)]
        [System.Management.Automation.PSCredential]$Credential,

        [hashtable]$Parameters = @{},

        [int]$CommandTimeoutSeconds = 180,

        [string]$ApplicationName = 'DBACentralRepository Query'
    )

    $connection = New-DBACentralSqlConnection `
        -ServerInstance $ServerInstance `
        -DatabaseName $DatabaseName `
        -Credential $Credential `
        -ApplicationName $ApplicationName

    $command = $null
    $adapter = $null

    try {
        $connection.Open()

        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        $command.CommandTimeout = $CommandTimeoutSeconds

        Add-DBACentralSqlParameters `
            -Command $command `
            -Parameters $Parameters

        $adapter =
            New-Object System.Data.SqlClient.SqlDataAdapter($command)

        $table =
            New-Object System.Data.DataTable

        [void]$adapter.Fill($table)

        # DataTable jest IEnumerable. Bez NoEnumerate PowerShell rozwija go
        # do DataRow[] i późniejsze odwołanie do .Rows kończy się błędem.
        Write-Output -NoEnumerate $table
    }
    finally {
        if ($null -ne $adapter) {
            $adapter.Dispose()
        }

        if ($null -ne $command) {
            $command.Dispose()
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}


function Invoke-DBACentralNonQuery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Server')]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [Alias('Database')]
        [string]$DatabaseName,

        [Parameter(Mandatory)]
        [Alias('Query')]
        [string]$Sql,

        [System.Management.Automation.PSCredential]$Credential,

        [hashtable]$Parameters = @{},

        [int]$CommandTimeoutSeconds = 180,

        [string]$ApplicationName = 'DBACentralRepository NonQuery'
    )

    $connection = New-DBACentralSqlConnection `
        -ServerInstance $ServerInstance `
        -DatabaseName $DatabaseName `
        -Credential $Credential `
        -ApplicationName $ApplicationName

    $command = $null

    try {
        $connection.Open()

        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        $command.CommandTimeout = $CommandTimeoutSeconds

        Add-DBACentralSqlParameters `
            -Command $command `
            -Parameters $Parameters

        return $command.ExecuteNonQuery()
    }
    finally {
        if ($null -ne $command) {
            $command.Dispose()
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}


function Invoke-DBACentralScalar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Server')]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [Alias('Database')]
        [string]$DatabaseName,

        [Parameter(Mandatory)]
        [Alias('Query')]
        [string]$Sql,

        [System.Management.Automation.PSCredential]$Credential,

        [hashtable]$Parameters = @{},

        [int]$CommandTimeoutSeconds = 180,

        [string]$ApplicationName = 'DBACentralRepository Scalar'
    )

    $connection = New-DBACentralSqlConnection `
        -ServerInstance $ServerInstance `
        -DatabaseName $DatabaseName `
        -Credential $Credential `
        -ApplicationName $ApplicationName

    $command = $null

    try {
        $connection.Open()

        $command = $connection.CreateCommand()
        $command.CommandText = $Sql
        $command.CommandTimeout = $CommandTimeoutSeconds

        Add-DBACentralSqlParameters `
            -Command $command `
            -Parameters $Parameters

        return $command.ExecuteScalar()
    }
    finally {
        if ($null -ne $command) {
            $command.Dispose()
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}


function Write-DBACentralBulkCopy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory)]
        [string]$DestinationTable,

        [Parameter(Mandatory)]
        [string]$ServerInstance,

        [Parameter(Mandatory)]
        [string]$DatabaseName,

        [System.Management.Automation.PSCredential]$Credential,

        [int]$CommandTimeoutSeconds = 180,

        [int]$BatchSize = 1000
    )

    if ($DataTable.Rows.Count -eq 0) {
        return 0
    }

    $connection = New-DBACentralSqlConnection `
        -ServerInstance $ServerInstance `
        -DatabaseName $DatabaseName `
        -Credential $Credential `
        -ApplicationName 'DBACentralRepository Bulk Copy'

    $bulkCopy = $null

    try {
        $connection.Open()

        $bulkCopy =
            New-Object System.Data.SqlClient.SqlBulkCopy($connection)

        $bulkCopy.DestinationTableName = $DestinationTable
        $bulkCopy.BulkCopyTimeout = $CommandTimeoutSeconds
        $bulkCopy.BatchSize = $BatchSize

        foreach ($column in $DataTable.Columns) {
            [void]$bulkCopy.ColumnMappings.Add(
                $column.ColumnName,
                $column.ColumnName
            )
        }

        $bulkCopy.WriteToServer($DataTable)

        return $DataTable.Rows.Count
    }
    finally {
        if ($null -ne $bulkCopy) {
            $bulkCopy.Dispose()
        }

        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}


function Add-DBACentralCommonColumns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory)]
        [long]$ScanRunId,

        [Parameter(Mandatory)]
        [long]$InstanceId,

        [Parameter(Mandatory)]
        [datetime]$CapturedAt
    )

    $definitions = @(
        @('ScanRunId', [long]),
        @('InstanceId', [long]),
        @('CapturedAt', [datetime])
    )

    foreach ($definition in $definitions) {
        if (-not $DataTable.Columns.Contains($definition[0])) {
            [void]$DataTable.Columns.Add(
                $definition[0],
                $definition[1]
            )
        }
    }

    foreach ($row in $DataTable.Rows) {
        $row['ScanRunId'] = $ScanRunId
        $row['InstanceId'] = $InstanceId
        $row['CapturedAt'] = $CapturedAt
    }
}


function Add-DBACentralScanIdentityColumns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory)]
        [long]$ScanRunId,

        [Parameter(Mandatory)]
        [long]$InstanceId
    )

    if (-not $DataTable.Columns.Contains('ScanRunId')) {
        [void]$DataTable.Columns.Add('ScanRunId', [long])
    }

    if (-not $DataTable.Columns.Contains('InstanceId')) {
        [void]$DataTable.Columns.Add('InstanceId', [long])
    }

    foreach ($row in $DataTable.Rows) {
        $row['ScanRunId'] = $ScanRunId
        $row['InstanceId'] = $InstanceId
    }
}


function ConvertFrom-DBACentralDataTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]$DataTable
    )

    foreach ($row in $DataTable.Rows) {
        $result = [ordered]@{}

        foreach ($column in $DataTable.Columns) {
            $value = $row[$column.ColumnName]

            if ($value -is [DBNull]) {
                $value = $null
            }

            $result[$column.ColumnName] = $value
        }

        [pscustomobject]$result
    }
}


function ConvertTo-DBACentralSafePathName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [int]$MaximumLength = 120
    )

    $result = $Name

    foreach ($invalidCharacter in [System.IO.Path]::GetInvalidFileNameChars()) {
        $result = $result.Replace(
            [string]$invalidCharacter,
            '-'
        )
    }

    $result = $result.Trim().TrimEnd('.')

    if ([string]::IsNullOrWhiteSpace($result)) {
        return 'Brak nazwy'
    }

    if ($MaximumLength -gt 0 -and $result.Length -gt $MaximumLength) {
        $result = $result.Substring(0, $MaximumLength).Trim()
    }

    return $result
}


function ConvertTo-DBACentralHtml {
    [CmdletBinding()]
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value -or $Value -is [DBNull]) {
        return ''
    }

    return [System.Net.WebUtility]::HtmlEncode(
        [string]$Value
    )
}


function Get-DBACentralDataRowValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [System.Data.DataRow]$Row,

        [Parameter(Mandatory)]
        [string]$ColumnName
    )

    if ($null -eq $Row) {
        return ''
    }

    $value = $Row[$ColumnName]

    if ($value -is [DBNull]) {
        return ''
    }

    return [string]$value
}


Export-ModuleMember -Function @(
    'New-DBACentralSqlConnection',
    'Invoke-DBACentralDataTable',
    'Invoke-DBACentralNonQuery',
    'Invoke-DBACentralScalar',
    'Write-DBACentralBulkCopy',
    'Add-DBACentralCommonColumns',
    'Add-DBACentralScanIdentityColumns',
    'ConvertFrom-DBACentralDataTable',
    'ConvertTo-DBACentralSafePathName',
    'ConvertTo-DBACentralHtml',
    'Get-DBACentralDataRowValue'
)
