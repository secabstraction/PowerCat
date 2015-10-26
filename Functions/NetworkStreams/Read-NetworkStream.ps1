function Read-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream,
    
        [Parameter(Position = 2, Mandatory = $true)]
        [Int]$Size
    )    
    switch ($Mode) {
        'Icmp' { 
            $Buffer = New-Object Byte[] -ArgumentList $Size

            try { $BytesReceived = $Stream.Socket.ReceiveFrom($Buffer, $Stream.RemoteEndPoint) }
            catch { Write-Warning "Failed to receive Icmp data from $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)" }
            
            return $Buffer[0..($BytesReceived - 1)] 
        }
        'Smb' { 
            $Buffer = New-Object Byte[] -ArgumentList $Size
            
            try { $BytesRead = $Stream.Read($Buffer, 0, $Size)  }
            catch { Write-Warning "Failed to send Smb data. $($_.Exception.Message)" ; exit }
            
            return $Buffer[0..($BytesRead - 1)]
        }
        'Tcp' { 
            if ($Stream.TcpStream.CanRead) {
                
                $Buffer = New-Object Byte[] -ArgumentList $Size

                try { $BytesRead = $Stream.TcpStream.Read($Buffer, 0, $Size) }
                catch { Write-Warning "Failed to read Tcp stream. $($_.Exception.Message)." }

                return $Buffer[0..($BytesRead - 1)]
            }
            else { Write-Warning 'Tcp stream cannot be read.' }
        }
        'Udp' { 
            try { $Bytes = $Stream.UdpClient.Receive([ref]$Stream.RemoteEndPoint) }
            catch { Write-Warning "Failed to receive Udp data from $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)." }

            return $Bytes
        }
    }
}