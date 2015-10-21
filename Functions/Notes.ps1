# Initialize-NetworkStream                    >> Waits for network connection


# Initialize-IOStream -Console                >> BeginRead
# If ($NetStream.Available)
#     Read-NetworkStream
#     Write-IOStream                          >> BeginRead
#
# If ($IOStream.Read.IsCompleted)
#     Read-IOStream
#     Write-NetworkStream
Start-PowerCat -Mode Tcp -Port 444 
Connect-PowerCat -Mode Tcp -RemoteIp 8.8.8.8 -Port 444

# If ($NetStream.Available)
# Read-NetworkStream
# WriteAllBytes
Start-PowerCat -Mode Tcp -Port 444 -OutputFile C:\Pathto\output.file

# Initialize-IOStream
# If ($IOStream.Read.IsCompleted)
#     Read-IOStream
#     Write-NetworkStream
New-PowerCat -Execute ConsoleApp
New-PowerCat -PowerShell -ScriptBlock


New-PowerCat -Input byte[]

New-PowerCat -SendFile C:\file

# Read-NetworkStream
# Write-NetworkStream
New-PowerCat -RelayTo tcp:10.10.10.10:444
New-PowerCat -RelayTo tcp:10.10.10.10:444
New-PowerCat -PowerShell