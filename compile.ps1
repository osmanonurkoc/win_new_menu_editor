# --- PS2EXE Module Check ---
$modName = "PS2EXE"
if (!(Get-Module -ListAvailable $modName)) {
    Write-Host "Module $modName not found, installing..." -ForegroundColor Yellow
    Install-Module -Name $modName -Scope CurrentUser -Force
}
Import-Module $modName

# --- Compilation Settings ---
$Params = @{
    InputFile    = ".\New_Menu_Editor.ps1"
    OutputFile   = ".\New_Menu_Editor.exe"
    IconFile     = ".\icon.ico"
    Title        = "Custom Templates Supported New Menu"
    Description  = "Custom Templates Supported New Menu"
    Company      = "Osman Onur Koc"
    Product      = "New Menu Editor"
    Copyright    = "www.osmanonurkoc.com"
    Version      = "1.2.0.0"
    NoConsole    = $true
    STA          = $true  # Critical for WPF
    requireAdmin = $true  # <--- FIXED: The correct parameter name is 'requireAdmin'
}

# --- Icon Check ---
# Note: PS2EXE requires .ico format. Ensure you converted your PNG to ICO.
if (!(Test-Path $Params.IconFile)) {
    Write-Warning "WARNING: icon.ico not found. Using default icon."
    $Params.Remove('IconFile')
}

# --- Start Compilation ---
Write-Host "Starting compilation process..." -ForegroundColor Cyan
try {
    # Invoke-PS2EXE uses the splatted params
    Invoke-PS2EXE @Params
    Write-Host "`nSUCCESS: New_Menu_Editor.exe created successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Error occurred during compilation: $_"
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
