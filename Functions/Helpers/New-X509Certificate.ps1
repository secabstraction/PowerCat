function New-X509Certificate { 
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName
    )      
    $DN = New-Object -ComObject 'X509Enrollment.CX500DistinguishedName.1'
    $DN.Encode("CN=$ServerName", 0)

    $PrivateKey = New-Object -ComObject 'X509Enrollment.CX509PrivateKey.1'
    $PrivateKey.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $PrivateKey.KeySpec = 1
    $PrivateKey.Length = 2048
    $PrivateKey.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $PrivateKey.MachineContext = 1
    $PrivateKey.Create()

    $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1")
    $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
    $ekuoids.add($serverauthoid)
    $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $PrivateKey, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = get-date
    $cert.NotAfter = $cert.NotBefore.AddDays(90)
    $cert.X509Extensions.Add($ekuext)
    $cert.Encode()

    $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")
}