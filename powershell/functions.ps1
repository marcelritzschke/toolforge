$configPath = Join-Path $PSScriptRoot '..\config.json'
$config = Get-Content $configPath | ConvertFrom-Json

$projectFolder = $config.projectFolder
$subfoldersToSearch = $config.projectSubfolders
$maximumRecursionDepth = $config.maximumRecursionDepth
$remoteHosts = $config.remoteHosts


function Show-CommandMenu {
    $commands = @{
        "Switch-ProjectFolder"    = "Switch to a project folder"
        "Open-ProjectFolder"      = "Search and open a project folder in VS Code"
        "Open-RemoteProjectFolder"= "Search and open a remote project folder in VS Code"
        "Switch-LocalGitBranch"   = "Switch to a local Git branch using fzf"
        "Switch-RemoteGitBranch"  = "Switch to a remote Git branch using fzf"
        "Remove-LocalGitBranches" = "Remove multiple local Git branches using fzf"
        "Start-Px"                = "Start the 'px' process with pac script"
        "Stop-Px"                 = "Stop the 'px' process running the pac script"
        "Set-Proxy"               = "Setting proxy environment variables"
        "Remove-Proxy"            = "Unset proxy environment variables"
    }

    # Find max command length for proper alignment
    $maxLength = ($commands.Keys | Measure-Object -Maximum -Property Length).Maximum
    $formattedList = $commands.GetEnumerator() | 
        Sort-Object -Property Key -Descending | 
        ForEach-Object { 
            "{0,-$maxLength}  |  {1}" -f $_.Key, $_.Value 
        }

    $selection = Invoke-Fzf_ -Prompt "Select a command: " -Options $formattedList

    if ($selection) {
        $selectedFunction = $selection -split "\|" | Select-Object -First 1
        $selectedFunction = $selectedFunction.Trim()
        Invoke-Expression $selectedFunction
        [Microsoft.PowerShell.PSConsoleReadLine]::AddToHistory($selectedFunction)
    }
}

function Switch-ProjectFolder {
    $selectedFolder = Get-ProjectFolder_
    if ($selectedFolder) { Set-Location $selectedFolder }
}

function Open-ProjectFolder {
    $selectedFolder = Get-ProjectFolder_
    if ($selectedFolder) {
        code $selectedFolder
    }
}

function Open-RemoteProjectFolder() {
    $hostNames = @($remoteHosts.PSObject.Properties.Name)
    $selectedRemote = Invoke-Fzf_ -Prompt "Select a remote host: " -Options $hostNames
    if (-not $selectedRemote) { return }

    $remoteHost = $selectedRemote.Trim()
    $remoteProjectFolder = $remoteHosts.$remoteHost

    $selectedFolder = Get-RemoteProjectFolder_ -RemoteHost $remoteHost -RemoteProjectFolder $remoteProjectFolder

    if ($selectedFolder) {        
        "code --remote ssh-remote+${remoteHost} ${selectedFolder}" | Invoke-Expression
    }
}

function Set-Proxy() {
    $proxy = $Env:CORPORATE_PROXY

    Write-Output "Setting local http_proxy = $proxy"
    $Env:http_proxy = $proxy

    Write-Output "Setting local https_proxy = $proxy"
    $Env:https_proxy = $proxy
}

function Remove-Proxy() {
    Write-Output "Unset local http_proxy"
    Remove-Item Env:http_proxy -ErrorAction SilentlyContinue
    
    Write-Output "Unset local https_proxy"
    Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
}

function Start-Px([string]$entity = "133") {
    $pac = "$Env:PAC_ADDRESS/$entity/proxy.pac"
    $proxy = "http://127.0.0.1:3128"
    
    $px = Get-Process -Name "px" -ErrorAction SilentlyContinue
    if (!$px) {
        Write-Output "Starting px proxy with pac = $pac..."
        Invoke-Expression "cmd /c start powershell -Command {px --pac=$pac}"
        Start-Sleep 10
    }
    Write-Output "Setting local https_proxy = $proxy"
    $Env:https_proxy = $proxy
}

function Stop-Px {
    $px = Get-Process -Name "px" -ErrorAction SilentlyContinue
    if ($px) {
        Stop-Process -Name "px" -Force
        Write-Host "Process 'px' has been stopped." -ForegroundColor Green
    } else {
        Write-Host "No 'px' process found." -ForegroundColor Yellow
    }
    Write-Output "Unset local https_proxy"
    Remove-Item Env:https_proxy -ErrorAction SilentlyContinue
}

function Switch-LocalGitBranch {
    $branches = git branch
    Invoke-Fzf_ -Prompt "Select branch: " -Options $branches | ForEach-Object { git switch $_.Trim() }
}

function Switch-RemoteGitBranch {
    git fetch | Invoke-Expression
    $branches = git branch -r
    Invoke-Fzf_ -Prompt "Select remote branch: " -Options $branches | ForEach-Object { git switch --track $_.Trim() }
}

function Remove-LocalGitBranches {
    $branches = git branch
    Invoke-Fzf_ -Prompt "Select branches to delete: " -Options $branches -ExtraArgs "-m" | ForEach-Object { git branch -D $_.Trim() }
}

function Get-RemoteProjectFolder_ {
    param (
        [string]$RemoteHost,
        [string]$RemoteProjectFolder
    )

    # Use SSH to list project folders on the remote machine
    $remoteCommand = @"
find $remoteProjectFolder -maxdepth 1 -type d
"@
    $allFolders = ssh $RemoteHost $remoteCommand | ForEach-Object { $_.Trim() }

    if (-not $allFolders) {
        Write-Host "No folders found on remote machine." -ForegroundColor Yellow
        return
    }

    # Use fzf to select a folder
    $selectedFolder = Invoke-Fzf_ -Prompt "Select a remote project: " -Options $allFolders
    if ($selectedFolder) {
        Write-Host "Selected remote folder: $selectedFolder" -ForegroundColor Green
        return $selectedFolder
    }
}

function Get-ProjectFolder_ {
    if (-Not (Test-Path $projectFolder)) {
        Write-Host "Project folder not found: $projectFolder" -ForegroundColor Red
        return
    }

    $allFolders = @()

    # Recursively search for the subfolders and at its childs to the list
    foreach ($subfolder in $subfoldersToSearch) {
        $matchingFolders = Get-ChildItem -Path $projectFolder -Depth $maximumRecursionDepth -Recurse -Directory -Filter $subfolder -ErrorAction SilentlyContinue
        if ($matchingFolders) {
            foreach ($folder in $matchingFolders) {
                $allFolders += Get-ChildItem -Path $folder.FullName -Attributes D | Select-Object -ExpandProperty FullName
            }
        } else {
            Write-Host "No matching folders found for: $subfolder" -ForegroundColor Yellow
        }
    }

    # Add all folders in the project folder to the list
    $allFolders += Get-ChildItem -Directory $projectFolder | Select-Object -ExpandProperty FullName

    # Use fzf to select a folder
    $relativeFolders = $allFolders | ForEach-Object { $_ -replace [regex]::Escape($projectFolder + '\'), '' }
    $selectedRelativeFolder = Invoke-Fzf_ -Prompt "Select a project: " -Options $relativeFolders
    $selectedFolder = if ($selectedRelativeFolder) { Join-Path $projectFolder $selectedRelativeFolder.TrimStart('\') }

    return $selectedFolder
}

function Invoke-Fzf_ {
    param (
        [string]$Prompt = "Select an option: ",
        [string[]]$Options,
        [string]$ExtraArgs = ""
    )

    if ($Options) {
        if ($ExtraArgs) {
            return $Options | fzf --height 40% --border --prompt $Prompt $ExtraArgs
        } else {
            return $Options | fzf --height 40% --border --prompt $Prompt
        }
    } else {
        if ($ExtraArgs) {
            return fzf --height 40% --border --prompt $Prompt $ExtraArgs
        } else {
            return fzf --height 40% --border --prompt $Prompt
        }
    }
}
