function New-TargetList {
<#
.SYNOPSIS
Dynamically builds a list of targetable hosts.

Version: 0.1
Author : Jesse Davis (@secabstraction)
License: BSD 3-Clause

.DESCRIPTION


.PARAMETER NetAddress
Specify an IPv4 network address, requires the NetMask parameter.

.PARAMETER NetMask 
Specify the network mask as an IPv4 address, used with NetAddress parameter.

.PARAMETER StartAddress
Specify an IPv4 address at the beginning of a range of addresses.

.PARAMETER EndAddress
Specify an IPv4 address at the end of a range of addresses.

.PARAMETER Cidr
Specify a single IPv4 network or a list of networks in CIDR notation.

.PARAMETER NoStrikeList
Specify the path to a list of IPv4 addresses that should never be touched.

.PARAMETER ResolveIp
Attemtps to Resolve IPv4 addresses to hostnames using DNS lookups.

.PARAMETER Randomize
Randomizes the list of targets returned.

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254 and 10.10.20.1-10.10.20.254

PS C:\> New-TargetList -Cidr 10.10.10.0/24,10.10.20.0/24

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254

PS C:\> New-TargetList -StartAddress 10.10.10.1 -EndAddress 10.10.10.254

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254

PS C:\> New-TargetList -NetAddress 10.10.10.0 -NetMask 255.255.255.0

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254 and randomizes the output.

PS C:\> New-TargetList -NetAddress 10.10.10.0 -NetMask 255.255.255.0 -Randomize

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254 and returns a list of IP addresses that repsond to ping requests.

PS C:\> New-TargetList -Cidr 10.10.10.0/24 -FindAlives

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254 and returns a list of hostnames that repsond to ping requests and have DNS entries.

PS C:\> New-TargetList -Cidr 10.10.10.0/24 -FindAlives -ResolveIp

.EXAMPLE
The following example builds a list of IP addresses from 10.10.10.1-10.10.10.254 and returns a list of hostnames that repsond to ping requests, have DNS entries, and are not included in a no-strike list.

PS C:\> New-TargetList -Cidr 10.10.10.0/24 -FindAlives -ResolveIp -NoStrikeList C:\pathto\NoStrikeList.txt

.NOTES

#>
    Param(
        [Parameter(ParameterSetName = "NetMask", Position = 0, Mandatory = $true)]
        [String]$NetAddress,
        
        [Parameter(ParameterSetName = "NetMask", Position = 1, Mandatory = $true)]
        [String]$NetMask,

        [Parameter(ParameterSetName = "IpRange", Position = 0, Mandatory = $true)]
        [String]$StartAddress,

        [Parameter(ParameterSetName = "IpRange", Position = 1, Mandatory = $true)]
        [String]$EndAddress,

        [Parameter(ParameterSetName = "Cidr", Position = 0, Mandatory = $true)]
        [String[]]$Cidr,

        [Parameter()]
        [String]$NoStrikeList,

        [Parameter()]
        [Switch]$FindAlives,

        [Parameter()]
        [Switch]$ResolveIp,

        [Parameter()]
        [Switch]$Randomize
    ) #End Param

    #region HELPERS
    function local:Convert-Ipv4ToInt64 {  
        param (
            [Parameter()]
            [String]$Ipv4Address
        )  
            $Octets = $Ipv4Address.split('.')  
            Write-Output ([Int64](  [Int64]$Octets[0] * 16777216 + [Int64]$Octets[1] * 65536 + [Int64]$Octets[2] * 256 + [Int64]$Octets[3]  ))  
    }    
    function local:Convert-Int64ToIpv4 {  
        param (
            [Parameter()]
            [Int64]$Int64
        )   
            Write-Output (([Math]::Truncate($Int64 / 16777216)).ToString() + "." + ([Math]::Truncate(($Int64 % 16777216) / 65536)).ToString() + "." + ([Math]::Truncate(($Int64 % 65536) / 256)).ToString() + "." + ([Math]::Truncate($Int64 % 256)).ToString()) 
    } 
    #endregion HELPERS

    #regex for input validation
    $IPv4 = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
    $IPv4_CIDR = "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/([0-9]|[1-2][0-9]|3[0-2]))$"   
                
    $IpList = New-Object Collections.Arraylist

    #Build IP Address list
    if ($PSCmdlet.ParameterSetName -eq "Cidr") {
        Write-Verbose "Building target list..."
        
        foreach ($Address in $Cidr) {
            if ($Address -notmatch $IPv4_CIDR) {
                Write-Warning "$Address is not a valid CIDR address!"
                continue
            }

            $Split = $Address.Split('/')
            $Net = [Net.IPAddress]::Parse($Split[0])
            $Mask = [Net.IPAddress]::Parse((Convert-Int64ToIpv4 -Int64 ([Convert]::ToInt64(("1" * $Split[1] + "0" * (32 - $Split[1])), 2))))
            
            $Network = New-Object Net.IPAddress ($Mask.Address -band $Net.Address)
            $Broadcast = New-Object Net.IPAddress (([Net.IPAddress]::Parse("255.255.255.255").Address -bxor $Mask.Address -bor $Network.Address))

            $Start = Convert-Ipv4ToInt64 -Ipv4Address $Network.IPAddressToString
            $End = Convert-Ipv4ToInt64 -Ipv4Address $Broadcast.IPAddressToString

            for ($i = $Start + 1; $i -lt $End; $i++) { [void]$IpList.Add((Convert-Int64ToIpv4 -Int64 $i)) }
        } 
    }
    if ($PSCmdlet.ParameterSetName -eq "NetMask") {       
        Write-Verbose "Building target list..."

        if ($NetAddress -notmatch $IPv4) { 
            Write-Warning "$NetAddress is not a valid IPv4 address!"
            break
        }
        if ($NetMask -notmatch $IPv4) { 
            Write-Warning "$NetMask is not a valid network mask!"
            break
        }

        $Net = [Net.IPAddress]::Parse($NetAddress)
        $Mask = [Net.IPAddress]::Parse($NetMask)

        $Network = New-Object Net.IPAddress ($Mask.Address -band $Net.Address)
        $Broadcast = New-Object Net.IPAddress (([Net.IPAddress]::Parse("255.255.255.255").Address -bxor $Mask.Address -bor $Network.Address))

        $Start = Convert-Ipv4ToInt64 -Ipv4Address $Network.IPAddressToString
        $End = Convert-Ipv4ToInt64 -Ipv4Address $Broadcast.IPAddressToString

        for ($i = $Start + 1; $i -lt $End; $i++) { [void]$IpList.Add((Convert-Int64ToIpv4 -Int64 $i)) }
    }
    if ($PSCmdlet.ParameterSetName -eq "IpRange") {
        Write-Verbose "Building target list..."

        if ($StartAddress -notmatch $IPv4) { 
            Write-Warning "$StartAddress is not a valid IPv4 address!"
            break
        }
        if ($EndAddress -notmatch $IPv4) { 
            Write-Warning "$EndAddress is not a valid network mask!"
            break
        }

        $Start = Convert-Ipv4ToInt64 -Ipv4Address $StartAddress
        $End = Convert-Ipv4ToInt64 -Ipv4Address $EndAddress

        for ($i = $Start ; $i -le $End; $i++) { [void]$IpList.Add((Convert-Int64ToIpv4 -Int64 $i)) }
    }

    ######### Remove Assets #########
    if ($PSBoundParameters['NoStrikeList']) {
        $ExclusionList = New-Object Collections.Arraylist

        $NoStrike = Get-Content $NoStrikeList | Where-Object {$_ -notmatch "^#"}
        foreach ($Entry in $NoStrike) {
            if ($Entry -match $IPv4) { $ExclusionList.Add($Entry) }
            else { 
                try { $ResolvedIp = ([Net.DNS]::GetHostByName("$Entry")).AddressList[0].IPAddressToString }
                catch { 
                    Write-Warning "$Entry is not a valid IPv4 address nor resolvable hostname. Check no strike list formatting." 
                    continue
                }
                [void]$ExclusionList.Add($ResolvedIp)
            }
        }       

        $ValidTargets = $IpList | Where-Object { $ExclusionList -notcontains $_ }
    }
    else { $ValidTargets = $IpList }

    ######### Randomize list #########
    if ($Randomize.IsPresent) {
        Write-Verbose "Randomizing target list..."
        $Random = New-Object Random
        $ValidTargets = ($ValidTargets.Count)..1 | ForEach-Object { $Random.Next(0, $ValidTargets.Count) | ForEach-Object { $ValidTargets[$_]; $ValidTargets.RemoveAt($_) } }
    }

    ########## Find Alives & Resolve Hostnames ###########
    if ($FindAlives.IsPresent -and $ResolveIp.IsPresent) {
        Write-Verbose "Pinging hosts..."

        $Pings = New-Object Collections.ArrayList
        $AliveTargets = New-Object Collections.ArrayList

        foreach ($Address in $ValidTargets) {
            [void]$Pings.Add((New-Object Net.NetworkInformation.Ping).SendPingAsync($Address, 250))
        }        
        [Threading.Tasks.Task]::WaitAll($Pings)

        foreach ($Ping in $Pings) {
            if ($Ping.Result.Status -eq [Net.NetworkInformation.IPStatus]::Success) {
                [void]$AliveTargets.Add($Ping.Result.Address.IPAddressToString)
            }
        }
        Write-Verbose "    $($AliveTargets.Count) hosts alive..."

        if ($AliveTargets.Count -lt 1) {
            Write-Warning "No alive hosts found. If hosts are responding to ping, check configuration."
            break
        }
        else {
            Write-Verbose "Resolving hostnames, this may take a while..."

            $ResolvedHosts = New-Object Collections.Arraylist
            $i = 1
            foreach ($Ip in $AliveTargets) {
                #Progress Bar
                Write-Progress -Activity "Resolving Hosts - *This may take a while*" -Status "Hosts Processed: $i of $($AliveTargets.Count)" -PercentComplete ($i / $AliveTargets.Count * 100)
        
                #Resolve the name of the host
                $CurrentEAP = $ErrorActionPreference
                $ErrorActionPreference = "SilentlyContinue"
                [void]$ResolvedHosts.Add(([Net.DNS]::GetHostByAddress($Ip)).HostName)
                $ErrorActionPreference = $CurrentEAP
                
                $i++
            }
            Write-Progress -Activity "Resolving Hosts" -Status "Done" -Completed
            Write-Output $ResolvedHosts
        }
    }
    
    ########## Only Find Alives ##############
    elseif ($FindAlives.IsPresent -and !$ResolveIp.IsPresent) {
        Write-Verbose "Finding alive hosts..."

        $Pings = New-Object Collections.ArrayList
        $AliveTargets = New-Object Collections.ArrayList

        foreach ($Address in $ValidTargets) {
            [void]$Pings.Add((New-Object Net.NetworkInformation.Ping).SendPingAsync($Address, 250))
        }
        
        [Threading.Tasks.Task]::WaitAll($Pings)

        foreach ($Ping in $Pings) {
            if ($Ping.Result.Status -eq [Net.NetworkInformation.IPStatus]::Success) {
                [void]$AliveTargets.Add($Ping.Result.Address.IPAddressToString)
            }
        }

        if ($AliveTargets.Count -lt 1) {
            Write-Warning "No alive hosts found. If hosts are responding to ping, check configuration."
            break
        }  
        else { 
            Write-Verbose "    $($AliveTargets.Count) alive and targetable hosts..."
            Write-Output $AliveTargets 
        }
    }

    ########## Only Resolve Hostnames ########
    elseif ($ResolveIp.IsPresent -and !$FindAlives.IsPresent) {
        Write-Verbose "Resolving hostnames, this may take a while..."

        $ResolvedHosts = New-Object Collections.Arraylist
        $i = 1
        foreach ($Ip in $ValidTargets) {
            #Progress Bar
            Write-Progress -Activity "Resolving Hosts - *This may take a while*" -Status "Hosts Processed: $i of $($ValidTargets.Count)" -PercentComplete ($i / $ValidTargets.Count * 100)
        
            #Resolve the name of the host
            $CurrentEAP = $ErrorActionPreference
            $ErrorActionPreference = "SilentlyContinue"
            [void]$ResolvedHosts.Add(([Net.DNS]::GetHostByAddress($Ip)).HostName)
            $ErrorActionPreference = $CurrentEAP
                
            $i++
        }
        Write-Progress -Activity "Resolving Hosts" -Status "Done" -Completed
        Write-Output $ResolvedHosts
    }
    
    ########## Don't find alives or resolve ########
    else { Write-Output $ValidTargets }
}
