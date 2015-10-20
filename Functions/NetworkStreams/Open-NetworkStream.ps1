function Open-NetworkStream {
param()
DynamicParam 
    {
        $ParameterDictionary = New-Object Management.Automation.RuntimeDefinedParameterDictionary
        
        if ($Mode -eq 'Smb') {
            $PipeNameParam = New-RuntimeParameter -Name PipeName -Type String -Mandatory
            $ParameterDictionary.Add('PipeName',$PipeNameParam)
        }

        if (($Mode -eq 'Tcp') -or ($Mode -eq 'Udp')) {
            $PortParam = New-RuntimeParameter -Name Port -Type Int -Mandatory -Position 2
            $ParameterDictionary.Add('Port', $PortParam)
        }

        $ParameterDictionary
    }






}

