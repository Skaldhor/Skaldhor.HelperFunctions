function Get-DmarcRecord{
    [CmdletBinding()] # for standard parameters like -Verbose or -ErrorAction
    param(
        [Parameter(Mandatory=$true, HelpMessage="Domain you want to get the DMARC record for. For example: gmail.com")] [string]$Domain
    )
    try{
        (Resolve-DnsName -Name "_dmarc.$($Domain)" -Type "TXT" -ErrorAction "Stop").Text
    }catch{
        throw "Error during DNS resolution: $($_.Exception.Message)"
    }
    
}

function Get-ExternalTcpConnection{
    try{
        $Connections = Get-NetTCPConnection -ErrorAction "Stop" | Where-Object{($_.RemoteAddress -ne "::") -and ($_.RemoteAddress -ne "::1") -and ($_.RemoteAddress -ne "127.0.0.1") -and ($_.LocalPort -ne 0) -and ($_.RemotePort -ne 0) -and ($_.OwningProcess -ne 0)}
    }catch{
        throw "Error when listing all TCP connections: $($_.Exception.Message)"
    }
    try{
        foreach($Connection in $Connections){
            $OwningProcessInfo = Get-Process -Id $Connection.OwningProcess -ErrorAction "Stop"
            $Connection | Add-Member -NotePropertyName "OwningProcessName" -NotePropertyValue $OwningProcessInfo.ProcessName -ErrorAction "Stop"
            $Connection | Add-Member -NotePropertyName "OwningProcessInfo" -NotePropertyValue $OwningProcessInfo -ErrorAction "Stop"
            $Connection
        }
    }catch{
        throw "Error during process query: $($_.Exception.Message)"
    }
}

function Get-IpConfig{
    # declare paramters
    param(
        [parameter(Mandatory=$false)] [string]$InterfaceAlias
    )

    # get config depending on the $InterfaceAlias input
    if(($null -ne $InterfaceAlias) -and ($InterfaceAlias -ne "")){
        $Configs = Get-NetIPConfiguration -InterfaceAlias $InterfaceAlias
    }else{
        $Configs = Get-NetIPConfiguration
    }
    $Objects = foreach($Config in $Configs){
        # build custom object
        [ordered]@{
            NetworkName = $Config.NetProfile.Name
            Alias = $Config.InterfaceAlias
            Index = $Config.InterfaceIndex
            IPv4Address = $Config.IPv4Address
            IPv4DnsServer = ($Config.DNSServer | Where-Object{$_.AddressFamily -eq 2}).ServerAddresses
            IPv6Address = $Config.IPv6Address
            IPv6DnsServer = ($Config.DNSServer | Where-Object{$_.AddressFamily -eq 23}).ServerAddresses
        }
    }
    $Objects = $Objects | ForEach-Object{New-Object object | Add-Member -NotePropertyMembers $_ -PassThru}
    $Objects | Format-Table
}

function Get-ModulesWithMultipleVersions{
    $AllModules = Get-InstalledModule
    foreach($Module in $AllModules){
        $Versions = Get-InstalledModule -Name $Module.Name -AllVersions
        if($Versions.Count -ge 2){
            Write-Host $Module.Name
        }
    }
}

function Get-MxRecord{
    [CmdletBinding()] # for standard parameters like -Verbose or -ErrorAction
    param(
        [Parameter(Mandatory=$true, HelpMessage="Domain you want to get the MX record for. For example: gmail.com")] [string]$Domain
    )
    try{
        Resolve-DnsName -Name $Domain -Type "MX" -ErrorAction "Stop" | Sort-Object -Property "Preference"
    }catch{
        throw "Error during DNS resolution: $($_.Exception.Message)"
    }
    
}

function Get-PublicIp{
    $PublicIpApiUrls = @(
        "https://ifconfig.me/ip",
        "https://api.myip.com",
        "https://ipinfo.io/ip",
        "https://icanhazip.com"
    )
    foreach($ApiUrl in $PublicIpApiUrls){
        try{
            $Ip = Invoke-RestMethod -Uri $ApiUrl -ErrorAction "Stop"
            Write-Host "Response from '$($ApiUrl)':"
            if($null -ne $Ip.Ip){
                $Ip.Ip
            }else{
                $Ip
            }
            break
        }catch{
            Write-Host "Can't reach '$($ApiUrl)'. Error: $($_.Exception.Message)"
        }
    }
}

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

function Get-SpfRecordEntryIp{
    [CmdletBinding()] # for standard parameters like -Verbose or -ErrorAction
    param(
        [Parameter(Mandatory=$true, HelpMessage="Get IP address for SPF entry in the format 'type:value'. For example: include:spf.protection.outlook.com")] [string]$SpfEntry
    )

    try{
        $Ip = $null
        if($SpfEntry -like "a:*"){
            $Ip = (Resolve-DnsName -Name $SpfEntry.Split(":")[1] -Type "A_AAAA" -ErrorAction "Stop").IPAddress
        }elseif($SpfEntry -like "include:*") {
            $Domains = Resolve-DnsName -Name $SpfEntry.Split(":")[1] -Type "TXT" -ErrorAction "Stop"
            $SpfEntries = $Domains.Text.Split(" ")[1..($Domains.Text.Split(" ").Count - 2)]
            foreach($SpfEntry in $SpfEntries){
                Get-SpfRecordEntryIp -SpfEntry $SpfEntry
            }
        }elseif($SpfEntry -like "ip4:*"){
            $Ip = $SpfEntry.Substring(4,($SpfEntry.length - 4))
        }elseif($SpfEntry -like "ip6:*"){
            $Ip = $SpfEntry.Substring(4,($SpfEntry.length - 4))
        }elseif($SpfEntry -like "mx*"){
            if($SpfEntry -eq "mx"){
                $MxDomain = $Domain
            }elseif($SpfEntry -like "mx:*"){
                $MxDomain = $SpfEntry.Split(":")[1]
            }else{
                throw "Error: Invalid MX record!"
            }

            $Domains = Resolve-DnsName -Name $MxDomain -Type "MX" -ErrorAction "Stop"
            $SpfEntries = $Domains.NameExchange
            foreach($SpfEntry in $SpfEntries){
                Get-SpfRecordEntryIp -SpfEntry "a:$($SpfEntry)"
            }
        }elseif($SpfEntry -like "redirect=*"){
            $TxtRecords = Resolve-DnsName -Name $SpfEntry.Substring(9,($SpfEntry.length - 9)) -Type "TXT" -ErrorAction "Stop"
            $SpfRecord = $TxtRecords | Where-Object{$_.Text -like "v=spf*"}
            if($SpfRecord.Count -gt 1){
                throw "Error: Domain has more than one SPF record!"
            }

            if($SpfRecord.Text -like "*all"){
                $SpfEntries = $SpfRecord.Text.Split(" ")[1..($SpfRecord.Text.Split(" ").Count - 2)]
            }else{
                $SpfEntries = $SpfRecord.Text.Split(" ")[1..($SpfRecord.Text.Split(" ").Count - 1)]
            }

            foreach($SpfEntry in $SpfEntries){
                Get-SpfRecordEntryIp -SpfEntry $SpfEntry
            }
        }else{
            throw "Error: Invalid SPF Syntax in '$($SpfEntry)'!"
        }
        $Ip
    }catch{
        throw "Error during DNS resolution: $($_.Exception.Message)"
    }
}

function Get-SpfRecord{
    [CmdletBinding()] # for standard parameters like -Verbose or -ErrorAction
    param(
        [Parameter(Mandatory=$true, HelpMessage="Domain you want to get the SPF record for. For example: gmail.com")] [string]$Domain
    )
    
    try{
        $TxtRecords = Resolve-DnsName -Name $Domain -Type "TXT" -ErrorAction "Stop"
        $SpfRecord = $TxtRecords | Where-Object{$_.Text -like "v=spf*"}
        if($SpfRecord.Count -gt 1){
            throw "Error: Domain has more than one SPF record!"
        }

        if($SpfRecord.Text -like "*all"){
            $SpfEntries = $SpfRecord.Text.Split(" ")[1..($SpfRecord.Text.Split(" ").Count - 2)]
        }else{
            $SpfEntries = $SpfRecord.Text.Split(" ")[1..($SpfRecord.Text.Split(" ").Count - 1)]
        }

        $ResolvedIps = @()
        foreach($SpfEntry in $SpfEntries){
            $ResolvedIps += Get-SpfRecordEntryIp -SpfEntry $SpfEntry
        }

        Write-Host "SPF Record String:"
        $SpfRecord.Text

        Write-Host ""
        Write-Host ""

        Write-Host "Direct SPF Record entries:"
        $SpfEntries

        Write-Host ""
        Write-Host ""

        Write-Host "All Resolved IPs:"
        $ResolvedIps | Sort-Object -Unique
    }catch{
        throw "Error during DNS resolution: $($_.Exception.Message)"
    }
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

function Remove-OldModuleVersions{
    param(
        [parameter(Mandatory=$true)] [array]$ModuleNames
    )
    if($ModuleNames -ne "All"){
        $Modules = foreach($ModuleName in $ModuleNames){
            try{
                Get-InstalledModule -Name $ModuleName -ErrorAction Stop
            }catch{
                Write-Host "Cannot get module '$($ModuleName)', maybe it is not installed. Error:"
                Write-Host $_.Exception.Message
            }
        }
    }else{
        $Modules = Get-InstalledModule
    }
    foreach($Module in $Modules){
        $Versions = Get-InstalledModule -Name $Module.Name -AllVersions
        if($Versions.Count -eq 1){
            Write-Host "Only one version ($($Versions.Version)) of module '$($Module.Name)' is installed."
        }else{
            $OldVersions = $Versions | Sort-Object -Property "Version" -Top ($Versions.Count - 1)
            foreach($OldVersion in $OldVersions){
                try{
                    Uninstall-Module -Name $OldVersion.Name -RequiredVersion $OldVersion.Version -Force -ErrorAction Stop
                    Write-Host "Uninstalled module '$($OldVersion.Name)' version '$($OldVersion.Version)'."
                }catch{
                    Write-Host "Cannot uninstall module '$($OldVersion.Name)' version '$($OldVersion.Version)'. Error:"
                    Write-Host $_.Exception.Message
                }
            }
            $CurrentVersion = $Versions | Sort-Object -Property "Version" -Bottom 1
            Write-Host "Current version of module '$($CurrentVersion.Name)' is '$($CurrentVersion.Version)'."
        }
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

function Test-PrivateIp{
    param(
        [string]$IpAddress
    )
    # create function to compare IPs
    function Get-Int32FromIp{
        param(
            [string]$Ip
        )
        $IpAddressBytes = [system.net.ipaddress]::Parse($Ip).GetAddressBytes()
        [array]::Reverse($IpAddressBytes)
        $Int32Ip = [system.BitConverter]::ToUInt32($IpAddressBytes, 0)
        $Int32Ip
    }

    # hardcode private IP networks
    $IpRange1Start = Get-Int32FromIp -Ip "10.0.0.0"
    $IpRange1End = Get-Int32FromIp -Ip "10.255.255.255"
    $IpRange2Start = Get-Int32FromIp -Ip "172.16.0.0"
    $IpRange2End = Get-Int32FromIp -Ip "172.31.255.255"
    $IpRange3Start = Get-Int32FromIp -Ip "192.168.0.0"
    $IpRange3End = Get-Int32FromIp -Ip "192.168.255.255"

    # process input IP
    try{
        $IpAddress = Get-Int32FromIp -Ip $IpAddress -ErrorAction "Stop"
    }catch{
        throw $_.Exception.Message
    }
    $IsPrivateIp = $false
    if(($IpRange1Start -le $IpAddress) -and ($IpAddress -le $IpRange1End)){
        $IsPrivateIp = $true
    }elseif(($IpRange2Start -le $IpAddress) -and ($IpAddress -le $IpRange2End)){
        $IsPrivateIp = $true
    }elseif(($IpRange3Start -le $IpAddress) -and ($IpAddress -le $IpRange3End)){
        $IsPrivateIp = $true
    }

    # return boolean
    $IsPrivateIp
}

Export-ModuleMember -Function Get-DmarcRecord, Get-ExternalTcpConnection, Get-IpConfig, Get-ModulesWithMultipleVersions, Get-MxRecord, Get-PublicIp, Get-RegistryItem, Get-SpfRecordEntryIp, Get-SpfRecord, New-RegistryItem, Remove-OldModuleVersions, Remove-RegistryItem, Test-PrivateIp
