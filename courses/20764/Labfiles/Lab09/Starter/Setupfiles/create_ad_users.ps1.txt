$groups = "IT_Support","Sales_Asia","Sales_Europe","Sales_NorthAmerica","Sales_Managers","Database_Managers","HumanResources_Users", "InternetSales_Users","InternetSales_Managers"

#users
$users = "AnthonyFrizzell","WebApplicationSvc","DanDrayton","DeannaBall","ExtractUser"

#members (<member> <group>)
$members = @("IT_Support","HumanResources_Users"),
@("Sales_Asia","HumanResources_Users"),
@("Sales_Europe","HumanResources_Users"),
@("Sales_NorthAmerica","HumanResources_Users"),
@("Sales_Managers","HumanResources_Users"),
@("AnthonyFrizzell","HumanResources_Users"),
@("DanDrayton","HumanResources_Users"),
@("DeannaBall","HumanResources_Users")

$secure = convertto-securestring -string "Pa`$`$w0rd"  -asplaintext -force

foreach ($g in $groups)
{
    if (-Not (Get-ADGroup -filter {name -eq $g})) 
    {
        New-ADGroup $g 1
    }
}

foreach ($u in $users)
{
    #remove and recreate user to sort out group memberships
    if (Get-ADUser -filter {name -eq $u})
    {
        Remove-ADUser -Identity $u -Confirm:$false
    }
    New-ADUser $u -ChangePasswordAtLogon $false -AccountPassword $secure -Enabled $true
}

foreach ($m in $members)
{
    Add-ADGroupMember $m[1] $m[0]
}