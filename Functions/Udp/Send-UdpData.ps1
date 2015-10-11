function Send-UdpData {
    Param ($Data, $UdpClient)

    [void]$UdpClient.Socket.Client.SendTo($Data,$UdpClient.IPEndPoint)

    return $UdpClient
}
