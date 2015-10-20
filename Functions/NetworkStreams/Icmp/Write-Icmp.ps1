function Write-Icmp {
    Param ($Stream, $Data)

    [void]$Stream.Socket.SendTo($Data, $Stream.RemoteEndPoint)

    return $Stream
}