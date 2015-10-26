function Write-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream,
    
        [Parameter(Position = 2, Mandatory = $true)]
        [Byte[]]$Bytes
    )    
    switch ($Mode) {
        'Icmp' { 
            try { $BytesSent = $Stream.Socket.SendTo($Bytes, $Stream.RemoteEndPoint) }
            catch { Write-Warning "Failed to send Icmp data to $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)" }
            continue 
        }
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
            try { $BytesSent = $Stream.UdpClient.Send($Bytes, $Bytes.Length, $Stream.RemoteEndPoint) }
            catch { Write-Warning "Failed to send Udp data to $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)." }
        }
    }
}