$IcmpListener = New-Object Net.Sockets.Socket([Net.Sockets.AddressFamily]::InterNetwork, [Net.Sockets.SocketType]::Raw, [Net.Sockets.ProtocolType]::Icmp)
$IcmpListener.Bind((New-Object Net.IPEndPoint([Net.IPAddress]::Parse("10.10.10.10"), 0)))
$IcmpListener.IOControl([Net.Sockets.IOControlCode]::ReceiveAll, [byte[]]@(1, 0, 0, 0), [byte[]]@(1, 0, 0, 0));

$Buffer = New-Object byte[](128)
$RemoteEndPoint = New-Object Net.IPEndPoint([Net.IPAddress]::Any, 0)
$BytesRead = $IcmpListener.ReceiveFrom($Buffer, [ref]$RemoteEndPoint)
