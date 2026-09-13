using System;
using System.IO;
using System.Security.Principal;
using Microsoft.SqlServer.Dts.Runtime;

public void Main()
{
    try
    {
        string outputShare = Dts.Variables["User::OutputShare"].Value.ToString();

        if (string.IsNullOrWhiteSpace(outputShare))
        {
            throw new InvalidOperationException("Package variable User::OutputShare is empty.");
        }

        string fileName = $"ssis-proxy-test-{DateTime.Now:yyyyMMdd-HHmmss-fff}.txt";
        string outputFile = Path.Combine(outputShare, fileName);
        string identity = WindowsIdentity.GetCurrent().Name;

        string[] lines =
        {
            "POC Secure SSIS Export - Stage 4",
            $"Timestamp={DateTime.Now:O}",
            $"MachineName={Environment.MachineName}",
            $"WindowsIdentity={identity}",
            $"OutputFile={outputFile}"
        };

        File.WriteAllLines(outputFile, lines);

        if (!File.Exists(outputFile))
        {
            throw new IOException("Output file was not created.");
        }

        Dts.TaskResult = (int)ScriptResults.Success;
    }
    catch (Exception ex)
    {
        Dts.Events.FireError(0, "Stage4 WriteShareTest", ex.ToString(), string.Empty, 0);
        Dts.TaskResult = (int)ScriptResults.Failure;
    }
}