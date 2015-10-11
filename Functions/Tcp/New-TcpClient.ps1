function New-TcpClient {
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
    
    $Stopwatch = [Diagnostics.Stopwatch]::StartNew()

    if ($Listener.IsPresent) {

        $TcpListener = New-Object Net.Sockets.TcpListener -ArgumentList $Port
        $TcpListener.Start()
        $ConnectHandle = $TcpListener.BeginAcceptTcpClient($null, $null)

        Write-Verbose "Listening on 0.0.0.0:$Port [tcp]"
        
        [console]::TreatControlCAsInput = $true
      
        while ($true) {

            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning "Caught escape sequence, stopping TCP listener setup."
                    $TcpListener.Stop()
                    $Stopwatch.Stop()
                    [console]::TreatControlCAsInput = $false
                    break
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping TCP listener setup."
                $TcpListener.Stop()
                $Stopwatch.Stop()
                [console]::TreatControlCAsInput = $false
                break
            }

            if ($ConnectHandle.IsCompleted) {
                $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectHandle)
                $NetworkStream = $TcpClient.GetStream()
                $BufferSize = $TcpClient.ReceiveBufferSize
                Write-Verbose -Message "Connection from $($TcpClient.Client.RemoteEndPoint.Address.IPAddressToString):$($Client.Client.RemoteEndPoint.Port)"  
                [console]::TreatControlCAsInput = $false
                $Stopwatch.Stop() 
                break
            }
        }

        if ($TcpClient -eq $null) { break }

        $StreamDestinationBuffer = New-Object Byte[] -ArgumentList $BufferSize
        $StreamReadOperation = $NetworkStream.BeginRead($StreamDestinationBuffer, 0, $BufferSize, $null, $null)
        
        $Properties = @{
            Encoding = $Encoding
            NetworkStream = $NetworkStream
            TcpListener = $TcpListener
            BufferSize = $BufferSize
            StreamReadOperation = $StreamReadOperation
            StreamDestinationBufer = $StreamDestinationBuffer
            StreamBytesRead = 1
        }

        New-Object -TypeName psobject -Property $Properties
    }        
    else { 

        $TcpClient = New-Object Net.Sockets.TcpClient
        Write-Verbose "Attempting connection to $($ServerIp.IPAddressToString):$Port..."
        $ConnectHandle = $TcpClient.BeginConnect($ServerIp, $Port, $null, $null)

        [console]::TreatControlCAsInput = $true

        while ($true) {

            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning 'Caught escape sequence, stopping TCP Setup.'
                    $TcpClient.Close()
                    $Stopwatch.Stop()
                    [console]::TreatControlCAsInput = $false
                    break
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP Setup.'
                $TcpClient.Close()
                $Stopwatch.Stop()
                [console]::TreatControlCAsInput = $false
                break
            }

            if ($ConnectHandle.IsCompleted) {
                try {
                    $TcpClient.EndConnect($ConnectHandle)
                    $NetworkStream = $TcpClient.GetStream()
                    $BufferSize = $TcpClient.ReceiveBufferSize
                    Write-Verbose "Connection to $($ServerIp.IPAddressToString):$Port [tcp] succeeded!"
                    [console]::TreatControlCAsInput
                    $Stopwatch.Stop()
                }
                catch {
                    Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed."
                    [console]::TreatControlCAsInput
                    $TcpClient.Close()
                    $Stopwatch.Stop()
                    break
                }
            }
        }

        if (!$TcpClient.Connected) { break }

        $StreamDestinationBuffer = New-Object Byte[] -ArgumentList $BufferSize
        $StreamReadOperation = $NetworkStream.BeginRead($StreamDestinationBuffer, 0, $BufferSize, $null, $null)
        
        $Properties = @{
            Encoding = $Encoding
            NetworkStream = $NetworkStream
            TcpClient = $TcpClient
            BufferSize = $BufferSize
            StreamReadOperation = $StreamReadOperation
            StreamDestinationBufer = $StreamDestinationBuffer
            StreamBytesRead = 1
        }

        New-Object -TypeName psobject -Property $Properties
    }
}
