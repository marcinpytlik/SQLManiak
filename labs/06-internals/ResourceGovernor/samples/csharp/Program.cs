using System;
using System.Data;
using Microsoft.Data.SqlClient;

/*
 * APP_NAME() ADO.NET demo:
 *  - Tworzy dwie sesje: Application Name=TwojaApp-LAB oraz TwojaApp-PROD
 *  - Odczytuje przypisanie do Workload Group i Resource Pool
 *
 * Uruchom:
 *   dotnet run --project samples/csharp/AppNameDemo.csproj -- --server localhost --db TwojaBaza
 *   # lub logowanie SQL:
 *   dotnet run --project samples/csharp/AppNameDemo.csproj -- --server localhost --db TwojaBaza --user sa --password P@ssw0rd
 */

class Args
{
    public string Server { get; set; } = "localhost";
    public string Database { get; set; } = "TwojaBaza";
    public string? User { get; set; }
    public string? Password { get; set; }
}

static class Program
{
    static int Main(string[] raw)
    {
        var a = Parse(raw);

        string baseCs = a.User is null
            ? $"Server={a.Server};Database={a.Database};Integrated Security=true;Trust Server Certificate=true;"
            : $"Server={a.Server};Database={a.Database};User ID={a.User};Password={a.Password};Trust Server Certificate=true;";

        TestOne(baseCs + "Application Name=TwojaApp-LAB;", "LAB");
        TestOne(baseCs + "Application Name=TwojaApp-PROD;", "PROD");
        Console.WriteLine("\nUwaga: APP_NAME() jest ustalane przy logowaniu – zmień connection string i otwórz nowe połączenie, aby przełączyć grupę.");
        return 0;
    }

    static void TestOne(string cs, string label)
    {
        Console.WriteLine($"\n== Sesja {label} ==");
        using var con = new SqlConnection(cs);
        con.Open();
        using var cmd = con.CreateCommand();
        cmd.CommandText = @"
SELECT @@SPID AS spid, APP_NAME() AS app_name, ORIGINAL_LOGIN() AS login_name,
       DB_NAME() AS default_db,
       wg.name AS workload_group, rp.name AS pool_name
FROM sys.dm_exec_sessions s
JOIN sys.dm_resource_governor_workload_groups wg ON s.group_id = wg.group_id
JOIN sys.dm_resource_governor_resource_pools  rp ON wg.pool_id = rp.pool_id
WHERE s.session_id = @@SPID;";
        using var rdr = cmd.ExecuteReader();
        var dt = new DataTable();
        dt.Load(rdr);
        PrintTable(dt);
    }

    static void PrintTable(DataTable dt)
    {
        foreach (DataColumn c in dt.Columns)
            Console.Write($"{c.ColumnName,20}");
        Console.WriteLine();
        foreach (DataRow r in dt.Rows)
        {
            foreach (var o in r.ItemArray)
                Console.Write($"{(o is null ? "" : o),20}");
            Console.WriteLine();
        }
    }

    static Args Parse(string[] raw)
    {
        var a = new Args();
        for(int i=0;i<raw.Length;i++)
        {
            switch(raw[i])
            {
                case "--server": a.Server = raw[++i]; break;
                case "--db": a.Database = raw[++i]; break;
                case "--user": a.User = raw[++i]; break;
                case "--password": a.Password = raw[++i]; break;
            }
        }
        return a;
    }
}
