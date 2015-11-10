function New-UdpStream {
[CmdletBinding(DefaultParameterSetName = 'Client')]
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [Int]$Port, 
        
        [Parameter()]
        [Int]$BufferSize = 65536,
        
        [Parameter()]
        [Int]$Timeout = 60
    )

    if ($Listener.IsPresent) {

        $SocketDestinationBuffer = New-Object Byte[] -ArgumentList 65536
        $RemoteEndPoint = New-Object Net.IPEndPoint -ArgumentList @([Net.IPAddress]::Any, $null)
        $UdpClient = New-Object Net.Sockets.UDPClient -ArgumentList $Port
        $PacketInfo = New-Object Net.Sockets.IPPacketInformation

        Write-Verbose "Listening on 0.0.0.0:$Port [udp]"
                
        $ConnectHandle = $UdpClient.Client.BeginReceiveMessageFrom($SocketDestinationBuffer, 0, 65536, [Net.Sockets.SocketFlags]::None, [ref]$RemoteEndPoint, $null, $null)
        
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Warning "Caught escape sequence, stopping UDP Setup."
                    $UdpClient.Dispose()
                    $Stopwatch.Stop()
                    $SocketDestinationBuffer = $null
                    [console]::TreatControlCAsInput = $false
                    return
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping UDP Setup."
                $UdpClient.Dispose()
                $Stopwatch.Stop()
                $SocketDestinationBuffer = $null
                [console]::TreatControlCAsInput = $false
                return
            }
        } until ($ConnectHandle.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        $SocketFlags = 0
        $SocketBytesRead = $UdpClient.Client.EndReceiveMessageFrom($ConnectHandle, [ref]$SocketFlags, [ref]$RemoteEndPoint, [ref]$PacketInfo)
        $UdpClient.Connect($RemoteEndPoint)
                
        if ($SocketBytesRead.Count) { $InitialBytes = $SocketDestinationBuffer[0..($SocketBytesRead - 1)] }

        Write-Verbose "Connection from $($RemoteEndPoint.ToString()) [udp] accepted."

        $Properties = @{
            UdpClient = $UdpClient
            Socket = $UdpClient.Client
            Read = $UdpClient.BeginReceive($null, $null)
        }
        $UdpStream = New-Object -TypeName psobject -Property $Properties
    }        
    else { # Client
        $RemoteEndPoint = New-Object Net.IPEndPoint -ArgumentList @($ServerIp, $Port) 
        $UdpClient = New-Object Net.Sockets.UDPClient
        $UdpClient.Connect($RemoteEndPoint)

        Write-Verbose "Sending UDP to $($RemoteEndPoint.ToString()). Make sure to send some data to the server!"

        $Properties = @{
            UdpClient = $UdpClient
            Socket = $UdpClient.Client
            Read = $UdpClient.BeginReceive($null, $null)
        }
        $UdpStream = New-Object -TypeName psobject -Property $Properties
    }
    return $InitialBytes, $UdpStream
}