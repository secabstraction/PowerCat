function New-SmbStream {
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client', Mandatory = $true)]
        [ValidatePattern("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$")]
        [String]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener', Mandatory = $true)]
        [Switch]$Listener,
        
        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [String]$PipeName, 
        
        [Parameter()]
        [Int]$Timeout = 60
    )

    if ($Listener.IsPresent) {

        $PipeServer = New-Object IO.Pipes.NamedPipeServerStream($PipeName, [IO.Pipes.PipeDirection]::InOut, 1, [IO.Pipes.PipeTransmissionMode]::Byte)
        $ConnectResult = $PipeServer.BeginWaitForConnection($null, $null)
       
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if (($Key.Modifiers -band [ConsoleModifiers]::Control) -and ($Key.Key -eq 'C')) {
                    Write-Warning "Caught escape sequence, stopping Smb Setup."
                    $PipeServer.Dispose()
                    $Stopwatch.Stop()
                    [console]::TreatControlCAsInput = $false
                    exit
                }
            }

            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping UDP Setup."
                $PipeServer.Dispose()
                $Stopwatch.Stop()
                [console]::TreatControlCAsInput = $false
                exit
            }
        } until ($ConnectResult.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        try { $PipeServer.EndWaitForConnection($ConnectResult) }
        catch { 
            Write-Warning "Pipe server connection failed. $($_.Exception.Message)." 
            $PipeServer.Dispose()
            exit
        }
        return $PipeServer
    }
    else { # Client

        $PipeClient = New-Object IO.Pipes.NamedPipeClientStream($ServerIp, $PipeName, [IO.Pipes.PipeDirection]::InOut)
        try { $PipeClient.Connect(($Timeout * 1000)) }
        catch { 
            Write-Warning "Pipe client connection failed. $($_.Exception.Message)." 
            $PipeClient.Dispose()
            exit
        }
        return $PipeClient
    }
}