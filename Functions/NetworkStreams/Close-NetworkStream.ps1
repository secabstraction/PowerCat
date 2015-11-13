function Close-NetworkStream {
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
    Param (
        [Parameter(Position = 0)]
        [String]$Mode,
    
        [Parameter(Position = 1)]
        [Object]$Stream
    )    
    switch ($Mode) {
        'Smb' { 
            try { $Stream.Pipe.Dispose() }
            catch { Write-Verbose "Failed to close Smb stream. $($_.Exception.Message)." }
            continue 
        }
        'Tcp' { 
            try { 
                if ($PSVersionTable.CLRVersion.Major -lt 4) { $Stream.Socket.Close() ; $Stream.TcpStream.Close() }
                else { $Stream.Socket.Dispose() ; $Stream.TcpStream.Dispose() }
            }
            catch { Write-Verbose "Failed to close Tcp stream. $($_.Exception.Message)." }
            continue 
        }
        'Udp' { 
            try { 
                if ($PSVersionTable.CLRVersion.Major -lt 4) { $Stream.Socket.Close() ; $Stream.UdpClient.Close() }
                else { $Stream.Socket.Dispose() ; $Stream.UdpClient.Dispose() }
            }
            catch { Write-Verbose "Failed to close Udp stream. $($_.Exception.Message)." }
        }
    }
}