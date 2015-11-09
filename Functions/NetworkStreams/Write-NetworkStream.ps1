function Write-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream,
    
        [Parameter(Position = 2, Mandatory = $true)]
        [Byte[]]$Bytes
    )    
    switch ($Mode) {
        'Smb' { 
            try { $Stream.Pipe.Write($Bytes, 0, $Bytes.Length) }
            catch { Write-Warning "Failed to send Smb data. $($_.Exception.Message)" ; return }
            continue 
        }
        'Tcp' { 
            if ($Stream.TcpStream.CanWrite) {
                try { $Stream.TcpStream.Write($Bytes, 0, $Bytes.Length) }
                catch { Write-Warning "Failed to write to Tcp stream. $($_.Exception.Message)." }
            }
            else { Write-Warning 'Tcp stream cannot be written to.' }
            continue 
        }
        'Udp' { 
            try { $BytesSent = $Stream.UdpClient.Send($Bytes, $Bytes.Length) }
            catch { Write-Warning "Failed to send Udp data to $($Stream.Socket.RemoteEndPoint.ToString()). $($_.Exception.Message)." }
        }
    }
}