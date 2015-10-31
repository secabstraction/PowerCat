function Read-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream,
    
        [Parameter(Position = 2)]
        [Int]$Size
    )    
    switch ($Mode) {
        'Smb' { 
            
            try { $BytesRead = $Stream.Pipe.EndRead($Stream.Read) }
            catch { Write-Warning "Failed to read Smb data. $($_.Exception.Message)." ; continue }

            if ($BytesRead) {
                $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]    # Grab only bytes written to buffer
                [Array]::Clear($Stream.Buffer, 0, $BytesRead)           # Clear buffer for next read
            }
            # Restart read operation
            $Stream.Read = $Stream.Pipe.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)
            
            if ($BytesRead) { return $BytesReceived }
            else { Write-Verbose '0 bytes read from smb stream.' ; continue }
        }
        'Tcp' { 
            if ($Stream.TcpStream.CanRead) {

                try { $BytesRead = $Stream.TcpStream.EndRead($Stream.Read) }
                catch { Write-Warning "Failed to read Tcp stream. $($_.Exception.Message)." ; continue }
                
                if ($BytesRead) {
                    $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]    # Grab only bytes written to buffer
                    [Array]::Clear($Stream.Buffer, 0, $BytesRead)           # Clear buffer for next read
                }
                $Stream.Read = $Stream.TcpStream.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)
                
                if ($BytesRead) { return $BytesReceived }
                else { Write-Verbose '0 bytes read from tcp stream.' ; continue }
            }
            else { Write-Warning 'Tcp stream cannot be read.' ; continue }
        }
        'Udp' { 
            try { $Bytes = $Stream.UdpClient.EndReceive($Stream.Read, [ref]$Stream.Socket.RemoteEndpoint) }
            catch { Write-Warning "Failed to receive Udp data from $($Stream.Socket.RemoteEndpoint.ToString()). $($_.Exception.Message)." ; continue }
            
            # Restart read operation
            $Stream.Read = $Stream.UdpClient.BeginReceive($null, $null)

            return $Bytes
        }
    }
}