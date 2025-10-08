## Commands
robocopy "G:\WindSurf\OpenRA_WoW\OpenRA_Wow" "G:\WindSurf\OpenRA_TAK_Lab" /E

powershell -ExecutionPolicy Bypass -File .\build-openra-auto.ps1 -OutputFolderName OpenRA_WoW_RC1 -Mod ra -Zip

make sure  PS G:\WindSurf\OpenRA_WoW\OpenRA_WoW\OpenRA> is the current directory

# Run OpenRA with a specific mod
 - dotnet run --project OpenRA.Launcher/OpenRA.Launcher.csproj -- Engine.EngineDir=".." Game.Mod=ra

# Build OpenRA
.\make.cmd clean -> clean the build directory
.\make.cmd all Release -> build the game in Release configuration
xcopy glsl bin\glsl /E /I /H /Y
Copy the mod folder to bin
.\make.cmd all -> build the game in Debug configuration
.\launch-game.cmd Game.Configuration=Release Game.Mod=ra

# show detailed output about the build process
Set-ExecutionPolicy Bypass -Scope Process -Force
.\build-openra-auto.ps1 -Mod ra -Verbose

# Build OpenRA from source
dotnet build ... → compile the game from source.

cmd /c launch-game.cmd Game.Mod=ra → run the game with a specific mod after it’s built.

dotnet build .\OpenRA.sln -c Debug 
#build the OpenRA solution to verify there are no compilation errors

dotnet build .\OpenRA.sln -c Debug -v minimal

# Run OpenRA
cmd /c launch-game.cmd Game.Mod=ra

# OpenRA Server instructions
dotnet build .\OpenRA.Server\OpenRA.Server.csproj -c Release

dotnet build .\OpenRA.sln -c Release

# Run OpenRA Server
PS G:\WindSurf\OpenRA_WoW\OpenRA> .\launch-dedicated.cmd
.\launch-dedicated.cmd Server.Map=4ponds.oramap Server.AdvertiseOnline=False

# Stop OpenRA Server
Get-Process -Name OpenRA.Server -ErrorAction SilentlyContinue | Stop-Process -Force


# Git branch restore
## Stash local changes if any
git stash -u

## Start a restore branch from current main
git checkout main
git pull --ff-only
git checkout -b restore-to-6c7f428

## Replace working tree/staging with files from that commit
### Use one of these (restore requires Git >= 2.23)
git restore --source 6c7f4280c0a7ac8e9f7aaa13d9b97ef427ab437a -- .
### or
git checkout 6c7f4280c0a7ac8e9f7aaa13d9b97ef427ab437a -- .

## Commit the snapshot
git commit -m "Restore repository contents to snapshot of 6c7f428"

## Push and open PR
git push -u origin restore-to-6c7f428
## Then create a PR: base = main, compare = restore-to-6c7f428