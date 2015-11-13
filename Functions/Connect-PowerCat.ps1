function Connect-PowerCat {
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
[CmdletBinding(DefaultParameterSetName = 'Console')]
    Param (
        [Parameter(Position = 0)]
        [Alias('m')]
        [ValidateSet('Smb', 'Tcp', 'Udp')]
        [String]$Mode = 'Tcp',

        [Parameter(Position = 1, Mandatory = $true)]
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
    
        [Parameter(ParameterSetName = 'Input')]
        [Alias('i')]
        [String]$Input,
    
        [Parameter()]
        [Alias('d')]
        [Switch]$Disconnect,
    
        [Parameter()]
        [Alias('t')]
        [Int]$Timeout = 60,
        
        [Parameter()]
        [ValidateSet('Ascii','Unicode','UTF7','UTF8','UTF32')]
        [String]$Encoding = 'Ascii'
    ) 
    DynamicParam { 
        $ParameterDictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary

        if ($Mode -eq 'Smb') { New-RuntimeParameter -Name PipeName -Type String -Mandatory -Position 2 -ParameterDictionary $ParameterDictionary }
        else { New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 2 -ParameterDictionary $ParameterDictionary }

        if ($Mode -eq 'Tcp') { New-RuntimeParameter -Name SslCn -Type String -ParameterDictionary $ParameterDictionary }
        
        if ($Execute.IsPresent) { 
            New-RuntimeParameter -Name ScriptBlock -Type ScriptBlock -ParameterDictionary $ParameterDictionary 
            New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary 
        }
        return $ParameterDictionary
    }
    Begin {     
        if ($RemoteIp -notmatch "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$") { 
            Write-Warning "$RemoteIp is not a valid IPv4 address."
            return 
        }
        $ServerIp = [Net.IPAddress]::Parse($RemoteIp)

        switch ($Mode) {
            'Smb' { 
                try { $ClientStream = New-SmbStream $RemoteIp $ParameterDictionary.PipeName.Value $Timeout }
                catch { Write-Warning "Failed to open Smb stream. $($_.Exception.Message)" ; return }
                continue 
            }
            'Tcp' { 
                try { $ClientStream = New-TcpStream $ServerIp $ParameterDictionary.Port.Value $ParameterDictionary.SslCn.Value $Timeout }
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
        
        if ($PSCmdlet.ParameterSetName -eq 'Input') { Write-NetworkStream $Mode $ClientStream $EncodingType.GetBytes($Input) }     
        elseif ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $FileStream = New-Object IO.FileStream @($ReceiveFile, [IO.FileMode]::Append) } 
        elseif ($PSCmdlet.ParameterSetName -eq 'SendFile') {   
            
            Write-Verbose "Attempting to send $SendFile"

            if ((Test-Path $SendFile)) { 
            
                try { $FileStream = New-Object IO.FileStream @($SendFile, [IO.FileMode]::Open) }
                catch { Write-Warning $_.Exception.Message }

                if ($BytesLeft = $FileStream.Length) { # goto cleanup
                    
                    $FileOffset = 0
                    if ($BytesLeft -gt 4608) { # Max packet size for Ncat

                        $BytesToSend = New-Object Byte[] 4608

                        while ($BytesLeft -gt 4608) {

                            [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                            [void]$FileStream.Read($BytesToSend, 0, 4608)
                            
                            $FileOffset += 4608
                            $BytesLeft -= 4608

                            Write-NetworkStream $Mode $ClientStream $BytesToSend
                        } 
                        # Send last packet
                        $BytesToSend = New-Object Byte[] $BytesLeft
                        [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                        [void]$FileStream.Read($BytesToSend, 0, $BytesLeft)

                        Write-NetworkStream $Mode $ClientStream $BytesToSend
                    }
                    else { # Only need to send one packet
                        $BytesToSend = New-Object Byte[] $BytesLeft
                        [void]$FileStream.Seek($FileOffset, [IO.SeekOrigin]::Begin)
                        [void]$FileStream.Read($BytesToSend, 0, $BytesLeft)

                        Write-NetworkStream $Mode $ClientStream $BytesToSend
                    }
                    $FileStream.Flush()
                    $FileStream.Dispose()
                }
                if ($Mode -eq 'Smb') { $ClientStream.Pipe.WaitForPipeDrain() } 
                if ($Mode -eq 'Tcp') { sleep 1 }
            }
            else { Write-Warning "$SendFile does not exist." }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') {
            
            Write-Verbose "Setting up relay stream..."

            $RelayConfig = $Relay.Split(':')
            $RelayMode = $RelayConfig[0].ToLower()

            if ($RelayConfig.Count -eq 2) { # Listener
                switch ($RelayMode) {
                    'smb' { $RelayStream = New-SmbStream -Listener $RelayConfig[1] ; continue }
                    'tcp' { $RelayStream = New-TcpStream -Listener $RelayConfig[1] ; continue }
                    'udp' { $RelayStream = New-UdpStream -Listener $RelayConfig[1] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; return }
                }
            }
            elseif ($RelayConfig.Count -eq 3) { # Client                
                if ($RelayConfig[1] -match "^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$") {
                    $ServerIp = [Net.IPAddress]::Parse($RelayConfig[1])
                    switch ($RelayMode) {
                        'smb' { $RelayStream = New-SmbStream $RelayConfig[1] $RelayConfig[2] ; continue }
                        'tcp' { $RelayStream = New-TcpStream $ServerIp $RelayConfig[2] ; continue }
                        'udp' { $RelayStream = New-UdpStream $ServerIp $RelayConfig[2] ; continue }
                        default { Write-Warning 'Invalid relay mode specified.' ; return }
                    }
                }
                else { Write-Warning "$($RelayConfig[1]) is not a valid IPv4 address." }
            }
            else { Write-Warning 'Invalid relay format.' }
        }          
        elseif ($PSCmdlet.ParameterSetName -eq 'Execute') {
            if ($ClientStream) {    
                $BytesToSend = $EncodingType.GetBytes("`nPowerCat by @secabstraction`n")
            
                if ($ParameterDictionary.ScriptBlock.Value) {

                    $ScriptBlock = $ParameterDictionary.ScriptBlock.Value
            
                    $Global:Error.Clear()
            
                    $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke($ParameterDictionary.ArgumentList.Value) | Out-String))
                    if ($Global:Error.Count) { foreach ($Err in $Global:Error) { $BytesToSend += $EncodingType.GetBytes($Err.Exception.Message) } }
                }
                $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
                Write-NetworkStream $Mode $ClientStream $BytesToSend
                $ScriptBlock = $null
                $BytesToSend = $null
            }
        }
    }
    Process {             
        [console]::TreatControlCAsInput = $true

        while ($true) {
        
            if ($PSCmdlet.ParameterSetName -eq 'SendFile' -or $Disconnect.IsPresent) { break } # Skip to Cleanup
            
            # Catch Esc / Read-Host
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey()
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Verbose 'Caught escape sequence, stopping PowerCat.'
                    break
                }
                if ($PSCmdlet.ParameterSetName -eq 'Console') { 
                    $BytesToSend = $EncodingType.GetBytes($Key.KeyChar + (Read-Host) + "`n") 
                    Write-NetworkStream $Mode $ClientStream $BytesToSend
                }
            }

            # Get data from the network
            if ($InitialBytes) { $ReceivedBytes = $InitialBytes ; $InitialBytes = $null }
            elseif ($ClientStream.Socket.Connected -or $ClientStream.Pipe.IsConnected) { 
                if ($ClientStream.Read.IsCompleted) { $ReceivedBytes = Read-NetworkStream $Mode $ClientStream } 
                else { Start-Sleep -Milliseconds 1 ; continue }
            }
            else { Write-Verbose "$Mode connection broken, exiting." ; break }

            # Redirect received bytes
            if ($PSCmdlet.ParameterSetName -eq 'Execute') {
            
                try { $ScriptBlock = [ScriptBlock]::Create($EncodingType.GetString($ReceivedBytes)) }
                catch { break } # network stream closed
            
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
                catch { break } # EOF reached
                continue
            }
            else { # Console
                try { Write-Host -NoNewline $EncodingType.GetString($ReceivedBytes).TrimEnd("`r") }
                catch { break } # network stream closed
            }
        }
    }
    End { # Cleanup
        Write-Host "`n"

        if ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $FileStream.Flush() ; $FileStream.Dispose() }
      
        try { Close-NetworkStream $Mode $ClientStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream $RelayMode $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
        [console]::TreatControlCAsInput = $false
    }
}