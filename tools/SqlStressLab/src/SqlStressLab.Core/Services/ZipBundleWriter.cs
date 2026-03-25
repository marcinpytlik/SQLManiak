using System.IO.Compression;

namespace SqlStressLab.Core.Services;

public static class ZipBundleWriter
{
    public static void CreateBundle(string outputZipPath, IEnumerable<string> files)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(outputZipPath);
        ArgumentNullException.ThrowIfNull(files);

        var fullOutputPath = Path.GetFullPath(outputZipPath);
        var outputDirectory = Path.GetDirectoryName(fullOutputPath) ?? Directory.GetCurrentDirectory();

        Directory.CreateDirectory(outputDirectory);

        if (File.Exists(fullOutputPath))
        {
            File.Delete(fullOutputPath);
        }

        using var archive = ZipFile.Open(fullOutputPath, ZipArchiveMode.Create);

        foreach (var file in files.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (!File.Exists(file))
                continue;

            archive.CreateEntryFromFile(file, Path.GetFileName(file), CompressionLevel.Optimal);
        }
    }
}