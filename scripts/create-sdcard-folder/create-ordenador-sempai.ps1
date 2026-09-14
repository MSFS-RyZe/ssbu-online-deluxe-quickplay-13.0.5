# ==========================================================
# Ordenador Sempai - SD Card + Source Code Builder
# ==========================================================
# Genera la carpeta "ordenador_sempai" con:
#   - "codigo" : copia del codigo fuente (sin target/vendor)
#   - "pedro"  : estructura SD card para Switch con
#                atmosphere y los plugins actualizados
# ==========================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# --- Output folder ---
$OutputFolder = Join-Path (Split-Path -Parent $ProjectRoot) "ordenador_sempai"
if (Test-Path $OutputFolder)
{
    Write-Host "Limpiando carpeta de salida: $OutputFolder" -ForegroundColor Yellow
    Remove-Item $OutputFolder -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

# ==========================================================
# PARTE 1: Carpeta "codigo" (fuente)
# ==========================================================
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Creando carpeta 'codigo'..." -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

$CodigoFolder = Join-Path $OutputFolder "codigo"
New-Item -ItemType Directory -Path $CodigoFolder -Force | Out-Null

# Copiar todo excepto target/, vendor/, .git/
$ExcludeDirs = @("target", "vendor", ".git")
$AllItems = Get-ChildItem -Path $ProjectRoot -Force

foreach ($item in $AllItems)
{
    $skip = $false
    foreach ($exc in $ExcludeDirs)
    {
        if ($item.Name -eq $exc)
        {
            $skip = $true
            break
        }
    }
    if (-not $skip)
    {
        $dest = Join-Path $CodigoFolder $item.Name
        if ($item.PSIsContainer)
        {
            Copy-Item -Path $item.FullName -Destination $dest -Recurse -Force
        }
        else
        {
            Copy-Item -Path $item.FullName -Destination $dest -Force
        }
        Write-Host "    OK: $($item.Name)" -ForegroundColor Green
    }
    else
    {
        Write-Host "    SKIP: $($item.Name)" -ForegroundColor DarkGray
    }
}
Write-Host "`n  Carpeta 'codigo' creada OK" -ForegroundColor Green

# ==========================================================
# PARTE 2: Carpeta "pedro" (SD card para Switch)
# ==========================================================
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  Creando carpeta 'pedro'..." -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

$PedroFolder = Join-Path $OutputFolder "pedro"
New-Item -ItemType Directory -Path $PedroFolder -Force | Out-Null

# --- Paths ---
$TitleID = "01006A800016E000"
$ExefsFolder = "atmosphere/contents/$TitleID/exefs"
$PluginsFolder = "atmosphere/contents/$TitleID/romfs/skyline/plugins"
$OCServiceFolder = "atmosphere/contents/00FF0000A11CE0FF"
$ConfigFolder = "ultimate/ssbu_online_deluxe"

# Crear todas las carpetas de la estructura SD
$Dirs = @(
    $ExefsFolder,
    $PluginsFolder,
    "$OCServiceFolder/flags",
    $ConfigFolder
)
foreach ($dir in $Dirs)
{
    New-Item -ItemType Directory -Path (Join-Path $PedroFolder $dir) -Force | Out-Null
}

# --- GitHub download helper ---
$Headers = @{
    "User-Agent" = "OrdenadorSempai-Builder"
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
    
    Write-Host "  Descargando de $Repo..." -ForegroundColor Cyan
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
        Write-Warning "    Patron '$FilePattern' no encontrado en $Repo"
        return $false
    }
    catch
    {
        Write-Warning "    Fallo para $Repo : $($_.Exception.Message)"
        return $false
    }
}

function Download-MultiFromRelease
{
    param(
        [string]$Repo,
        [hashtable[]]$FileMappings
    )
    
    Write-Host "  Descargando de $Repo..." -ForegroundColor Cyan
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
            foreach ($m in $remaining) { Write-Warning "    Patron '$($m.Pattern)' no encontrado" }
        }
    }
    catch
    {
        Write-Warning "    Fallo para $Repo : $($_.Exception.Message)"
    }
}

# ==========================================================
Write-Host "`n--- Descargando dependencias ---`n" -ForegroundColor Yellow
# ==========================================================

$pluginsAbsPath = Join-Path $PedroFolder $PluginsFolder
$exefsAbsPath = Join-Path $PedroFolder $ExefsFolder
$ocAbsPath = Join-Path $PedroFolder $OCServiceFolder

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

# 6. ssbu-online-deluxe (upstream — skyline exefs + ssbusync + overclocker)
Download-MultiFromRelease -Repo "saad-script/ssbu-online-deluxe" -FileMappings @(
    @{ Pattern = "main.npdm"; Dest = $exefsAbsPath },
    @{ Pattern = "subsdk9"; Dest = $exefsAbsPath },
    @{ Pattern = "libssbusync.nro"; Dest = $pluginsAbsPath },
    @{ Pattern = "libnx_over.nro"; Dest = $pluginsAbsPath },
    @{ Pattern = "exefs.nsp"; Dest = $ocAbsPath }
)

# 6b. boot2.flag para overclock service
$flagsPath = Join-Path $PedroFolder "$OCServiceFolder/flags"
if (-not (Test-Path (Join-Path $flagsPath "boot2.flag")))
{
    "" | Out-File -FilePath (Join-Path $flagsPath "boot2.flag") -Encoding ascii -NoNewline
    Write-Host "    OK: boot2.flag (creado)" -ForegroundColor Green
}

# 7. TU plugin compilado (reemplaza el de upstream)
Write-Host "`n  Copiando TU plugin compilado..." -ForegroundColor Yellow
$localNro = Join-Path $ProjectRoot "target\aarch64-skyline-switch\release\libssbu_online_deluxe.nro"
if (Test-Path $localNro)
{
    Copy-Item -Path $localNro -Destination (Join-Path $pluginsAbsPath "libssbu_online_deluxe.nro") -Force
    Write-Host "    OK: libssbu_online_deluxe.nro (build local con fix)" -ForegroundColor Green
}
else
{
    Write-Warning "    BUILD LOCAL NO ENCONTRADO en: $localNro"
    Write-Warning "    Ejecuta 'cargo skyline build --release' primero y luego vuelve a ejecutar este script."
}

# 8. Crear config.toml
Write-Host "`n  Creando config.toml..." -ForegroundColor Yellow
$configPath = Join-Path $PedroFolder "$ConfigFolder/config.toml"
$configContent = @"
# ==========================================================
# SSBU Online Deluxe - Configuration File
# Ordenador Sempai Edition (Pedro)
# ==========================================================
# Fix incluido: Delaymod hookea directamente en Quickplay CSS
# sin necesidad de pasar por Arena primero.
# ==========================================================

# Lurk Mode (recomendado): oculta tus datos pero puedes ver
# la latencia, render profile, etc. del oponente.
# Los peers SI ven que eres modded y tu tipo [Wired]/[Wifi].
lurk_mode = true

# Full Stealth Mode: pareces 100% vanilla para todos.
# AVISO: No veras la info extendida de oponentes.
# stealth_mode tiene prioridad sobre lurk_mode.
stealth_mode = false

# Overclocker integrado de Switch.
# Pon 'false' si usas un sysmodule externo (ej: sys-clk)
overclocker = true

[render_profile_config]
# Perfil usado en menus (recomendado: "Vanilla")
menu = "Vanilla"

# Perfiles para partidas offline
offline_match.singles = "Vanilla"
offline_match.doubles = "Vanilla"

# Perfiles seleccionados automaticamente en modo 'Auto'
online_match.singles = "LessLag"
online_match.doubles = "LessLagDoubles"
"@
[System.IO.File]::WriteAllText($configPath, $configContent, [System.Text.UTF8Encoding]::new($false))
Write-Host "    OK: config.toml" -ForegroundColor Green

# ==========================================================
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  COMPLETADO!" -ForegroundColor Green
Write-Host "  Salida: $OutputFolder" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  ordenador_sempai/" -ForegroundColor Cyan
Write-Host "    codigo/    <- codigo fuente con los fixes" -ForegroundColor White
Write-Host "    pedro/     <- copia esto a la raiz de tu SD" -ForegroundColor White
Write-Host ""
