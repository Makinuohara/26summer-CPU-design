$ErrorActionPreference = 'Stop'

$pathsToAdd = @(
    'D:\iverilog\bin',
    'D:\Vivado\Vivado\2018.3\bin'
)

$baseUserPaths = @(
    "$env:LOCALAPPDATA\Microsoft\WindowsApps"
)

$ordered = New-Object System.Collections.Generic.List[string]
foreach ($part in @($baseUserPaths + $pathsToAdd)) {
    $trimmed = $part.Trim()
    if ($trimmed.Length -gt 0 -and -not $ordered.Contains($trimmed)) {
        $ordered.Add($trimmed)
    }
}

$newPath = [string]::Join(';', $ordered)
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host 'User PATH updated. Tool entries:'
foreach ($path in $pathsToAdd) {
    if ($ordered.Contains($path)) {
        Write-Host "  OK $path"
    } else {
        Write-Host "  MISSING $path"
    }
}
