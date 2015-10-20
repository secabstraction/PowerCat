function Write-Udp {
    Param ($Stream, $Data)

    [void]$Stream.Socket.Client.SendTo($Data, $Stream.RemoteEndPoint)

    return $Stream
}