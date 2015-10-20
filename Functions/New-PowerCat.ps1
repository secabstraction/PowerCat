function New-PowerCat {
[CmdletBinding()]
    Param (
        [Parameter(ParameterSetName = 'Client', Position = 0, Mandatory = $true)]
        [ValidatePattern("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")]
        [Alias("c")]
        [String]$Client,

        [Parameter(ParameterSetName = 'Listener', Position = 0, Mandatory = $true)]
        [Alias("l")]
        [Switch]$Listener,

        [Parameter()]
        [Alias("m")]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode = 'Tcp',

        [Parameter()]
        [Alias("e")]
        [String]$Execute="",
        
        [Parameter()]
        [Alias("p")]
        [Switch]$PowerShell,
    
        [Parameter()]
        [Alias("i")]
        [Object]$Input,
        
        [Parameter()]
        [Alias("if")]
        [Object]$InputFile,
    
        [Parameter()]
        [Alias("r")]
        [String]$RelayTo = "",
    
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
        [Switch]$Repeater
    )
    DynamicParam {
        $ParameterDictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        
        if ($Mode -eq 'Smb') {
            $PipeNameParam = New-RuntimeParameter -Name PipeName -Type String -Mandatory -ParameterDictionary $ParameterDictionary
        }

        elseif (($Mode -eq 'Tcp') -or ($Mode -eq 'Udp')) {
            $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary
        }
        return $ParameterDictionary
    }
    Begin {    
        $Encoding = New-Object System.Text.AsciiEncoding
      
        if ($PSBoundParameters.InputFile) {
            if (Test-Path $InputFile) { [byte[]]$InputToWrite = [IO.File]::ReadAllBytes($InputFile) }
            else { Write-Warning "$InputFile does not exist." ; return }
        }
        
        elseif ($PSBoundParameters.Input) {        
            if ($Input.GetType().Name -eq 'Byte[]') { [byte[]]$InputToWrite = $Input }
            elseif ($Input.GetType().Name -eq 'String') { [byte[]]$InputToWrite = $Encoding.GetBytes($Input) }
            else { Write-Warning 'Incompatible input type.' ; return }
        }
    }
    Process {     
        Write-Verbose "Setting up network stream..."
        
        try { $NetworkStream = Open-NetworkStream $Stream1SetupVars }
        catch { Write-Warning "Failed to open network stream. $($_.Exception.Message)" ; break }
      
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