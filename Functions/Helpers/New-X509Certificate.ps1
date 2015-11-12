function New-X509Certificate { 
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$SslKey,

        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateSet(1024,2048)]
        [Int]$KeyLength = 1024
    )      
    $DN = New-Object -ComObject 'X509Enrollment.CX500DistinguishedName.1'
    $DN.Encode("CN=$ServerName", 0)

    $PrivateKey = New-Object -ComObject 'X509Enrollment.CX509PrivateKey.1'
    $PrivateKey.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $PrivateKey.KeySpec = 1
    $PrivateKey.Length = $KeyLength
    $PrivateKey.MachineContext = 1
    $PrivateKey.Create()

    $ServerAuthOid = New-Object -ComObject 'X509Enrollment.CObjectId.1'
    $ServerAuthOid.InitializeFromValue('1.3.6.1.5.5.7.3.1')
    $EkuOid = New-Object -ComObject 'X509Enrollment.CObjectIds.1'
    $EkuOid.Add($ServerAuthOid)
    $EkuExtension = New-Object -ComObject 'X509Enrollment.CX509ExtensionEnhancedKeyUsage.1'
    $EkuExtension.InitializeEncode($EkuOid)

    $Certificate = New-Object -ComObject 'X509Enrollment.CX509CertificateRequestCertificate.1'
    $Certificate.InitializeFromPrivateKey(2, $PrivateKey, "")
    $Certificate.Subject = $DN
    $Certificate.Issuer = $Certificate.Subject
    $Certificate.NotBefore = [DateTime]::Now.AddDays(-1)
    $Certificate.NotAfter = $Certificate.NotBefore.AddDays(90)
    $Certificate.X509Extensions.Add($EkuExtension)
    $Certificate.Encode()
    
    return $Certificate
}