function Test-Port { 
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Int]$Port
    )      
    # Check if port is available
    $IPGlobalProperties = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
    $ActiveTcpConnections = $IPGlobalProperties.GetActiveTcpConnections()
    $ActiveTcpListeners = $IPGlobalProperties.GetActiveTcpListeners()
    $ActiveUdpListeners = $IPGlobalProperties.GetActiveUdpListeners()

    foreach ($Connection in $ActiveTcpConnections) {
        if ($Connection.LocalEndPoint.Port -eq $Port) { 
            Write-Warning "Port $Port is already in use."
            return $false
        }
    }
    foreach ($Listener in $ActiveTcpListeners) {
        if ($Listener.Port -eq $Port) { 
            Write-Warning "Port $Port is already in use."
            return $false
        }
    }
    foreach ($Listener in $ActiveUdpListeners) {
        if ($Listener.Port -eq $Port) { 
            Write-Warning "Port $Port is already in use."
            return $false
        }
    }
    return $true
}
