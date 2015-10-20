while ($TcpStream.Socket.Available) {
    $Bytes += Read-TcpStream -BufferSize $TcpStream.Socket.Available
}

if ($UdpClient.Available) {
    $bytes = Read-UdpStream
    Write-IOStream $Data
}