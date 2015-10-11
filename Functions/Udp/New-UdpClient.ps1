function New-UdpClient {
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Mandatory = $true)]
        [Int]$Port, 
        
        [Parameter()]
        [Int]$Timeout
    )    
        
    $Encoding = New-Object Text.AsciiEncoding

    if ($Listener.IsPresent) {

        $SocketDestinationBuffer = New-Object Byte[] -ArgumentList 65536
        $IPEndPoint = New-Object Net.IPEndPoint -ArgumentList @([Net.IPAddress]::Any, $null)
        $UdpClient = New-Object Net.Sockets.UDPClient -ArgumentList $Port
        $PacketInfo = New-Object Net.Sockets.IPPacketInformation

        Write-Verbose "Listening on 0.0.0.0:$Port [udp]"
                
        $ConnectHandle = $UdpClient.Client.BeginReceiveMessageFrom($SocketDestinationBuffer, 0, 65536, [Net.Sockets.SocketFlags]::None, [ref]$IPEndPoint, $null, $null)
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        
        [console]::TreatControlCAsInput = $true
      
        while ($true) {

            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning "Caught escape sequence, stopping UDP Setup."
                    $UdpClient.Close()
                    $Stopwatch.Stop()
                    $SocketDestinationBuffer = $null
                    [console]::TreatControlCAsInput = $false
                    break
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping UDP Setup."
                $UdpClient.Close()
                $Stopwatch.Stop()
                $SocketDestinationBuffer = $null
                [console]::TreatControlCAsInput = $false
                break
            }

            if ($ConnectHandle.IsCompleted) {
                $SocketFlags = 0
                $SocketBytesRead = $UdpClient.Client.EndReceiveMessageFrom($ConnectHandle, [ref]$SocketFlags, [ref]$IPEndPoint, [ref]$PacketInfo)
                
                if ($SocketBytesRead.Count -gt 0) { $InitialConnectionBytes = $SocketDestinationBuffer[0..($SocketBytesRead - 1)] }

                Write-Verbose "Connection from $($IPEndPoint.Address.IPAddressToString):$($IPEndPoint.Port) [udp] accepted."
                [console]::TreatControlCAsInput = $false
                break
            }
        }
        $Stopwatch.Stop()

        $Properties = @{
            Encoding = $Encoding
            UdpClient = $UdpClient
            IPEndPoint = $IPEndPoint
            InitialConnectionBytes = $InitialConnectionBytes
        }
    }        
    else { 
        $IPEndPoint = New-Object Net.IPEndPoint -ArgumentList @($ServerIp, $Port) 
        $UdpClient = New-Object Net.Sockets.UDPClient
        $UdpClient.Connect($IPEndPoint)

        Write-Verbose "Sending UDP traffic to $($ServerIp.IPAddressToString) port $Port..."
        Write-Verbose "Make sure to send some data so the server!"

        $Properties = @{
            Encoding = $Encoding
            UdpClient = $UdpClient
            IPEndPoint = $IPEndPoint
        }
    }
    
    $BufferSize = 65536
    $StreamDestinationBuffer = New-Object byte[] -ArgumentList $BufferSize
    $StreamReadOperation = $UdpClient.Client.BeginReceiveFrom($StreamDestinationBuffer, 0, $BufferSize, [Net.Sockets.SocketFlags]::None, [ref]$IPEndPoint, $null, $null)
    
    [void]$Properties.Add('BufferSize', $BufferSize)
    [void]$Properties.Add('StreamDestinationBuffer', $StreamDestinationBuffer)
    [void]$Properties.Add('StreamReadOperation', $StreamReadOperation)

    New-Object -TypeName psobject -Property $Properties
}
