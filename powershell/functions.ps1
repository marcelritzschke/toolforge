$configPath = Join-Path $PSScriptRoot '..\config.json'
$config = Get-Content $configPath | ConvertFrom-Json

$projectFolder = $config.projectFolder
$subfoldersToSearch = $config.projectSubfolders
$maximumRecursionDepth = $config.maximumRecursionDepth


function Show-CommandMenu {
    $commands = @{
        "Switch-ProjectFolder"    = "Switch to a project folder"
        "Open-ProjectFolder"      = "Search and open a project folder in VS Code"
        "Switch-LocalGitBranch"   = "Switch to a local Git branch using fzf"
        "Switch-RemoteGitBranch"  = "Switch to a remote Git branch using fzf"
        "Remove-LocalGitBranches" = "Remove multiple local Git branches using fzf"
        "Stop-Px"                 = "Stop the 'px' process if it is running"
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
    }
}

function Switch-ProjectFolder {
    $null = Get-ProjectFolder_
}

function Open-ProjectFolder {
    $selectedFolder = Get-ProjectFolder_
    if ($selectedFolder) {
        code $selectedFolder
    }
}

function Stop-Px {
    $px = Get-Process -Name "px" -ErrorAction SilentlyContinue
    if ($px) {
        Stop-Process -Name "px" -Force
        Write-Host "Process 'px' has been stopped." -ForegroundColor Green
    } else {
        Write-Host "No 'px' process found." -ForegroundColor Yellow
    }
}

function Switch-LocalGitBranch {
    $branches = git branch
    Invoke-Fzf_ -Prompt "Select branch: " -Options $branches | ForEach-Object { git switch $_.Trim() }
}

function Switch-RemoteGitBranch {
    $branches = git branch -r
    Invoke-Fzf_ -Prompt "Select remote branch: " -Options $branches | ForEach-Object { git switch --track $_.Trim() }
}

function Remove-LocalGitBranches {
    $branches = git branch
    Invoke-Fzf_ -Prompt "Select branches to delete: " -Options $branches -ExtraArgs "-m" | ForEach-Object { git branch -D $_.Trim() }
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
                $allFolders += Get-ChildItem -Path $folder.FullName -Exclude '*.tar' | Select-Object -ExpandProperty FullName
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
    if ($selectedFolder) { Set-Location $selectedFolder }

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
