# Skaldhor.HelperFunctions

## Description
This PowerShell Module contains helper functions for:\
- easier administration of the Windows Registry
- easier uninstalling of old PowerShell modules from PowerShellGet

## Installation
Run the following command in PowerShell to install the module: `Install-Module -Name "Skaldhor.HelperFunctions"`\
You can also download the module from [PSGallery](https://www.powershellgallery.com/packages/Skaldhor.HelperFunctions).

## Usage
### Overview
Please note that for some cases (registry settings on machine level/uninstalling modules outside your current scope) elevated rights are required.

Import the module with the following command:
`Import-Module -Name "Skaldhor.HelperFunctions"`

Run the commands `Get-RegistryItem`, `New-RegistryItem` and `Remove-RegistryItem` to see, set/create and remove registry items.\
Run the commands `Get-ModulesWithMultipleVersions` and `Remove-OldModuleVersions` to see and modules with multiple versions installed and delete old versions you don't need anymore.

### Examples
`Get-RegistryItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"`

When using `New-RegistryItem` the value for the "Path" parameter must end with the following syntax:\
`<ProperyName.PropertyType>`\
The PropertyType must be one of: "String", "DWord", "QWord", "Binary", "MultiString", "ExpandString", "Unknown", depending on what entry you want to create.\
`New-RegistryItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\TestString.String" -Value "test"`
`New-RegistryItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EnableSomeSettings.DWord" -Value 1`

`Remove-RegistryItem -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\BrowserGuestModeEnabled"`

`Get-ModulesWithMultipleVersions`

`Remove-OldModuleVersions -ModuleNames "Modul1"`
`Remove-OldModuleVersions -ModuleNames "Modul1", "Modul3", "Modul5"`
You can use the the string "All" to uninstall all outdated module versions you have currentyl installed.
`Remove-OldModuleVersions -ModuleNames "All"`
