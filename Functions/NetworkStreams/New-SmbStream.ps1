function New-SmbStream {
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
[CmdletBinding(DefaultParameterSetName = 'Client')]
    Param (
        [Parameter(Position = 0, ParameterSetName = 'Client')]
        [String]$ServerIp,
        
        [Parameter(Position = 0, ParameterSetName = 'Listener')]
        [Switch]$Listener,
        
        [Parameter(Position = 1)]
        [ValidateNotNullorEmpty()]
        [String]$PipeName,  

        [Parameter(Position = 3)]
        [Int]$Timeout = 60,
        
        [Parameter()]
        [Int]$BufferSize = 65536
    )

    if ($Listener.IsPresent) {
        $PipeSecurity = New-Object IO.Pipes.PipeSecurity
        $PipeServer = New-Object IO.Pipes.NamedPipeServerStream($PipeName, 3, 1, 0, [IO.Pipes.PipeOptions]::Asynchronous, $BufferSize, $BufferSize, $PipeSecurity, 0, [IO.Pipes.PipeAccessRights]::ChangePermissions)
        $PipeSecurity = $PipeServer.GetAccessControl()
        $PipeSecurity.AddAccessRule((New-Object IO.Pipes.PipeAccessRule("Everyone", [IO.Pipes.PipeAccessRights]::FullControl, 0)))
        $PipeServer.SetAccessControl($PipeSecurity)
        $ConnectResult = $PipeServer.BeginWaitForConnection($null, $null)

        Write-Verbose "Listening on 0.0.0.0:$PipeName [smb]"
       
        $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
        [console]::TreatControlCAsInput = $true
      
        do {
            if ([console]::KeyAvailable) {          
                $Key = [console]::ReadKey($true)
                if ($Key.Key -eq [Consolekey]::Escape) {
                    Write-Warning "Caught escape sequence, stopping Smb Setup."
                    [console]::TreatControlCAsInput = $false
                    $PipeServer.Dispose()
                    $Stopwatch.Stop()
                    return
                }
            }
            if ($Stopwatch.Elapsed.TotalSeconds -gt $Timeout) {
                Write-Warning "Timeout exceeded, stopping Smb Setup."
                [console]::TreatControlCAsInput = $false
                $PipeServer.Dispose()
                $Stopwatch.Stop()
                return
            }
        } until ($ConnectResult.IsCompleted)
        
        [console]::TreatControlCAsInput = $false
        $Stopwatch.Stop()

        try { $PipeServer.EndWaitForConnection($ConnectResult) }
        catch { 
            Write-Warning "Pipe server connection failed. $($_.Exception.Message)." 
            $PipeServer.Dispose()
            return
        }
        Write-Verbose "Connection from client accepted."

        $Buffer = New-Object Byte[] $BufferSize

        $Properties = @{
            Pipe = $PipeServer
            Buffer = $Buffer
            Read = $PipeServer.BeginRead($Buffer, 0, $Buffer.Length, $null, $null)
        }
        New-Object psobject -Property $Properties
    }
    else { # Client

        $PipeClient = New-Object IO.Pipes.NamedPipeClientStream($ServerIp, $PipeName, [IO.Pipes.PipeDirection]::InOut, [IO.Pipes.PipeOptions]::Asynchronous)
        try { $PipeClient.Connect(($Timeout * 1000)) }
        catch { 
            Write-Warning "Pipe client connection failed. $($_.Exception.Message)." 
            $PipeClient.Dispose()
            return
        }
        Write-Verbose "Connected to $ServerIp`:$PipeName."

        $Buffer = New-Object Byte[] $BufferSize

        $Properties = @{
            Pipe = $PipeClient
            Buffer = $Buffer
            Read = $PipeClient.BeginRead($Buffer, 0, $Buffer.Length, $null, $null)
        }
        New-Object psobject -Property $Properties
    }
}