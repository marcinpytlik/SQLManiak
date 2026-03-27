namespace SqlOpsLogParser.Core.Abstractions;

public static class ExitCodes
{
    public const int Success = 0;
    public const int GeneralError = 1;
    public const int ConnectionError = 2;
    public const int NoData = 3;
    public const int ValidationError = 4;
}