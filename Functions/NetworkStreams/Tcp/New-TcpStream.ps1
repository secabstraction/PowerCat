function New-TcpStream {
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Mandatory = $true)]
        [Int]$Port, 
        
        [Parameter()]
        [Int]$Timeout = 1,

        [Parameter()]
        [ValidateSet('Ascii','Unicode','UTF7','UTF8','UTF32')]
        [String]$Encoding = 'Ascii'
    )    
    
    switch ($Encoding) {
          'Ascii' { $EncodingType = New-Object Text.AsciiEncoding }
        'Unicode' { $EncodingType = New-Object Text.UnicodeEncoding }
           'UTF7' { $EncodingType = New-Object Text.UTF7Encoding }
           'UTF8' { $EncodingType = New-Object Text.UTF8Encoding }
          'UTF32' { $EncodingType = New-Object Text.UTF32Encoding }
    }
    
    $Stopwatch = [Diagnostics.Stopwatch]::StartNew()

    if ($Listener.IsPresent) {

        $TcpListener = New-Object Net.Sockets.TcpListener -ArgumentList $Port
        $TcpListener.Start()
        $ConnectHandle = $TcpListener.BeginAcceptTcpClient($null, $null)

        Write-Verbose "Listening on 0.0.0.0:$Port [tcp]"
        
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning "Caught escape sequence, stopping TCP setup."
                    $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectHandle)
                    $TcpClient.Dispose()
                    $TcpListener.Stop()
                    $Stopwatch.Stop()
                    [console]::TreatControlCAsInput = $false
                    return
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping TCP setup."
                $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectHandle)
                $TcpClient.Dispose()
                $TcpListener.Stop()
                $Stopwatch.Stop()
                [console]::TreatControlCAsInput = $false
                return
            }
        } until ($ConnectHandle.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop() 

        $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectHandle)
        
        if ($TcpClient -eq $null) { 
            $TcpListener.Stop()
            return 
        }

        $NetworkStream = $TcpClient.GetStream()

        Write-Verbose "Connection from $($TcpClient.Client.RemoteEndPoint.Address.IPAddressToString):$($Client.Client.RemoteEndPoint.Port)"
        
        $Properties = @{
            Encoding = $EncodingType
            TcpStream = $NetworkStream
            TcpListener = $TcpListener
            BufferSize = $TcpClient.ReceiveBufferSize
        }

        New-Object -TypeName psobject -Property $Properties
    }        
    else { 

        $TcpClient = New-Object Net.Sockets.TcpClient
        Write-Verbose "Attempting connection to $($ServerIp.IPAddressToString):$Port"
        $ConnectHandle = $TcpClient.BeginConnect($ServerIp, $Port, $null, $null)

        [console]::TreatControlCAsInput = $true

        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning 'Caught escape sequence, stopping TCP setup.'
                    $TcpClient.EndConnect($ConnectHandle)
                    $TcpClient.Dispose()
                    $Stopwatch.Stop()
                    [console]::TreatControlCAsInput = $false
                    return
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP setup.'
                $TcpClient.EndConnect($ConnectHandle)
                $TcpClient.Dispose()
                $Stopwatch.Stop()
                [console]::TreatControlCAsInput = $false
                return
            }
        } until ($ConnectHandle.IsCompleted)

        [console]::TreatControlCAsInput
        $Stopwatch.Stop()

        try {
            $TcpClient.EndConnect($ConnectHandle)
            $NetworkStream = $TcpClient.GetStream()
            Write-Verbose "Connection to $($ServerIp.IPAddressToString):$Port [tcp] succeeded!"
        }
        catch {
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed."
            $TcpClient.Dispose()
        }

        if (!$TcpClient.Connected) { 
            $TcpClient.Dispose()
            return 
        }
        
        $Properties = @{
            Encoding = $EncodingType
            TcpStream = $NetworkStream
            TcpClient = $TcpClient
            BufferSize = $TcpClient.ReceiveBufferSize
        }

        New-Object -TypeName psobject -Property $Properties
    }
}