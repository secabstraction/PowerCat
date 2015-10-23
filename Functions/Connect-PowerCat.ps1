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
        
        [Parameter(ParameterSetName = 'ScriptBlock')]
        [Alias("sb")]
        [ScriptBlock]$ScriptBlock,
    
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
        [ValidateSet('Host','Bytes','String')]
        [String]$OutputType = 'Host',

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

        if ($PSBoundParameters.ScriptBlock) { $ArgumentListParam = New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary }

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
      
        if ($PSCmdlet.ParameterSetName = 'Input') {   
            
            Write-Verbose 'Parsing input...'

            if ((Test-Path $Input)) { $InputToWrite = [IO.File]::ReadAllBytes($Input) }     
            elseif ($Input.GetType().Name -eq 'Byte[]') { $InputToWrite = $Input }
            elseif ($Input.GetType().Name -eq 'String') { $InputToWrite = $EncodingType.GetBytes($Input) }
            else { Write-Warning 'Incompatible input type.' ; return }
        }

        elseif ($PSCmdlet.ParameterSetName = 'Relay') {
            
            Write-Verbose "Setting up relay stream..."

            $RelayConfig = $Relay.Split(':')

            if ($RelayConfig.Count -eq 2) { # Listener
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
                       'icmp' { $RelayStream = New-IcmpStream -BindAddress $RelayConfig[1] ; continue }
                        'smb' { $RelayStream = New-SmbStream -PipeName $RelayConfig[1] ; continue }
                        'tcp' { $RelayStream = New-TcpStream -Port $RelayConfig[1] ; continue }
                        'udp' { $RelayStream = New-UdpStream -Port $RelayConfig[1] ; continue }
                }
            }
            elseif ($RelayConfig.Count -eq 3) { # Client
                
                $RelayMode = $RelayConfig[0].ToLower()

                switch ($RelayMode) {
                       'icmp' { $RelayStream = New-IcmpStream -RemoteIp $RelayConfig[2] -BindAddress $RelayConfig[1] ; continue }
                        'smb' { $RelayStream = New-SmbStream -RemoteIp $RelayConfig[2] -PipeName $RelayConfig[1] ; continue }
                        'tcp' { $RelayStream = New-TcpStream -RemoteIp $RelayConfig[2] -Port $RelayConfig[1] ; continue }
                        'udp' { $RelayStream = New-UdpStream -RemoteIp $RelayConfig[2] -Port $RelayConfig[1] ; continue }
                }
            }
            else { Write-Error 'Invalid relay format.' -ErrorAction Stop }
        }
          
        Write-Verbose "Setting up network stream..."

        switch ($Mode) {
           'Icmp' { 
                try { $NetworkStream = New-IcmpStream -RemoteIp $RemoteIp -BindAddress $ParameterDictionary.BindAddress.Value }
                catch { Write-Warning "Failed to open network stream. $($_.Exception.Message)" ; break }
                continue 
            }
            'Smb' { 
                try { $NetworkStream = New-SmbStream -RemoteIp $RemoteIp -PipeName $ParameterDictionary.PipeName.Value  }
                catch { Write-Warning "Failed to open network stream. $($_.Exception.Message)" ; break }
                continue 
            }
            'Tcp' { 
                try { $NetworkStream = New-TcpStream -RemoteIp $RemoteIp -Port $Port  }
                catch { Write-Warning "Failed to open network stream. $($_.Exception.Message)" ; break }
                continue 
            }
            'Udp' { 
                try { $NetworkStream = New-UdpStream -RemoteIp $RemoteIp -Port $Port  }
                catch { Write-Warning "Failed to open network stream. $($_.Exception.Message)" ; break }
                continue 
            }
        }
    }
    Process {   
      
        Write-Verbose "Setting up IO stream..."
        
        try { $IOStream = Open-IOStream $Stream2SetupVars }
        catch { Write-Warning "Failed to open IO stream. $($_.Exception.Message)" ; break }
      
        $Data = $null
      
        if ($InputToWrite) {
            Write-Verbose "Writing input to network stream..."

            try { $NetworkStream = Write-NetworkStream -Stream $NetworkStream -Data $InputToWrite }
            catch { Write-Warning "Failed to write input to network stream. $($_.Exception.Message)" ; break }
        }
      
        if ($Disconnect.IsPresent) { Write-Verbose "-d (disconnect) Activated. Disconnecting..." ; break }
      
        Write-Verbose "Both Communication Streams Established. Redirecting Data Between Streams..."
      
        while ($true) {
            try {
                $Data, $IOStream = Read-IOStream -Stream $IOStream
                if ($Data) { $NetworkStream = Write-NetworkStream -Stream $NetworkStream -Data $Data }
                $Data = $null
            }
            catch { Write-Warning "Failed to redirect data from IO stream to network stream. $($_.Exception.Message)" ; break }
        
            try {
                $Data, $NetworkStream = Read-NetworkStream -Stream $NetworkStream
                if ($Data) { $IOStream = Write-IOStream -Stream $IOStream -Data $Data }
                $Data = $null
            }
            catch { Write-Warning "Failed to redirect data from network stream to IO stream. $($_.Exception.Message)" ; break }
        }
    }
    End {      
        try { Close-IOStream -Stream $IOStream }
        catch { Write-Warning "Failed to close IO stream. $($_.Exception.Message)" }
      
        try { Close-NetworkStream -Stream $NetworkStream }
        catch { Write-Warning "Failed to close network stream. $($_.Exception.Message)" }
    }
}