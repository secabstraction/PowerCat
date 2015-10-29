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
            catch { Write-Warning "Failed to dispose Icmp socket. $($_.Exception.Message)." }
            
            continue 
        }
        'Smb' { 
            try { $Stream.Pipe.Close() ; $Stream.Pipe.Dispose()  }
            catch { Write-Warning "Failed to dispose Smb stream. $($_.Exception.Message)." }
            
            continue 
        }
        'Tcp' { 
            try { $Stream.Socket.Dispose() }
            catch { Write-Warning "Failed to dispose Tcp socket. $($_.Exception.Message)." }
            
            continue 
        }
        'Udp' { 
            try { $Stream.Socket.Dispose() }
            catch { Write-Warning "Failed to dispose Udp socket. $($_.Exception.Message)." }
        }
    }
}