function Close-NetworkStream {
    Param (
        [Parameter(Position = 0)]
        [String]$Mode,
    
        [Parameter(Position = 1)]
        [Object]$Stream
    )    
    switch ($Mode) {
        'Smb' { 
            try { $Stream.Pipe.Dispose() }
            catch { Write-Warning "Failed to dispose Smb stream. $($_.Exception.Message)." }
            continue 
        }
        'Tcp' { 
            try { $Stream.Socket.Dispose() ; $Stream.TcpStream.Dispose() }
            catch { Write-Warning "Failed to dispose Tcp socket. $($_.Exception.Message)." }
            continue 
        }
        'Udp' { 
            try { $Stream.Socket.Dispose() ; $Stream.UdpClient.Dispose() }
            catch { Write-Warning "Failed to dispose Udp socket. $($_.Exception.Message)." }
        }
    }
}