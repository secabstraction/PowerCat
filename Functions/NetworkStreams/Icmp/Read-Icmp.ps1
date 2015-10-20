function Read-Icmp {
    Param ($Stream)

    $Data = $null
    if ($Stream.Read.IsCompleted) {
        $StreamBytesRead = $Stream.Socket.EndReceiveFrom($Stream.Read, [ref]$Stream.RemoteEndPoint)
      
        if ($StreamBytesRead -eq 0) { break }

        $Data = $Stream.Buffer[0..([int]$StreamBytesRead - 1)]
        $Stream.Read = $Stream.Socket.BeginReceiveFrom($Stream.Buffer, 0, $Stream.BufferSize, [Net.Sockets.SocketFlags]::None, [ref]$Stream.RemoteEndPoint, $null, $null)
    }
    return $Data, $Stream
}