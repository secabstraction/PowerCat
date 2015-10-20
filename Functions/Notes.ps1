# Initialize-NetworkStream                    >> Waits for network connection
# Initialize-IOStream -Console                >> 
# Read-NetworkStream 
# Write-IOStream
New-PowerCat -Listener -Port 444 
New-PowerCat -Client 8.8.8.8 -Port 444

# 
New-PowerCat -Listener -Port 444 -OutputFile

# Read-IOStream/Input
# Write-NetworkStream
New-PowerCat -Execute ConsoleApp
New-PowerCat -PowerShell -ScriptBlock
New-PowerCat -Input byte[]
New-PowerCat -InputFile C:\file

# Read-NetworkStream
# Write-NetworkStream
New-PowerCat -RelayTo tcp:10.10.10.10:444
New-PowerCat -RelayTo tcp:10.10.10.10:444
New-PowerCat -PowerShell