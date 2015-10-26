function New-TcpStream {
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Mandatory = $true)]
        [Int]$Port, 
        
        [Parameter()]
        [Int]$Timeout = 60
    )
    
    if ($Listener.IsPresent) {

        $TcpListener = New-Object Net.Sockets.TcpListener -ArgumentList $Port
        $TcpListener.Start()
        $ConnectResult = $TcpListener.BeginAcceptTcpClient($null, $null)

        Write-Verbose "Listening on 0.0.0.0:$Port [tcp]"
        
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning 'Caught escape sequence, stopping TCP setup.'
                    [console]::TreatControlCAsInput = $false
                    $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectResult)
                    $TcpClient.Dispose()
                    $TcpListener.Stop()
                    $Stopwatch.Stop()
                    exit
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP setup.'
                [console]::TreatControlCAsInput = $false
                $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectResult)
                $TcpClient.Dispose()
                $TcpListener.Stop()
                $Stopwatch.Stop()
                exit
            }
        } until ($ConnectResult.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop() 

        $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectResult)
        
        if ($TcpClient -eq $null) { 
            $TcpListener.Stop()
            return 
        }

        Write-Verbose "Connection from $($TcpClient.Client.RemoteEndPoint.ToString())."
        
        $Properties = @{
            Socket = $TcpClient.Client
            TcpStream = $TcpClient.GetStream()
            BufferSize = $TcpClient.ReceiveBufferSize
        }

        New-Object -TypeName psobject -Property $Properties
    }        
    else { # Client

        $TcpClient = New-Object Net.Sockets.TcpClient

        Write-Verbose "Attempting connection to $($ServerIp.IPAddressToString):$Port"
        
        $ConnectResult = $TcpClient.BeginConnect($ServerIp, $Port, $null, $null)
        
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true

        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning 'Caught escape sequence, stopping TCP setup.'
                    [console]::TreatControlCAsInput = $false
                    $TcpClient.EndConnect($ConnectResult)
                    $TcpClient.Dispose()
                    $Stopwatch.Stop()
                    exit
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP setup.'
                [console]::TreatControlCAsInput = $false
                $TcpClient.EndConnect($ConnectResult)
                $TcpClient.Dispose()
                $Stopwatch.Stop()
                exit
            }
        } until ($ConnectResult.IsCompleted)

        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        try { $TcpClient.EndConnect($ConnectResult) }
        catch {
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed. $($_.Exception.Message)"
            $TcpClient.Dispose()
            exit
        }

        if (!$TcpClient.Connected) { 
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed. $($_.Exception.Message)"
            $TcpClient.Dispose()
            exit 
        }

        Write-Verbose "Connection to $($ServerIp.IPAddressToString):$Port [tcp] succeeded!"
        
        $Properties = @{
            Socket = $TcpClient.Client
            TcpStream = $TcpClient.GetStream()
            BufferSize = $TcpClient.ReceiveBufferSize
        }

        New-Object -TypeName psobject -Property $Properties
    }
}