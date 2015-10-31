function Start-PowerCat {
[CmdletBinding(DefaultParameterSetName = 'Console')]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias('m')]
        [ValidateSet('Smb', 'Tcp', 'Udp')]
        [String]$Mode,
        
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

        switch ($Mode) {
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
          
        switch ($Encoding) {
            'Ascii' { $EncodingType = New-Object Text.AsciiEncoding ; continue }
          'Unicode' { $EncodingType = New-Object Text.UnicodeEncoding ; continue }
             'UTF7' { $EncodingType = New-Object Text.UTF7Encoding ; continue }
             'UTF8' { $EncodingType = New-Object Text.UTF8Encoding ; continue }
            'UTF32' { $EncodingType = New-Object Text.UTF32Encoding ; continue }
        }

        if ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $FileStream = New-Object IO.FileStream -ArgumentList @($ReceiveFile, [IO.FileMode]::Append) }
      
        if ($PSCmdlet.ParameterSetName -eq 'SendFile') {   
            
            Write-Verbose 'Reading file bytes...'

            if ((Test-Path $SendFile)) { 
                if ($Mode -eq 'Udp') { Write-Warning 'Cannot send files from Udp listener.' }
                if ($Mode -eq 'Smb') { 
                    try { $FileStream = New-Object IO.FileStream -ArgumentList @($SendFile, [IO.FileMode]::Open) }
                    catch { Write-Warning $_.Exception.Message }

                    if ($BytesLeft = $FileStream.Length) {
                    
                        $FileOffset = 0
                        if ($BytesLeft -gt 65536) {

                            $BytesToSend = New-Object Byte[] 65536

                            while ($BytesLeft -gt 65536) {

                                [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                                [void]$FileStream.Read($BytesToSend, 0, 65536)
                            
                                $FileOffset += 65536
                                $BytesLeft -= 65536

                                Write-NetworkStream $Mode $ServerStream $BytesToSend
                            } 

                            $BytesToSend = New-Object Byte[] $BytesLeft
                            [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                            [void]$FileStream.Read($BytesToSend, 0, $BytesLeft)

                            Write-NetworkStream $Mode $ServerStream $BytesToSend
                        }
                        else {
                            $BytesToSend = New-Object Byte[] $BytesLeft
                            [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                            [void]$FileStream.Read($BytesToSend, 0, $BytesLeft)

                            Write-NetworkStream $Mode $ServerStream $BytesToSend
                        }
                        $FileStream.Flush()
                        $FileStream.Dispose()
                    }
                    $ServerStream.Pipe.WaitForPipeDrain()
                }
                else { $ServerStream.Socket.SendFile($SendFile) ; sleep 1 }
            }
            else { Write-Warning "$SendFile does not exist." }
        }

        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') {
            
            Write-Verbose "Setting up relay stream..."

            $RelayConfig = $Relay.Split(':')

            if ($RelayConfig.Count -eq 2) { # Listener
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
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
                    'smb' { $RelayStream = New-SmbStream $RelayConfig[1] $RelayConfig[2] ; continue }
                    'tcp' { $RelayStream = New-TcpStream $ServerIp $RelayConfig[2] ; continue }
                    'udp' { $RelayStream = New-UdpStream $ServerIp $RelayConfig[2] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; return }
                }
            }
            else { Write-Warning 'Invalid relay format.' ; return }
        }
          
        elseif ($ParameterDictionary.ScriptBlock.Value) {
            
            Write-Verbose 'Executing scriptblock...'

            $ScriptBlock = $ParameterDictionary.ScriptBlock.Value
            
            $Global:Error.Clear()
            
            $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke($ParameterDictionary.ArgumentList.Value) | Out-String))
            if ($Global:Error.Count) { foreach ($Err in $Global:Error) { $BytesToSend += $EncodingType.GetBytes($Err.Exception.Message) } }
            $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
            Write-NetworkStream $Mode $ServerStream $BytesToSend
            $ScriptBlock = $null
            $BytesToSend = $null
        }
    }
    Process {    
        [console]::TreatControlCAsInput = $true

        while ($true) {

            if ($PSCmdlet.ParameterSetName -eq 'SendFile') { break } # Skip to Cleanup
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
                    Write-NetworkStream $Mode $ServerStream $BytesToSend
                }
            }

            # Get data from the network
            if ($InitialBytes) { $ReceivedBytes = $InitialBytes ; $InitialBytes = $null }
            elseif ($ServerStream.Socket.Connected) { 
                if ($ServerStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ServerStream $ServerStream.Socket.Available } 
                else { Start-Sleep -Milliseconds 1 ; continue }
            }
            elseif ($ServerStream.Pipe.IsConnected) { 
                if ($ServerStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ServerStream } 
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
                
                Write-NetworkStream $Mode $ServerStream $BytesToSend 
                $BytesToSend = $null
                $ScriptBlock = $null
                continue
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Relay') { Write-NetworkStream $RelayMode $RelayStream $ReceivedBytes ; continue }
            elseif ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { 
                try { $FileStream.Write($ReceivedBytes, 0, $ReceivedBytes.Length) }
                catch { Write-Verbose $_.Exception.Message ; break } # EOF reached
                continue
            }
            else { Write-Host -NoNewline $EncodingType.GetString($ReceivedBytes).TrimEnd("`r") }
        }
    }
    End {   
        [console]::TreatControlCAsInput = $false
        Write-Verbose 'Attempting to close network stream.'

        if ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $FileStream.Flush() ; $FileStream.Dispose() }
      
        try { Close-NetworkStream $Mode $ServerStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream $RelayMode $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
    }
}