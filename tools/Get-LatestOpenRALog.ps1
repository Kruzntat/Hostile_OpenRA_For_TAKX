param([int]$Tail = 400)

$paths = @(
    (Join-Path $env:APPDATA 'OpenRA\Logs'),
    (Join-Path $env:USERPROFILE 'Documents\OpenRA\Logs')
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        $file = Get-ChildItem -Path $p -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($null -ne $file) {
            Write-Output ("LOGDIR: $p")
            Write-Output ("LOGFILE: $($file.FullName)")
            Get-Content -Path $file.FullName -Tail $Tail
            exit 0
        }
    }
}

Write-Output 'No logs found'
