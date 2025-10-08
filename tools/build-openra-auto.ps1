# build-openra-auto.ps1
# Automated portable build + map bundling for OpenRA
# Produces a self-contained Release folder and (optionally) a .zip

[CmdletBinding()]
param(
  [string]$OutputFolderName,
  [string]$Mod = 'ra',
  [string]$MapGlob = '*.oramap',
  [string]$BaseOut = 'G:\Builds\OpenRA',
  [switch]$Zip,
  [switch]$NoYAMLCheck,
  [switch]$SkipYaml,
  [int]$YamlTimeoutSec = 60
)

$ErrorActionPreference = 'Stop'

# Ensure we operate from the OpenRA project directory regardless of caller CWD
Push-Location $PSScriptRoot
try {
  if (-not (Test-Path '.\OpenRA.sln')) {
    Write-Warning 'This does not look like the repo root (OpenRA.sln not found). Continue anyway...'
  }

  # --- Resolve output folder name (non-interactive) ---
  if ([string]::IsNullOrWhiteSpace($OutputFolderName)) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $folderName = "win-x64_nosingle_$ts"
  } else {
    $folderName = $OutputFolderName
  }

  # Paths
  $outputDir    = Join-Path $BaseOut $folderName
  $launcherProj = '.\OpenRA.Launcher\OpenRA.Launcher.csproj'
  $windowsLauncherProj = '.\OpenRA.WindowsLauncher\OpenRA.WindowsLauncher.csproj'
  $utilityProj  = '.\OpenRA.Utility\OpenRA.Utility.csproj'
  $modsSrc      = '.\mods'
  $stageDir     = Join-Path $PSScriptRoot '_publish_stage'

  # Ensure output dir exists
  if (-not (Test-Path $BaseOut)) { New-Item -ItemType Directory -Force -Path $BaseOut | Out-Null }
  New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
  if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

  Write-Host '=== Restoring solution (with RID) ==='
  & dotnet restore -r win-x64 -p:TargetPlatform=win-x64
  if ($LASTEXITCODE -ne 0) { throw "Restore failed with exit code $LASTEXITCODE." }
  # Ensure Windows launcher has win-x64 assets
  Write-Host '=== Restoring OpenRA.WindowsLauncher (win-x64) ==='
  & dotnet restore '.\OpenRA.WindowsLauncher\OpenRA.WindowsLauncher.csproj' -r win-x64 -p:TargetPlatform=win-x64
  if ($LASTEXITCODE -ne 0) { Write-Warning 'Restore of Windows launcher failed; publish will attempt to restore.' }

  # Prefer publishing the Windows launcher (produces OpenRA.exe). Fallback to generic launcher (OpenRA.dll).
  Write-Host ("=== Publishing OpenRA.WindowsLauncher (Windows .exe) to staging {0} ===" -f $stageDir)
  $publishWinArgs = @(
    'publish', $windowsLauncherProj,
    '-c','Release',
    '-r','win-x64',
    '-p:TargetPlatform=win-x64',
    '-p:UseAppHost=true',
    '-p:SelfContained=true',
    '-p:PublishSingleFile=false',
    '-p:PublishTrimmed=false',
    '-p:PublishReadyToRun=false',
    '-p:LauncherName=OpenRA',
    "-p:ModID=$Mod",
    "-p:DisplayName=OpenRA ($Mod)",
    '-p:FaqUrl=https://github.com/OpenRA/OpenRA/wiki/FAQ',
    '-o', $stageDir
  )
  & dotnet @publishWinArgs
  if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $stageDir 'OpenRA.exe'))) {
    Write-Host 'Published Windows launcher successfully (OpenRA.exe).'
  } else {
    Write-Warning 'Failed to produce Windows .exe or not found. Falling back to generic launcher publish (OpenRA.dll).'
    Write-Host ("=== Publishing OpenRA.Launcher (generic) to staging {0} ===" -f $stageDir)
    $publishArgs = @(
      'publish', $launcherProj,
      '-c','Release',
      '-r','win-x64',
      '-p:TargetPlatform=win-x64',
      '-p:UseAppHost=true',
      '-p:SelfContained=true',
      '-p:PublishSingleFile=false',
      '-p:PublishTrimmed=false',
      '-p:PublishReadyToRun=false',
      '-o', $stageDir
    )
    & dotnet @publishArgs
    if ($LASTEXITCODE -ne 0) { throw "Publish failed with exit code $LASTEXITCODE." }
    if (-not (Test-Path (Join-Path $stageDir 'OpenRA.dll'))) {
      throw 'Generic launcher publish completed but OpenRA.dll not found.'
    }
  }

  # Copy staged publish to final output folder
  Write-Host '=== Copying staged publish to final output ==='
  Copy-Item -Recurse -Force (Join-Path $stageDir '*') $outputDir
  Remove-Item $stageDir -Recurse -Force

  # --- Copy mods ---
  Write-Host '=== Copying mods folder ==='
  if (Test-Path $modsSrc) {
    Copy-Item -Recurse -Force $modsSrc (Join-Path $outputDir 'mods')
    Write-Host ("Mods copied to {0}" -f (Join-Path $outputDir 'mods'))
  } else {
    Write-Warning ("Mods folder not found at {0} - skipping copy." -f $modsSrc)
  }

  # --- Copy georectified .oramap maps into packaged mod ---
  $repoRoot   = Split-Path -Parent $PSScriptRoot
  $mapsSrcRoot = Join-Path $repoRoot 'output'
  $mapsDst     = Join-Path (Join-Path (Join-Path $outputDir 'mods') $Mod) 'maps'
  if (Test-Path $mapsSrcRoot) {
    New-Item -ItemType Directory -Force -Path $mapsDst | Out-Null
    $mapsToCopy = Get-ChildItem -Path $mapsSrcRoot -Recurse -Filter $MapGlob -File -ErrorAction SilentlyContinue
    if ($mapsToCopy -and $mapsToCopy.Count -gt 0) {
      foreach ($m in $mapsToCopy) {
        Copy-Item -Force $m.FullName $mapsDst
        Write-Host ("Copied map: {0} -> {1}" -f $m.Name, $mapsDst)
      }
    } else {
      Write-Host ("No maps matching '{0}' found under {1}. Skipping." -f $MapGlob, $mapsSrcRoot)
    }
  } else {
    Write-Host ("Maps source folder not found: {0}. Skipping copy." -f $mapsSrcRoot)
  }

  # --- Copy engine GLSL shaders ---
  $glslSrc = Join-Path $PSScriptRoot 'glsl'
  if (Test-Path $glslSrc) {
    $glslDst = Join-Path $outputDir 'glsl'
    New-Item -ItemType Directory -Force -Path $glslDst | Out-Null
    Copy-Item -Recurse -Force (Join-Path $glslSrc '*') $glslDst
    Write-Host ("Shaders copied to {0}" -f $glslDst)
  } else {
    Write-Warning ("Shaders directory not found: {0}. The game may fail to start if GLSL files are missing." -f $glslSrc)
  }

  # --- Build and copy platform DLLs (e.g., OpenRA.Platforms.Default.dll) ---
  Write-Host '=== Ensuring platform DLLs are present ==='
  $platformProjects = Get-ChildItem -Recurse -File -Filter 'OpenRA.Platforms.*.csproj' | Sort-Object FullName
  if ($platformProjects.Count -gt 0) {
    foreach ($pp in $platformProjects) {
      $projName = [System.IO.Path]::GetFileNameWithoutExtension($pp.Name)

      Write-Host ("Building {0}" -f $pp.FullName)
      & dotnet build $pp.FullName -c Release -p:TargetPlatform=win-x64 --no-restore
      if ($LASTEXITCODE -ne 0) { throw "Platform project build failed: $($pp.FullName)" }

      $binRoot = Join-Path $PSScriptRoot 'bin'
      if (Test-Path $binRoot) {
        $dll = Get-ChildItem $binRoot -Recurse -File -Filter ($projName + '.dll') |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1
        if ($dll) {
          Copy-Item -Force $dll.FullName $outputDir
          Write-Host ("Copied {0}" -f $dll.Name)

          # Copy platform managed dependencies if present (from the project's bin tree)
          $ppDir = Split-Path -Parent $pp.FullName
          $ppBin = Join-Path $ppDir 'bin'
          $managedDeps = @('OpenAL-CS.dll','SDL2-CS.dll','Freetype6.dll')
          foreach ($dep in $managedDeps) {
            $depFile = Get-ChildItem $ppBin -Recurse -File -Filter $dep -ErrorAction SilentlyContinue |
                       Sort-Object LastWriteTime -Descending |
                       Select-Object -First 1
            if ($depFile) {
              Copy-Item -Force $depFile.FullName $outputDir
              Write-Host ("Copied platform dependency: {0}" -f $depFile.Name)
            }
          }

          # Fallback: ensure critical managed deps are present even if not under platform project bin
          $ensureManaged = @('OpenAL-CS.dll','SDL2-CS.dll','Freetype6.dll')
          foreach ($dep in $ensureManaged) {
            $outDep = Join-Path $outputDir $dep
            if (-not (Test-Path $outDep)) {
              $fallback = Get-ChildItem (Join-Path $PSScriptRoot 'bin') -Recurse -File -Filter $dep -ErrorAction SilentlyContinue |
                         Where-Object { $_.FullName -notmatch '\\obj\\' } |
                         Sort-Object LastWriteTime -Descending |
                         Select-Object -First 1
              if ($fallback) {
                Copy-Item -Force $fallback.FullName $outputDir
                Write-Host ("Copied fallback dependency: {0}" -f $fallback.Name)
              } else {
                Write-Warning ("Could not locate required dependency {0} in repo; game may fail to start." -f $dep)
              }
            }
          }

          # Optionally publish the platform project to capture its .deps.json and runtimes assets
          try {
            $ppStage = Join-Path $PSScriptRoot ("_ppublish_" + $projName)
            if (Test-Path $ppStage) { Remove-Item $ppStage -Recurse -Force }
            New-Item -ItemType Directory -Force -Path $ppStage | Out-Null

            $ppPubArgs = @(
              'publish', $pp.FullName,
              '-c','Release',
              '-r','win-x64',
              '-p:TargetPlatform=win-x64',
              '-p:SelfContained=false',
              '-p:PublishSingleFile=false',
              '-p:PublishTrimmed=false',
              '-p:PublishReadyToRun=false',
              '-o', $ppStage
            )
            & dotnet @ppPubArgs
            if ($LASTEXITCODE -eq 0) {
              $depsPath = Join-Path $ppStage ($projName + '.deps.json')
              if (Test-Path $depsPath) {
                Copy-Item -Force $depsPath $outputDir
                Write-Host ("Copied {0}" -f [System.IO.Path]::GetFileName($depsPath))
              }

              $rtSrc = Join-Path $ppStage 'runtimes'
              if (Test-Path $rtSrc) {
                $rtDst = Join-Path $outputDir 'runtimes'
                Copy-Item -Recurse -Force $rtSrc $rtDst
                Write-Host 'Copied platform runtimes assets.'
              }
            } else {
              Write-Warning ("Publish of {0} returned exit code {1}; continuing without deps.json/runtimes" -f $projName, $LASTEXITCODE)
            }
          } catch {
            Write-Warning ("Platform publish for {0} failed: {1}" -f $projName, $_.Exception.Message)
          } finally {
            if (Test-Path $ppStage) { Remove-Item $ppStage -Recurse -Force }
          }
        } else {
          Write-Warning ("Could not locate {0}.dll under {1}" -f $projName, $binRoot)
        }
      } else {
        Write-Warning ("No bin folder found for {0}" -f $projName)
      }
    }
  } else {
    # Fallback: copy any already-built platform DLLs in repo (exclude obj)
    $existingPlatformDlls = Get-ChildItem -Recurse -File -Filter 'OpenRA.Platforms.*.dll' |
                            Where-Object { $_.FullName -notmatch '\\obj\\' }
    if ($existingPlatformDlls) {
      foreach ($dll in $existingPlatformDlls) {
        Copy-Item -Force $dll.FullName $outputDir
        Write-Host ("Copied {0}" -f $dll.Name)
      }
    } else {
      Write-Warning 'No OpenRA.Platforms.*.csproj or DLLs found. If the game crashes, add a ProjectReference or build the platform project manually.'
    }
  }

  # --- Ensure mod assemblies (OpenRA.Mods.*.dll) are present next to OpenRA.exe ---
  Write-Host '=== Ensuring mod assemblies are present ==='
  $modProjects = Get-ChildItem -Recurse -File -Filter 'OpenRA.Mods.*.csproj' | Sort-Object FullName
  if ($modProjects.Count -gt 0) {
    foreach ($mp in $modProjects) {
      Write-Host ("Building {0}" -f $mp.FullName)
      & dotnet build $mp.FullName -c Release -p:TargetPlatform=win-x64 --no-restore
      if ($LASTEXITCODE -ne 0) { throw "Mod project build failed: $($mp.FullName)" }
    }

    # Copy latest produced OpenRA.Mods.*.dll from repo bin folders (exclude obj)
    $modsFromBin = Get-ChildItem (Join-Path $PSScriptRoot 'bin') -Recurse -File -Filter 'OpenRA.Mods.*.dll' -ErrorAction SilentlyContinue |
                   Where-Object { $_.FullName -notmatch '\\obj\\' } |
                   Sort-Object LastWriteTime -Descending
    $copiedModNames = @{}
    foreach ($dll in $modsFromBin) {
      $name = $dll.Name
      if (-not $copiedModNames.ContainsKey($name)) {
        Copy-Item -Force $dll.FullName $outputDir
        Write-Host ("Copied mod assembly: {0}" -f $dll.Name)
        $copiedModNames[$name] = $true
      }
    }
  } else {
    Write-Warning 'No OpenRA.Mods.*.csproj found. If the game fails with FileNotFound for OpenRA.Mods.*.dll, ensure these projects exist and are built.'
  }

  # Sanity: ensure Common assembly exists (required by ra)
  $commonAssembly = Join-Path $outputDir 'OpenRA.Mods.Common.dll'
  if (-not (Test-Path $commonAssembly)) {
    Write-Warning ("OpenRA.Mods.Common.dll not found in output. The RA mod requires this; the game will crash without it.")
  }

  # --- Resolve and copy managed dependencies for mod assemblies (e.g., TagLibSharp/NVorbis/MP3Sharp/Pfim/etc.) ---
  Write-Host '=== Resolving mod managed dependencies ==='
  if ($modProjects.Count -gt 0) {
    foreach ($mp in $modProjects) {
      $projName = [System.IO.Path]::GetFileNameWithoutExtension($mp.Name)
      $mpStage = Join-Path $PSScriptRoot ("_modpublish_" + $projName)
      if (Test-Path $mpStage) { Remove-Item $mpStage -Recurse -Force }
      New-Item -ItemType Directory -Force -Path $mpStage | Out-Null

      $mpPubArgs = @(
        'publish', $mp.FullName,
        '-c','Release',
        '-r','win-x64',
        '-p:TargetPlatform=win-x64',
        '-p:CopyLocalLockFileAssemblies=true',
        '-p:SelfContained=false',
        '-p:PublishSingleFile=false',
        '-p:PublishTrimmed=false',
        '-p:PublishReadyToRun=false',
        '-o', $mpStage
      )
      & dotnet @mpPubArgs
      if ($LASTEXITCODE -eq 0) {
        $dlls = Get-ChildItem $mpStage -Recurse -File -Filter '*.dll' -ErrorAction SilentlyContinue
        foreach ($d in $dlls) {
          $n = $d.Name
          # Avoid overwriting core engine/platform libraries; include OpenRA.Mods.* and any third-party package dlls
          $isOpenRA = $n -like 'OpenRA.*.dll' -and ($n -notlike 'OpenRA.Mods.*.dll')
          if (-not $isOpenRA) {
            Copy-Item -Force $d.FullName $outputDir
            Write-Host ("Copied mod dependency: {0}" -f $d.Name)
          }
        }
      } else {
        Write-Warning ("Publish of {0} returned exit code {1}; skipping dependency copy for this project." -f $projName, $LASTEXITCODE)
      }

      if (Test-Path $mpStage) { Remove-Item $mpStage -Recurse -Force }
    }
  } else {
    Write-Host 'No mod projects found for dependency publish.'
  }

  # Post-sanity: verify TagLibSharp.dll presence
  $taglib = Join-Path $outputDir 'TagLibSharp.dll'
  if (-not (Test-Path $taglib)) {
    Write-Warning 'TagLibSharp.dll not found in output after mod dependency publish. The game may crash when loading audio metadata.'
    # Fallback: copy mod package DLLs directly from the NuGet global packages cache
    try {
      $nugetRoot = $env:NUGET_PACKAGES
      if ([string]::IsNullOrWhiteSpace($nugetRoot)) {
        $nugetRoot = Join-Path $env:USERPROFILE '.nuget\\packages'
      }
      if (-not (Test-Path $nugetRoot)) {
        Write-Warning ("NuGet packages cache not found at {0}. Skipping fallback copy." -f $nugetRoot)
      } else {
        Write-Host ("Falling back to NuGet cache for mod package DLLs at {0}" -f $nugetRoot)

        foreach ($mp in $modProjects) {
          try {
            [xml]$xml = Get-Content -Raw -LiteralPath $mp.FullName
          } catch {
            Write-Warning ("Failed to parse XML for {0}: {1}" -f $mp.FullName, $_.Exception.Message)
            continue
          }

          $pkgRefs = @()
          foreach ($ig in $xml.Project.ItemGroup) {
            if ($ig.PackageReference) { $pkgRefs += $ig.PackageReference }
          }
          if (-not $pkgRefs) { continue }

          foreach ($pr in $pkgRefs) {
            $id = $pr.Include
            if ([string]::IsNullOrWhiteSpace($id)) { continue }
            # Skip dev-only tools
            if ($id -in @('NuGet.CommandLine')) { continue }

            $ver = $pr.Version
            if ($null -eq $ver -or [string]::IsNullOrWhiteSpace([string]$ver)) {
              # Try nested <Version> element
              try { $ver = [string]$pr.SelectSingleNode('Version').InnerText } catch { $ver = $null }
            } else {
              $ver = [string]$ver
            }

            $pkgPath = Join-Path $nugetRoot ($id.ToLower())
            if (-not (Test-Path $pkgPath)) { continue }
            $verDir = $null
            if (-not [string]::IsNullOrWhiteSpace($ver)) {
              $candidate = Join-Path $pkgPath $ver
              if (Test-Path $candidate) { $verDir = $candidate }
            }
            if (-not $verDir) {
              $verDir = Get-ChildItem -Directory $pkgPath -ErrorAction SilentlyContinue |
                        Sort-Object Name -Descending |
                        Select-Object -First 1 | ForEach-Object { $_.FullName }
            }
            if (-not $verDir) { continue }

            $libRoot = Join-Path $verDir 'lib'
            if (-not (Test-Path $libRoot)) { continue }

            $tfms = @(
              'net8.0','net7.0','net6.0','net5.0',
              'netstandard2.1','netstandard2.0','netstandard1.6','netstandard1.5',
              'net48','net47','net472','net471','net47','net462','net461','net452','net451','net45','net40','net35','net20'
            )
            $copiedAny = $false
            foreach ($tfm in $tfms) {
              $tfmDir = Join-Path $libRoot $tfm
              if (Test-Path $tfmDir) {
                $dlls = Get-ChildItem $tfmDir -File -Filter '*.dll' -ErrorAction SilentlyContinue
                foreach ($d in $dlls) {
                  $n = $d.Name
                  # Avoid copying engine core or framework assemblies to prevent conflicts
                  if ($n -like 'OpenRA.*.dll' -or $n -like 'Microsoft.*.dll' -or $n -like 'System.*.dll') { continue }
                  Copy-Item -Force $d.FullName $outputDir
                  Write-Host ("Copied NuGet package DLL: {0} ({1}\{2})" -f $n, $id, $tfm)
                  $copiedAny = $true
                }
                if ($copiedAny) { break }
              }
            }
            # Fallback: if no known TFM matched, copy any dlls from any lib subfolder
            if (-not $copiedAny) {
              $anyLibDlls = Get-ChildItem $libRoot -Recurse -File -Filter '*.dll' -ErrorAction SilentlyContinue
              foreach ($d in $anyLibDlls) {
                $n = $d.Name
                if ($n -like 'OpenRA.*.dll' -or $n -like 'Microsoft.*.dll' -or $n -like 'System.*.dll') { continue }
                Copy-Item -Force $d.FullName $outputDir
                Write-Host ("Copied NuGet package DLL (fallback): {0} ({1})" -f $n, $id)
                $copiedAny = $true
              }
            }
          }
        }
      }
    } catch {
      Write-Warning ("NuGet fallback copy failed: {0}" -f $_.Exception.Message)
    }

    # Re-check TagLibSharp after NuGet fallback
    if (Test-Path $taglib) {
      Write-Host 'TagLibSharp.dll located via NuGet cache and copied to output.'
    } else {
      Write-Warning 'TagLibSharp.dll still missing after NuGet fallback. The game will likely crash; please verify the NuGet cache and package version.'
    }
  }

  # --- Copy common native DLLs if present (SDL2, OpenAL, freetype, zlib, libpng) ---
  Write-Host '=== Checking for native DLLs (SDL2/OpenAL/etc.) ==='
  $nativeNames = @('SDL2.dll','OpenAL32.dll','freetype6.dll','zlib1.dll','soft_oal.dll')
  $natives = @()
  foreach ($n in $nativeNames) {
    $found = Get-ChildItem -Recurse -File -Filter $n
    if ($found) { $natives += $found }
  }
  $pngs = Get-ChildItem -Recurse -File -Filter 'libpng*.dll'
  if ($pngs) { $natives += $pngs }

  $natives = $natives | Where-Object { $_.FullName -notmatch '\\obj\\' } | Sort-Object FullName -Unique
  if ($natives.Count -gt 0) {
    foreach ($f in $natives) {
      Copy-Item -Force $f.FullName $outputDir
      Write-Host ("Copied native dll: {0}" -f $f.Name)
    }
  } else {
    Write-Host 'No common native DLLs found in repo to copy.'
  }

  # --- Publish/copy Utility (optional) ---
  if (-not ($NoYAMLCheck -or $SkipYaml)) {
    Write-Host '=== Publishing OpenRA.Utility (for YAML check) ==='
    try {
      $utilOut = Join-Path $outputDir '_util_tmp'
      $utilArgs = @(
        'publish', $utilityProj,
        '-c','Release',
        '-r','win-x64',
        '-p:TargetPlatform=win-x64',
        '-p:UseAppHost=true',
        '-p:SelfContained=true',
        '-p:PublishSingleFile=false',
        '-p:PublishTrimmed=false',
        '-p:PublishReadyToRun=false',
        '-o', $utilOut
      )
      & dotnet @utilArgs
      $utilExe = Join-Path $utilOut 'OpenRA.Utility.exe'
      $utilDll = Join-Path $utilOut 'OpenRA.Utility.dll'
      Write-Host '=== Running ra-content --check-yaml ==='
      $timeoutMs = [Math]::Max(1, [int]$YamlTimeoutSec) * 1000
      $proc = $null
      if (Test-Path $utilExe) {
        # Copy the exe and its sidecar dll to output and run with timeout
        Copy-Item -Force $utilExe $outputDir
        if (Test-Path $utilDll) { Copy-Item -Force $utilDll $outputDir }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $utilExe
        $psi.Arguments = 'ra-content --check-yaml'
        $psi.WorkingDirectory = $outputDir
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
      } elseif (Test-Path $utilDll) {
        # Fallback: run via dotnet <dll>
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'dotnet'
        $dllQuoted = '"' + $utilDll + '"'
        $psi.Arguments = $dllQuoted + ' ra-content --check-yaml'
        $psi.WorkingDirectory = $outputDir
        $psi.UseShellExecute = $false
        $proc = [System.Diagnostics.Process]::Start($psi)
      } else {
        Write-Warning 'OpenRA.Utility (exe/dll) not produced; skipping YAML check.'
      }
      if ($null -ne $proc) {
        if (-not $proc.WaitForExit($timeoutMs)) {
          try { $proc.Kill() } catch { }
          Write-Warning ('YAML check timed out after {0}s; continuing.' -f $YamlTimeoutSec)
        } else {
          if ($proc.ExitCode -ne 0) {
            Write-Warning ('YAML check exited with code {0}; continuing.' -f $proc.ExitCode)
          } else {
            Write-Host 'YAML check completed successfully.'
          }
        }
      }
    } catch {
      Write-Warning 'Could not publish OpenRA.Utility (project missing or build failed). Skipping YAML check.'
    }
  } else {
    Write-Host 'Skipping YAML check by request.'
  }

  # --- Optional: Create a zip archive for distribution ---
  if ($Zip) {
    try {
      $zipPath = Join-Path $BaseOut ($folderName + '.zip')
      if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
      Write-Host ('Creating archive: {0}' -f $zipPath)
      Compress-Archive -Path (Join-Path $outputDir '*') -DestinationPath $zipPath -Force
      Write-Host ('Archive created: {0}' -f $zipPath)
    } catch {
      Write-Warning ('Failed to create zip: {0}' -f $_.Exception.Message)
    }
  }

  # --- Sanity checks ---
  Write-Host '=== Sanity checks ==='
  $platPresent = Get-ChildItem -Name 'OpenRA.Platforms.*.dll' -Path $outputDir | ForEach-Object { $_ }
  if (-not $platPresent) { Write-Warning 'No OpenRA.Platforms.*.dll found in output folder.' } else { $platPresent | ForEach-Object { Write-Host ("Found platform dll: {0}" -f $_) } }

  $platDeps = Get-ChildItem -Name 'OpenRA.Platforms.*.deps.json' -Path $outputDir -ErrorAction SilentlyContinue | ForEach-Object { $_ }
  if (-not $platDeps) { Write-Warning 'No OpenRA.Platforms.*.deps.json found in output; native probing via deps may be limited.' } else { $platDeps | ForEach-Object { Write-Host ("Found platform deps: {0}" -f $_) } }

  $hasRuntimes = Test-Path (Join-Path $outputDir 'runtimes')
  if (-not $hasRuntimes) { Write-Warning 'runtimes/ folder not found in output; ensure SDL2/OpenAL native DLLs are present next to the exe.' }

  $maybeSDL = Test-Path (Join-Path $outputDir 'SDL2.dll')
  if (-not $maybeSDL) { Write-Warning 'SDL2.dll not found in output. If graphics still fail, ensure SDL2 is available next to the EXE.' }

  $hasOpenALCS = Test-Path (Join-Path $outputDir 'OpenAL-CS.dll')
  if (-not $hasOpenALCS) { Write-Warning 'OpenAL-CS.dll not found in output. Sound may fail to initialize.' }

  $hasSoftOAL = Test-Path (Join-Path $outputDir 'soft_oal.dll')
  if (-not $hasSoftOAL) { Write-Host 'soft_oal.dll not found. The game will rely on system OpenAL32.dll if available.' }

  $hasCombined = Test-Path (Join-Path $outputDir 'glsl\combined.vert')
  if (-not $hasCombined) { Write-Warning 'GLSL shaders not found in output; the game will not render.' }

  # Verify the selected mod directory exists in the packaged output
  $expectedModDir = Join-Path (Join-Path $outputDir 'mods') $Mod
  if (Test-Path $expectedModDir) {
    Write-Host ("Found mod directory: {0}" -f $expectedModDir)
  } else {
    Write-Warning ("Expected mod directory not found: {0}. Verify the 'mods' tree was copied and the Mod parameter ('{1}') is valid." -f $expectedModDir, $Mod)
  }

  Write-Host ("=== Build complete. Output: {0} ===" -f $outputDir)
  Write-Host 'Start the game by running OpenRA.exe from this folder so the working directory is correct.'
}
finally {
  Pop-Location
}
