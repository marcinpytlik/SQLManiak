using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface IPatchComplianceEvaluator
{
    PatchComplianceResult Evaluate(SqlServerInstanceMetadata metadata, PatchBaseline baseline);
}