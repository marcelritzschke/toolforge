# Import-Module -Name Terminal-Icons 

. "$PSScriptRoot\functions.ps1"

Set-PSReadlineKeyHandler -Key Ctrl+f -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Show-CommandMenu')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

New-Alias -Name ff -Value Show-CommandMenu

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\tokyonight_storm.omp.json" | Invoke-Expression
