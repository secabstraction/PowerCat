function New-TcpStream {
[CmdletBinding(DefaultParameterSetName = 'Client')]
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client')]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener')]
        [Switch]$Listener,
        
        [Parameter(Position = 1)]
        [Int]$Port, 
        
        [Parameter()]
        [Int]$Timeout = 60
    )
    
    if ($Listener.IsPresent) {

        $TcpListener = New-Object Net.Sockets.TcpListener $Port
        $TcpListener.Start()
        $ConnectResult = $TcpListener.BeginAcceptTcpClient($null, $null)

        Write-Verbose "Listening on 0.0.0.0:$Port [tcp]"
        
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Warning 'Caught escape sequence, stopping TCP setup.'
                    [console]::TreatControlCAsInput = $false
                    $TcpListener.Stop()
                    $Stopwatch.Stop()
                    return
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP setup.'
                [console]::TreatControlCAsInput = $false
                $TcpListener.Stop()
                $Stopwatch.Stop()
                return
            }
        } until ($ConnectResult.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop() 

        $TcpClient = $TcpListener.EndAcceptTcpClient($ConnectResult)
        $TcpListener.Stop()
        
        if (!$TcpClient) { Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed." ; return }

        Write-Verbose "Connection from $($TcpClient.Client.RemoteEndPoint.ToString()) accepted."

        $TcpStream = $TcpClient.GetStream()
        $Buffer = New-Object Byte[] $TcpClient.ReceiveBufferSize
        
        $Properties = @{
            Socket = $TcpClient.Client
            TcpStream = $TcpStream
            Buffer = $Buffer
            Read = $TcpStream.BeginRead($Buffer, 0, $Buffer.Length, $null, $null)
        }
        New-Object psobject -Property $Properties
    }        
    else { # Client

        $TcpClient = New-Object Net.Sockets.TcpClient
        
        $ConnectResult = $TcpClient.BeginConnect($ServerIp, $Port, $null, $null)
        
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true

        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Warning 'Caught escape sequence, stopping TCP setup.'
                    [console]::TreatControlCAsInput = $false
                    if ($PSVersionTable.CLRVersion.Major -lt 4) { $TcpClient.Close() }
                    else { $TcpClient.Dispose() }
                    $Stopwatch.Stop()
                    return
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP setup.'
                [console]::TreatControlCAsInput = $false
                if ($PSVersionTable.CLRVersion.Major -lt 4) { $TcpClient.Close() }
                else { $TcpClient.Dispose() }
                $Stopwatch.Stop()
                return
            }
        } until ($ConnectResult.IsCompleted)

        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        try { $TcpClient.EndConnect($ConnectResult) }
        catch {
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed. $($_.Exception.Message)"
            if ($PSVersionTable.CLRVersion.Major -lt 4) { $TcpClient.Close() }
            else { $TcpClient.Dispose() }
            return
        }
        Write-Verbose "Connection to $($ServerIp.IPAddressToString):$Port [tcp] succeeded!"
        
        $TcpStream = $TcpClient.GetStream()
        $Buffer = New-Object Byte[] $TcpClient.ReceiveBufferSize
        
        $Properties = @{
            Socket = $TcpClient.Client
            TcpStream = $TcpStream
            Buffer = $Buffer
            Read = $TcpStream.BeginRead($Buffer, 0, $Buffer.Length, $null, $null)
        }        
        New-Object psobject -Property $Properties
    }
}