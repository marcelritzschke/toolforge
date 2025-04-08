# Prerequisites

1. fzf [here](https://github.com/junegunn/fzf)
2. Terminal Icons [here](https://www.powershellgallery.com/packages/Terminal-Icons)
3. oh-my-posh [here](https://ohmyposh.dev/)

# Installation

`<path_to_repository>\powershell\profile.ps1` needs to be loaded with start of PowerShell. You can create a shortcut to do this or if you are using PowerShell from within Windows Terminal (Recommended), then go to your `settings.json` and search for the Powershell entry. There add the following key-value:

```
"commandline": "pwsh -NoExit -ExecutionPolicy Bypass -Command \". <path_to_repository>\\powershell\\profile.ps1\""
```

Alternatively, go into your `$PROFILE` and add the following line

```
. "<path_to_repository>\powershell\profile.ps1"
```
