# Skaldhor.HelperFunctions

## Description
This PowerShell Module contains helper functions for easier administration of the Windows Registry.

## Installation
Run the following command in PowerShell to install the module:
`Install-Module -Name "Skaldhor.HelperFunctions"`

You can also download the module from [PSGallery](https://www.powershellgallery.com/packages/Skaldhor.HelperFunctions).

## Usage
### Overview
Import the module with the following command:
`Import-Module -Name "Skaldhor.HelperFunctions"`

Run the commands `Get-RegistryItem`, `New-RegistryItem` and `Remove-RegistryItem` to see, set/create and remove registry items.

### Examples
`Get-RegistryItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion"`

When using `New-RegistryItem` the value for the "Path" parameter must end with the syntax "<ProperyName.PropertyType>".\
The PropertyType must be one of: "String", "DWord", "QWord", "Binary", "MultiString", "ExpandString", "Unknown", depending on what entry you want to create.\
`New-RegistryItem -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\TestString.String" -Value "test"`

`Remove-RegistryItem -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\BrowserGuestModeEnabled"`
