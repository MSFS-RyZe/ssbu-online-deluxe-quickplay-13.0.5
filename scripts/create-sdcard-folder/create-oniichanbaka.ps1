# ==========================================================
# OniichanBaka SD Card Builder
# ==========================================================
# Generates the "OniichanBaka" folder with the full SD card
# structure for SSBU Online Deluxe (adyamox fork).
#
# - Downloads all required dependencies from GitHub releases
# - Copies your locally built libssbu_online_deluxe.nro
# - Creates config.toml with lurk_mode enabled
# ==========================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# --- Output folder ---
$OutputFolder = Join-Path (Split-Path -Parent $ProjectRoot) "OniichanBaka"
if (Test-Path $OutputFolder)
{
    Write-Host "Cleaning output folder: $OutputFolder" -ForegroundColor Yellow
    Remove-Item $OutputFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

# --- Paths ---
$TitleID = "01006A800016E000"
$ExefsFolder = "atmosphere/contents/$TitleID/exefs"
$PluginsFolder = "atmosphere/contents/$TitleID/romfs/skyline/plugins"
$OCServiceFolder = "atmosphere/contents/00FF0000A11CE0FF"
$ConfigFolder = "ultimate/ssbu_online_deluxe"

# Create all directories
$Dirs = @(
    $ExefsFolder,
    $PluginsFolder,
    "$OCServiceFolder/flags",
    $ConfigFolder
)
foreach ($dir in $Dirs)
{
    New-Item -ItemType Directory -Path (Join-Path $OutputFolder $dir) -Force | Out-Null
}

# --- GitHub download helper ---
$Headers = @{
    "User-Agent" = "OniichanBaka-Builder"
    "Accept"     = "application/vnd.github+json"
}
if ($env:GITHUB_TOKEN)
{
    $Headers["Authorization"] = "Bearer $($env:GITHUB_TOKEN)"
}

function Download-FromRelease
{
    param(
        [string]$Repo,
        [string]$FilePattern,
        [string]$DestinationPath
    )
    
    Write-Host "  Downloading from $Repo..." -ForegroundColor Cyan
    try
    {
        $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $Headers -Method Get
        
        foreach ($asset in $release.assets)
        {
            $assetName = $asset.name.ToLowerInvariant()
            
            if ($assetName -like "*.zip")
            {
                $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $asset.name
                $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) ("extract-" + [guid]::NewGuid().ToString("N"))
                
                try
                {
                    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $Headers -OutFile $tempZip
                    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
                    
                    $found = Get-ChildItem -Path $tempExtract -Recurse -File | Where-Object { $_.Name -like $FilePattern }
                    if ($found)
                    {
                        $targetFile = $found | Select-Object -First 1
                        $destFile = Join-Path $DestinationPath $targetFile.Name
                        Copy-Item -Path $targetFile.FullName -Destination $destFile -Force
                        Write-Host "    OK: $($targetFile.Name)" -ForegroundColor Green
                        return $true
                    }
                }
                finally
                {
                    if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
            elseif ($assetName -like $FilePattern.ToLowerInvariant())
            {
                $destFile = Join-Path $DestinationPath $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -Headers $Headers -OutFile $destFile
                Write-Host "    OK: $($asset.name)" -ForegroundColor Green
                return $true
            }
        }
        Write-Warning "    Pattern '$FilePattern' not found in $Repo"
        return $false
    }
    catch
    {
        Write-Warning "    Failed for $Repo : $($_.Exception.Message)"
        return $false
    }
}

function Download-MultiFromRelease
{
    param(
        [string]$Repo,
        [hashtable[]]$FileMappings  # @{ Pattern = "*.nro"; Dest = "path/" }
    )
    
    Write-Host "  Downloading from $Repo..." -ForegroundColor Cyan
    try
    {
        $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -Headers $Headers -Method Get
        
        $remaining = [System.Collections.ArrayList]::new($FileMappings)
        
        foreach ($asset in $release.assets)
        {
            $assetName = $asset.name.ToLowerInvariant()
            
            if ($assetName -like "*.zip")
            {
                $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) $asset.name
                $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) ("extract-" + [guid]::NewGuid().ToString("N"))
                
                try
                {
                    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $Headers -OutFile $tempZip
                    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
                    
                    $allFiles = Get-ChildItem -Path $tempExtract -Recurse -File
                    
                    $toRemove = @()
                    foreach ($mapping in $remaining)
                    {
                        $found = $allFiles | Where-Object { $_.Name -like $mapping.Pattern } | Select-Object -First 1
                        if ($found)
                        {
                            $destFile = Join-Path $mapping.Dest $found.Name
                            Copy-Item -Path $found.FullName -Destination $destFile -Force
                            Write-Host "    OK: $($found.Name)" -ForegroundColor Green
                            $toRemove += $mapping
                        }
                    }
                    foreach ($r in $toRemove) { $remaining.Remove($r) | Out-Null }
                }
                finally
                {
                    if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
                    if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
        }
        
        if ($remaining.Count -gt 0)
        {
            foreach ($m in $remaining) { Write-Warning "    Pattern '$($m.Pattern)' not found" }
        }
    }
    catch
    {
        Write-Warning "    Failed for $Repo : $($_.Exception.Message)"
    }
}

# ==========================================================
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  OniichanBaka SD Card Builder" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta
# ==========================================================

$pluginsAbsPath = Join-Path $OutputFolder $PluginsFolder
$exefsAbsPath = Join-Path $OutputFolder $ExefsFolder
$ocAbsPath = Join-Path $OutputFolder $OCServiceFolder

# 1. Arcropolis
Download-FromRelease -Repo "raytwo/arcropolis" -FilePattern "libarcropolis.nro" -DestinationPath $pluginsAbsPath

# 2. NRO Hook
Download-FromRelease -Repo "ultimate-research/nro-hook-plugin" -FilePattern "libnro_hook.nro" -DestinationPath $pluginsAbsPath

# 3. Smashline
Download-FromRelease -Repo "HDR-Development/smashline" -FilePattern "libsmashline_plugin.nro" -DestinationPath $pluginsAbsPath

# 4. imgui-smash
Download-FromRelease -Repo "Coolsonickirby/imgui-smash" -FilePattern "libimgui_smash.nro" -DestinationPath $pluginsAbsPath

# 5. ssbu-pia-manager
Download-FromRelease -Repo "project-ultelier/ssbu-pia-interface" -FilePattern "libssbu_pia_manager.nro" -DestinationPath $pluginsAbsPath

# 6. ssbu-online-deluxe (upstream — for skyline exefs + ssbusync + overclocker)
Download-MultiFromRelease -Repo "saad-script/ssbu-online-deluxe" -FileMappings @(
    @{ Pattern = "main.npdm"; Dest = $exefsAbsPath },
    @{ Pattern = "subsdk9"; Dest = $exefsAbsPath },
    @{ Pattern = "libssbusync.nro"; Dest = $pluginsAbsPath },
    @{ Pattern = "libnx_over.nro"; Dest = $pluginsAbsPath },
    @{ Pattern = "exefs.nsp"; Dest = $ocAbsPath }
)

# 6b. boot2.flag for overclock service
$flagsPath = Join-Path $OutputFolder "$OCServiceFolder/flags"
if (-not (Test-Path (Join-Path $flagsPath "boot2.flag")))
{
    "" | Out-File -FilePath (Join-Path $flagsPath "boot2.flag") -Encoding ascii -NoNewline
    Write-Host "    OK: boot2.flag (created)" -ForegroundColor Green
}

# 7. YOUR custom-built plugin (replaces upstream)
Write-Host "`n  Copying YOUR built plugin..." -ForegroundColor Yellow
$localNro = Join-Path $ProjectRoot "target\aarch64-skyline-switch\release\libssbu_online_deluxe.nro"
if (Test-Path $localNro)
{
    Copy-Item -Path $localNro -Destination (Join-Path $pluginsAbsPath "libssbu_online_deluxe.nro") -Force
    Write-Host "    OK: libssbu_online_deluxe.nro (local build)" -ForegroundColor Green
}
else
{
    Write-Warning "    LOCAL BUILD NOT FOUND at: $localNro"
    Write-Warning "    Run 'cargo skyline build --release' first, then re-run this script."
}

# 8. Create config.toml with lurk_mode
Write-Host "`n  Creating config.toml..." -ForegroundColor Yellow
$configPath = Join-Path $OutputFolder "$ConfigFolder/config.toml"
$configContent = @"
# ==========================================================
# SSBU Online Deluxe - Configuration File
# OniichanBaka Edition
# ==========================================================

# Lurk Mode (recommended): hide your own data, but still
# see opponents' latency, render profile, etc.
# Peers CAN see you're modded and your [Wired]/[Wifi] type.
lurk_mode = true

# Full Stealth Mode: appear 100% vanilla to everyone.
# WARNING: You will be "blind" to opponents' extended info.
# stealth_mode takes precedence over lurk_mode.
stealth_mode = false

# Built-in Switch Overclocker integration.
# Set to 'false' if you use an external sysmodule (e.g., sys-clk)
overclocker = true

[render_profile_config]
# Profile used in menus (recommended: "Vanilla")
menu = "Vanilla"

# Profiles applied for offline matches
offline_match.singles = "Vanilla"
offline_match.doubles = "Vanilla"

# Profiles selected automatically when in 'Auto' mode
online_match.singles = "LessLag"
online_match.doubles = "LessLagDoubles"
"@
[System.IO.File]::WriteAllText($configPath, $configContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "    OK: config.toml" -ForegroundColor Green

# ==========================================================
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  DONE!" -ForegroundColor Green
Write-Host "  Output: $OutputFolder" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "`nCopy the contents of OniichanBaka to your SD card root (or sdmc/ on emulator).`n" -ForegroundColor Cyan
