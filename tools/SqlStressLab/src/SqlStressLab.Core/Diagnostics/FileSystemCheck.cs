namespace SqlStressLab.Core.Diagnostics;

public static class FileSystemCheck
{
    public static bool CanWriteToDirectory(string directoryPath, out string? error)
    {
        try
        {
            Directory.CreateDirectory(directoryPath);
            var file = Path.Combine(directoryPath, $"__writecheck_{Guid.NewGuid():N}.tmp");
            File.WriteAllText(file, "ok");
            File.Delete(file);
            error = null;
            return true;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            return false;
        }
    }
}