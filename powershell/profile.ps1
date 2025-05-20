# Import-Module -Name Terminal-Icons 

Write-Host "🟢 PowerShell $($PSVersionTable.PSVersion) started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Green

. "$PSScriptRoot\functions.ps1"
Set-PSReadlineKeyHandler -Key Ctrl+f -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Show-CommandMenu')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
New-Alias -Name ff -Value Show-CommandMenu

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\tokyonight_storm.omp.json" | Invoke-Expression

# Quick navigation
function proj { Set-Location "C:\\projects" }
function desk { Set-Location "$HOME\Desktop" }
function gs { "git status" | Invoke-Expression }
function gf { "git fetch" | Invoke-Expression }
function gp { "git pull" | Invoke-Expression }

# Aliases
Set-Alias -Name spj -Value Switch-ProjectFolder
