namespace SqlOpsLogParser.Core.Enums;

public enum EventCategory
{
    General = 0,
    Security = 1,
    Backup = 2,
    Restore = 3,
    Recovery = 4,
    Availability = 5,
    IO = 6,
    Memory = 7,
    Deadlock = 8,
    Agent = 9,
    Shutdown = 10,
    Startup = 11,
    Trace = 12,
    ExtendedEvents = 13,
    Corruption = 14
}