function Get-RegistryItem{
    param(
        [Parameter(Mandatory=$true, HelpMessage="Path in the format 'HKxx:\path\to\registryKey'.")] [string]$Path
    )
    $Key = Get-Item -Path $Path
    $Items = $Key.GetValueNames()
    $ItemList = foreach($Item in $Items){
        [ordered]@{
            Name = $Item
            Type = $Key.GetValueKind($Item)
            Value = $Key.GetValue($Item)
        }
    }
    $ItemObjects = $ItemList | ForEach-Object{New-Object object | Add-Member -NotePropertyMembers $_ -PassThru}
    $ItemObjects
}

function New-RegistryItem{
    param(
        [Parameter(Mandatory=$true, HelpMessage="Path in the format 'HKxx:\path\to\new\item.filetype'. Filetype must be one of: 'String', 'DWord', 'QWord', 'Binary', 'MultiString', 'ExpandString', 'Unknown'.")] [string]$Path,
        [Parameter(Mandatory=$true, HelpMessage="Value for the new item.")] $Value
    )

    # split path to substrings
    $ParentPath = Split-Path -Path $Path -Parent
    $ItemNameArray = (Split-Path -Path $Path -Leaf).Split(".")
    $ItemName = $ItemNameArray[0..(($ItemNameArray).length - 2)] -join "."
    $ItemType = (Split-Path -Path $Path -Leaf).Split(".")[-1]

    # create registry key, if it doesn't exist already
    if((Test-Path -Path $ParentPath) -eq $false){
        New-Item -Path $ParentPath -ItemType Directory -Force
    }

    # create registry item, if it doesn't exist already and delete then recreate it if it exists
    if($null -eq (Get-ItemProperty -Path $ParentPath -Name $ItemName -ErrorAction SilentlyContinue)){
        New-ItemProperty -Path $ParentPath -Name $ItemName -Value $Value -PropertyType $ItemType
    }else{
        Remove-ItemProperty -Path $ParentPath -Name $ItemName -Force -Confirm:$false
        New-ItemProperty -Path $ParentPath -Name $ItemName -Value $Value -PropertyType $ItemType
    }
}

function Remove-RegistryItem{
    param(
        [Parameter(Mandatory=$true, HelpMessage="Path in the format 'HKxx:\path\to\itemToDelete'.")] [string]$Path
    )
    $ParentPath = Split-Path -Path $Path -Parent
    $ItemName = Split-Path -Path $Path -Leaf
    Remove-ItemProperty -Path $ParentPath -Name $ItemName -Force -Confirm:$false
}

Export-ModuleMember -Function Get-RegistryItem, New-RegistryItem, Remove-RegistryItem
