$paths = @(
    (Join-Path $env:APPDATA 'OpenRA\Logs'),
    (Join-Path $env:USERPROFILE 'Documents\OpenRA\Logs')
)

foreach ($p in $paths) {
    if (Test-Path $p) {
        Write-Output ("DIR: $p")
        Get-ChildItem -Path $p -File |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 30 |
            Select-Object @{Name='LastWriteTime';Expression={$_.LastWriteTime}}, @{Name='Size';Expression={$_.Length}}, @{Name='Name';Expression={$_.Name}} |
            Format-Table -AutoSize
        Write-Output ""
    }
}
