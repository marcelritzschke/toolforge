$configPath = Join-Path $PSScriptRoot '..\config.json'
$config = Get-Content $configPath | ConvertFrom-Json

$projectFolder = $config.projectFolder
$subfoldersToSearch = $config.projectSubfolders
$maximumRecursionDepth = $config.maximumRecursionDepth

function fzfForFolder {
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
                $allFolders += Get-ChildItem -Path $folder.FullName | Select-Object -ExpandProperty FullName
            }
        } else {
            Write-Host "No matching folders found for: $subfolder" -ForegroundColor Yellow
        }
    }

    # Add all folders in the project folder to the list
    $allFolders += Get-ChildItem -Directory $projectFolder | Select-Object -ExpandProperty FullName

    # Use fzf to select a folder
    $relativeFolders = $allFolders | ForEach-Object { $_ -replace [regex]::Escape($projectFolder + '\'), '' }
    $selectedRelativeFolder = $relativeFolders | fzf
    $selectedFolder = if ($selectedRelativeFolder) { Join-Path $projectFolder $selectedRelativeFolder.TrimStart('\') }
    if ($selectedFolder) { Set-Location $selectedFolder }

    return $selectedFolder
}

<#
.SYNOPSIS
Lets you fuzzy find a folder in the project directory, cd to the selected location and optionally open it in Visual Studio Code. Use config.json file to select the project folder and subfolders that shall be listed as well.
#>
function cdp {
    param (
        [boolean]$openVsCode = $False
    )

    if ($openVsCode) {
        $selectedFolder = fzfForFolder
        if ($selectedFolder) {
            code $selectedFolder
        }
    } else {
        $null = fzfForFolder
    }
}
