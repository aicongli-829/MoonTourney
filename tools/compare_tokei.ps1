param(
    [Parameter(Mandatory = $true)]
    [string]$Directory,
    [string]$PortBinary = '_build/native/debug/build/cmd/main/main.exe',
    [string]$UpstreamBinary = 'tokei'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command $UpstreamBinary -ErrorAction SilentlyContinue)) {
    throw "Upstream Tokei not found at $UpstreamBinary."
}
if (-not (Test-Path -LiteralPath $PortBinary -PathType Leaf)) {
    throw "Port binary not found at $PortBinary. Run moon build --target native."
}

$upText = & $UpstreamBinary $Directory -o json
if ($LASTEXITCODE -ne 0) { throw 'Upstream tokei failed.' }
$ourText = & $PortBinary $Directory -o json
if ($LASTEXITCODE -ne 0) { throw 'MoonBit port failed.' }
$up = ConvertFrom-Json -InputObject ($upText -join "`n")
$ours = ConvertFrom-Json -InputObject ($ourText -join "`n")
$names = @($up.PSObject.Properties.Name) + @($ours.PSObject.Properties.Name) | Sort-Object -Unique
$mismatch = 0
foreach ($name in $names) {
    $a = $up.PSObject.Properties[$name].Value
    $b = $ours.PSObject.Properties[$name].Value
    if ($null -eq $a -or $null -eq $b) {
        Write-Output "MISMATCH $name`: one implementation did not report this language"
        $mismatch++
        continue
    }
    $aCounts = @(@($a.reports).Count, $a.code, $a.comments, $a.blanks)
    $bCounts = @(@($b.reports).Count, $b.code, $b.comments, $b.blanks)
    if (($aCounts -join ',') -ne ($bCounts -join ',')) {
        Write-Output "MISMATCH $name`: upstream=[$($aCounts -join ',')] port=[$($bCounts -join ',')]"
        $mismatch++
    }
    if ($name -ne 'Total') {
        $aFiles = @{}
        $bFiles = @{}
        foreach ($report in $a.reports) {
            $path = ([string]$report.name).Replace('\', '/')
            $aFiles[$path] = @($report.stats.code, $report.stats.comments, $report.stats.blanks) -join ','
        }
        foreach ($report in $b.reports) {
            $path = ([string]$report.name).Replace('\', '/')
            $bFiles[$path] = @($report.stats.code, $report.stats.comments, $report.stats.blanks) -join ','
        }
        $paths = @($aFiles.Keys) + @($bFiles.Keys) | Sort-Object -Unique
        foreach ($path in $paths) {
            if ($aFiles[$path] -ne $bFiles[$path]) {
                Write-Output "MISMATCH $name / $path`: upstream=[$($aFiles[$path])] port=[$($bFiles[$path])]"
                $mismatch++
            }
        }
    }
}
if ($mismatch -gt 0) {
    Write-Output "DIFF FAILED: $mismatch language(s) differ."
    exit 1
}
Write-Output 'DIFF OK: all per-language file and line counts agree.'
