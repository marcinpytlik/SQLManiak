using System.IO.Compression;

namespace SqlStressLab.Core.Services;

public static class ZipBundleWriter
{
    public static string CreateZip(string sourceDirectory, string outputZipPath)
    {
        if (File.Exists(outputZipPath))
            File.Delete(outputZipPath);

        ZipFile.CreateFromDirectory(sourceDirectory, outputZipPath, CompressionLevel.Optimal, false);
        return outputZipPath;
    }
}