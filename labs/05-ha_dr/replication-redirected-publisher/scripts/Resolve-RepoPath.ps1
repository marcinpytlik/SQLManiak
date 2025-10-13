param([Parameter(Mandatory)][string]$RelativePath)
$script:Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Join-Path $script:Root $RelativePath
