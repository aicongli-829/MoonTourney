$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $taskRoot
try {
  $taskMoonHome = Join-Path $taskRoot '.tools/moon'
  if (Test-Path -LiteralPath (Join-Path $taskMoonHome 'bin/moon.exe')) {
    $env:MOON_HOME = $taskMoonHome
    $env:Path = "$taskMoonHome/bin;$env:Path"
  }
  & moon fmt --check
  if ($LASTEXITCODE -ne 0) { throw 'Formatting check failed.' }
  foreach ($taskTarget in @('js', 'wasm-gc', 'native')) {
    & moon check --target $taskTarget --deny-warn
    if ($LASTEXITCODE -ne 0) { throw "Type check failed: $taskTarget" }
    & moon test --target $taskTarget --deny-warn
    if ($LASTEXITCODE -ne 0) { throw "Tests failed: $taskTarget" }
  }
  & node scripts/build.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }
  & node tests/smoke.mjs
  if ($LASTEXITCODE -ne 0) { throw 'CLI / engine integration failed.' }
} finally { Pop-Location }
