function Open-IOStream {


    if($PSBoundParameters.Execute) {
        Write-Verbose "Set Stream 2: Process"
        $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_CMD} + "`n}`n`n")
        $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_CMD} + "`n}`n`n")
        $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_CMD} + "`n}`n`n")
        $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_CMD} + "`n}`n`n")
        $InvokeString += "@('$e')`n`n"
    }

    elseif($PSBoundParameters.PowerShell) {
        Write-Verbose "Set Stream 2: Powershell"
        $InvokeString += "`n`n"
    }

    elseif($PSBoundParameters.RelayTo) {
    
        if($RelayTo.split(":")[0].ToLower() -eq "udp") {
            Write-Verbose "Set Stream 2: UDP"
            $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_UDP} + "`n}`n`n")
            $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_UDP} + "`n}`n`n")
            $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_UDP} + "`n}`n`n")
            $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_UDP} + "`n}`n`n")    
            if($r.split(":").Count -eq 2){$InvokeString += ("@('',`$True,'" + $r.split(":")[1] + "','$t') ")}
            elseif($r.split(":").Count -eq 3){$InvokeString += ("@('" + $r.split(":")[1] + "',`$False,'" + $r.split(":")[2] + "','$t') ")}
            else{return "Bad relay format."}
        }
        if($r.split(":")[0].ToLower() -eq "dns") {
            Write-Verbose "Set Stream 2: DNS"
            $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_DNS} + "`n}`n`n")
            $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_DNS} + "`n}`n`n")
            $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_DNS} + "`n}`n`n")
            $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_DNS} + "`n}`n`n")
            if($r.split(":").Count -eq 2){return "This feature is not available."}
            elseif($r.split(":").Count -eq 4){$InvokeString += ("@('" + $r.split(":")[1] + "','" + $r.split(":")[2] + "','" + $r.split(":")[3] + "',$dnsft) ")}
            else{return "Bad relay format."}
        }
        elseif($r.split(":")[0].ToLower() -eq "tcp") {
            Write-Verbose "Set Stream 2: TCP"
            $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_TCP} + "`n}`n`n")
            $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_TCP} + "`n}`n`n")
            $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_TCP} + "`n}`n`n")
            $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_TCP} + "`n}`n`n")
            if($r.split(":").Count -eq 2){$InvokeString += ("@('',`$True,'" + $r.split(":")[1] + "','$t') ")}
            elseif($r.split(":").Count -eq 3){$InvokeString += ("@('" + $r.split(":")[1] + "',`$False,'" + $r.split(":")[2] + "','$t') ")}
            else{return "Bad relay format."}
        }
    }
    
    else {
        Write-Verbose "Set Stream 2: Console"
        $FunctionString += ("function Stream2_Setup`n{`n" + ${function:Setup_Console} + "`n}`n`n")
        $FunctionString += ("function Stream2_ReadData`n{`n" + ${function:ReadData_Console} + "`n}`n`n")
        $FunctionString += ("function Stream2_WriteData`n{`n" + ${function:WriteData_Console} + "`n}`n`n")
        $FunctionString += ("function Stream2_Close`n{`n" + ${function:Close_Console} + "`n}`n`n")
        $InvokeString += ("@('" + $o + "')")
    }
  
    if ($PSBoundParameters.PowerShell) { $FunctionString += ("function Main`n{`n" + ${function:Main_Powershell} + "`n}`n`n") }
    else { $FunctionString += ("function Main`n{`n" + ${function:Main} + "`n}`n`n") }

    $InvokeString = ($FunctionString + $InvokeString)
}