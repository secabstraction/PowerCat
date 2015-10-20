function Read-UdpData {
    Param ($UdpClient)

    $Data = $null
    if ($UdpClient.StreamReadOperation.IsCompleted) {
        $StreamBytesRead = $UdpClient.Socket.Client.EndReceiveFrom($UdpClient.StreamReadOperation, [ref]$UdpClient.IPEndPoint)
      
        if ($StreamBytesRead -eq 0) { break }

        $Data = $UdpClient.StreamDestinationBuffer[0..([int]$StreamBytesRead - 1)]
        $UdpClient.StreamReadOperation = $UdpClient.Socket.Client.BeginReceiveFrom($UdpClient.StreamDestinationBuffer, 0, $UdpClient.BufferSize, [Net.Sockets.SocketFlags]::None, [ref]$UdpClient.IPEndPoint, $null, $null)
    }
    return $Data, $UdpClient
}
