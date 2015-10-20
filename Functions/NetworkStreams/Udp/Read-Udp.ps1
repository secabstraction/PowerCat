function Read-UdpStream {
    Param ($Stream)

    $Data = $Stream.UdpClient.Receive([ref]$Stream.RemoteEndPoint)
      
    if ($Data.Count -eq 0) { return }

    return $Data
}