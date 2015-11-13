function Test-Port { 
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Int]$Number,

        [Parameter(Position = 1)]
        [ValidateSet('Tcp','Udp')]
        [String]$Transport
    )      
    
    $IPGlobalProperties = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()

    if ($Transport -eq 'Tcp') {       
        foreach ($Connection in $IPGlobalProperties.GetActiveTcpConnections()) {
            if ($Connection.LocalEndPoint.Port -eq $Number) { 
                Write-Warning "Port $Number`:Tcp is already in use."
                return $false
            }
        }
        foreach ($Listener in $IPGlobalProperties.GetActiveTcpListeners()) {
            if ($Listener.Port -eq $Number) { 
                Write-Warning "Port $Number`:Tcp is already in use."
                return $false
            }
        }
    }
    elseif ($Transport -eq 'Udp') {       
        foreach ($Listener in $IPGlobalProperties.GetActiveUdpListeners()) {
            if ($Listener.Port -eq $Number) { 
                Write-Warning "Port $Number`:Udp is already in use."
                return $false
            }
        }
    }
    else { # check both Tcp & Udp
        foreach ($Connection in $IPGlobalProperties.GetActiveTcpConnections()) {
            if ($Connection.LocalEndPoint.Port -eq $Number) { 
                Write-Warning "Port $Number`:Tcp is already in use."
                return $false
            }
        }
        foreach ($Listener in $IPGlobalProperties.GetActiveTcpListeners()) {
            if ($Listener.Port -eq $Number) { 
                Write-Warning "Port $Number`:Tcp is already in use."
                return $false
            }
        }
        foreach ($Listener in $IPGlobalProperties.GetActiveUdpListeners()) {
            if ($Listener.Port -eq $Number) { 
                Write-Warning "Port $Number`:Udp is already in use."
                return $false
            }
        }
    }
    return $true
}