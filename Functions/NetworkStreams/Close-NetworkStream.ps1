function Close-NetworkStream {
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet('Icmp', 'Smb', 'Tcp', 'Udp')]
        [String]$Mode,
    
        [Parameter(Position = 1, Mandatory = $true)]
        [Object]$Stream
    )    
    switch ($Mode) {
        'Icmp' { 
            try { $Stream.Socket.Dispose() }
            catch { Write-Warning "Failed to dispose Icmp socket. $($_.Exception.Message)." ; continue }
            Write-Verbose 'Icmp connection closed.'
        }
        'Smb' { 
            try { $Stream.Pipe.Dispose() }
            catch { Write-Warning "Failed to dispose Smb stream. $($_.Exception.Message)." ; continue }
            Write-Verbose 'Smb connection closed.'
            continue 
        }
        'Tcp' { 
            try { $Stream.Socket.Dispose() ; $Stream.TcpStream.Dispose() }
            catch { Write-Warning "Failed to dispose Tcp socket. $($_.Exception.Message)." ; continue }
            Write-Verbose 'Tcp connection closed.'
            continue 
        }
        'Udp' { 
            try { $Stream.Socket.Dispose() ; $Stream.UdpClient.Dispose() }
            catch { Write-Warning "Failed to dispose Udp socket. $($_.Exception.Message)." ; continue }
            Write-Verbose 'Udp connection closed.'
        }
    }
}