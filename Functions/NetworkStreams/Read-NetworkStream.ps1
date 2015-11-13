function Read-NetworkStream {
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
            try { $BytesRead = $Stream.Pipe.EndRead($Stream.Read) }
            catch { Write-Warning "Failed to read Smb stream. $($_.Exception.Message)." ; continue }

            if ($BytesRead) {
                $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]
                [Array]::Clear($Stream.Buffer, 0, $BytesRead)
            }
            $Stream.Read = $Stream.Pipe.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)
            
            if ($BytesRead) { return $BytesReceived }
            else { Write-Verbose 'Smb stream closed by remote end.' ; continue }
        }
        'Tcp' { 
            try { $BytesRead = $Stream.TcpStream.EndRead($Stream.Read) }
            catch { Write-Warning "Failed to read Tcp stream. $($_.Exception.Message)." ; continue }
                
            if ($BytesRead) {
                $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]
                [Array]::Clear($Stream.Buffer, 0, $BytesRead)
            }
            $Stream.Read = $Stream.TcpStream.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)
                
            if ($BytesRead) { return $BytesReceived }
            else { Write-Verbose 'Tcp stream closed by remote end.' ; continue }
        }
        'Udp' { 
            try { $Bytes = $Stream.UdpClient.EndReceive($Stream.Read, [ref]$Stream.Socket.RemoteEndpoint) }
            catch { Write-Warning "Failed to receive Udp data from $($Stream.Socket.RemoteEndpoint.ToString()). $($_.Exception.Message)." ; continue }
            
            $Stream.Read = $Stream.UdpClient.BeginReceive($null, $null)

            return $Bytes
        }
    }
}