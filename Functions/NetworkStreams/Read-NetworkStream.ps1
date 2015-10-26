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
        'Icmp' { 
            $Buffer = New-Object Byte[] -ArgumentList $Size

            try { $BytesReceived = $Stream.Socket.ReceiveFrom($Buffer, $Stream.RemoteEndPoint) }
            catch { 
                Write-Warning "Failed to receive Icmp data from $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)." 
                Remove-Variable Buffer 
                continue
            }
            
            return $Buffer[0..($BytesReceived - 1)] 
        }
        'Smb' { 
            
            try { $BytesRead = $Stream.Pipe.EndRead($Stream.Read) }
            catch { Write-Warning "Failed to read Smb data. $($_.Exception.Message)." ; continue }

            $BytesReceived = $Stream.Buffer[0..($BytesRead - 1)]
            [Array]::Clear($Stream.Buffer, 0, $BytesRead)

            $Stream.Read = $Stream.Pipe.BeginRead($Stream.Buffer, 0, $Stream.Buffer.Length, $null, $null)

            return $BytesReceived
        }
        'Tcp' { 
            if ($Stream.TcpStream.CanRead) {
                
                $Buffer = New-Object Byte[] -ArgumentList $Size

                try { $BytesRead = $Stream.TcpStream.Read($Buffer, 0, $Size) }
                catch { 
                    Write-Warning "Failed to read Tcp stream. $($_.Exception.Message)." 
                    Remove-Variable Buffer 
                    continue
                }

                return $Buffer[0..($BytesRead - 1)]
            }
            else { Write-Warning 'Tcp stream cannot be read.' ; continue }
        }
        'Udp' { 
            try { $Bytes = $Stream.UdpClient.Receive([ref]$Stream.RemoteEndPoint) }
            catch { Write-Warning "Failed to receive Udp data from $($Stream.RemoteEndPoint.ToString()). $($_.Exception.Message)." ; continue }

            return $Bytes
        }
    }
}