function Read-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream
    )    
    switch ($Mode) {
        'Smb' { 
            try { $BytesRead = $Stream.Pipe.EndRead($Stream.Read) }
            catch { Write-Warning "Failed to read Smb data. $($_.Exception.Message)." ; continue }

            if ($BytesRead) {
                $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]
                [Array]::Clear($Stream.Buffer, 0, $BytesRead)
            }
            $Stream.Read = $Stream.Pipe.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)
            
            if ($BytesRead) { return $BytesReceived }
            else { Write-Verbose '0 bytes read from smb stream.' ; continue }
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
            else { Write-Verbose '0 bytes read from tcp stream.' ; continue }
        }
        'Udp' { 
            try { $Bytes = $Stream.UdpClient.EndReceive($Stream.Read, [ref]$Stream.Socket.RemoteEndpoint) }
            catch { Write-Warning "Failed to receive Udp data from $($Stream.Socket.RemoteEndpoint.ToString()). $($_.Exception.Message)." ; continue }
            
            $Stream.Read = $Stream.UdpClient.BeginReceive($null, $null)

            return $Bytes
        }
    }
}