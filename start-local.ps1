param(
    [string]$PgBin = 'C:\Program Files\PostgreSQL\17\bin',
    [int]$Port = 55439,
    [switch]$Stop
)
$ErrorActionPreference = 'Stop'
$localDir = Join-Path $PSScriptRoot '.local'
$dataDir = Join-Path $localDir 'data'
$settingsFile = Join-Path $localDir 'connection.json'
$ctl = Join-Path $PgBin 'pg_ctl.exe'
$psql = Join-Path $PgBin 'psql.exe'
if (!(Test-Path -LiteralPath $ctl)) { throw "PostgreSQL not found in $PgBin" }
if ($Stop) {
    & $ctl -D $dataDir -m fast -w stop
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop local PostgreSQL.' }
    return
}
New-Item -ItemType Directory -Path $localDir -Force | Out-Null
if (!(Test-Path -LiteralPath $settingsFile)) {
    if (Test-Path -LiteralPath $dataDir) { throw 'Existing data without connection.json; inspect before continuing.' }
    $settings = @{
        adminPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        appPassword = [guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')
        port = $Port
    }
    $settings | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
} else {
    $settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
    $Port = $settings.port
}
if (!(Test-Path -LiteralPath (Join-Path $dataDir 'PG_VERSION'))) {
    $pwFile = Join-Path $localDir 'init-password.tmp'
    [IO.File]::WriteAllText($pwFile, $settings.adminPassword)
    try {
        & (Join-Path $PgBin 'initdb.exe') -D $dataDir -U postgres --encoding=UTF8 --locale=C --auth=scram-sha-256 "--pwfile=$pwFile"
        if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL initialization failed.' }
    } finally { Remove-Item -LiteralPath $pwFile -Force -ErrorAction SilentlyContinue }
}
& $ctl -D $dataDir status *> $null
if ($LASTEXITCODE -ne 0) {
    # Separate file handles prevent the background server from keeping a
    # redirected PowerShell output pipeline open after pg_ctl exits.
    $logPath = Join-Path $localDir 'server.log'
    $startArgs = @('-D', ('"' + $dataDir + '"'), '-l', ('"' + $logPath + '"'), '-o', ('"-h 127.0.0.1 -p ' + $Port + '"'), '-w', 'start')
    $started = Start-Process -FilePath $ctl -ArgumentList $startArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $localDir 'start.stdout.log') -RedirectStandardError (Join-Path $localDir 'start.stderr.log')
    $started.WaitForExit()
    # Windows PowerShell may expose a null Process.ExitCode even when pg_ctl
    # succeeds. Check the listening server instead; authenticated SQL below
    # additionally verifies that the expected catalog is available.
    & (Join-Path $PgBin 'pg_isready.exe') -h 127.0.0.1 -p $Port -t 5 -q
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL failed to start. See .local/server.log.' }
}
$oldPassword = $env:PGPASSWORD
$oldAppPassword = $env:CATALOG_DB_PASSWORD
$oldEncoding = $env:PGCLIENTENCODING
try {
    $env:PGCLIENTENCODING = 'UTF8'
    $env:PGPASSWORD = $settings.adminPassword
    $env:CATALOG_DB_PASSWORD = $settings.appPassword
    & $psql -X -h 127.0.0.1 -p $Port -U postgres -d postgres -f (Join-Path $PSScriptRoot 'bootstrap.sql')
    if ($LASTEXITCODE -ne 0) { throw 'Role/database creation failed.' }
    $env:PGPASSWORD = $settings.appPassword
    $exists = & $psql -X -h 127.0.0.1 -p $Port -U catalog_app -d course_catalog -tAc "SELECT to_regclass('public.courses') IS NOT NULL"
    if ($LASTEXITCODE -ne 0) { throw 'Cannot connect as catalog_app.' }
    if ($exists -eq 'f') {
        foreach ($file in @('schema.sql','seed.sql','queries.sql','verify.sql')) {
            & $psql -X -h 127.0.0.1 -p $Port -U catalog_app -d course_catalog -v ON_ERROR_STOP=1 -f (Join-Path $PSScriptRoot $file)
            if ($LASTEXITCODE -ne 0) { throw "Failed: $file" }
        }
    } else {
        Write-Host 'Existing catalog preserved.'
        & $psql -X -h 127.0.0.1 -p $Port -U catalog_app -d course_catalog -c 'SELECT id,title,likes FROM courses ORDER BY id'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read existing courses.' }
    }
    Write-Host "Database: 127.0.0.1:$Port/course_catalog; role catalog_app"
} finally {
    $env:PGPASSWORD = $oldPassword
    $env:CATALOG_DB_PASSWORD = $oldAppPassword
    $env:PGCLIENTENCODING = $oldEncoding
}
