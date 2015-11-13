function Write-NetworkStream {
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
    Param (
        [Parameter(Position = 0)]
        [String]$Mode,
    
        [Parameter(Position = 1)]
        [Object]$Stream,
    
        [Parameter(Position = 2)]
        [Byte[]]$Bytes
    )    
    switch ($Mode) {
        'Smb' { 
            try { $Stream.Pipe.Write($Bytes, 0, $Bytes.Length) }
            catch { Write-Warning "Failed to send Smb data. $($_.Exception.Message)" }
            continue 
        }
        'Tcp' { 
            try { $Stream.TcpStream.Write($Bytes, 0, $Bytes.Length) }
            catch { Write-Warning "Failed to write to Tcp stream. $($_.Exception.Message)." }
            continue 
        }
        'Udp' { 
            try { $BytesSent = $Stream.UdpClient.Send($Bytes, $Bytes.Length) }
            catch { Write-Warning "Failed to send Udp data to $($Stream.Socket.RemoteEndPoint.ToString()). $($_.Exception.Message)." }
        }
    }
}