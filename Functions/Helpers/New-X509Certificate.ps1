function New-X509Certificate { 
<#
Author: Jesse Davis (@secabstraction)
License: BSD 3-Clause
#>
    Param (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$CommonName
    )      
    $DN = New-Object -ComObject 'X509Enrollment.CX500DistinguishedName.1'
    $DN.Encode("CN=$CommonName", 0)

    $PrivateKey = New-Object -ComObject 'X509Enrollment.CX509PrivateKey.1'
    $PrivateKey.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $PrivateKey.KeySpec = 1 # XCN_AT_KEYEXCHANGE
    $PrivateKey.ExportPolicy = 2 # XCN_NCRYPT_ALLOW_PLAINTEXT_EXPORT_FLAG
    $PrivateKey.MachineContext = $true
    $PrivateKey.Length = 2048
    $PrivateKey.Create()

    $HashAlg = New-Object -ComObject 'X509Enrollment.CObjectId.1'
    $HashAlg.InitializeFromAlgorithmName(1, 0, 0, 'SHA512')

    $ServerAuthOid = New-Object -ComObject 'X509Enrollment.CObjectId.1'
    $ServerAuthOid.InitializeFromValue('1.3.6.1.5.5.7.3.1')
    $EkuOid = New-Object -ComObject 'X509Enrollment.CObjectIds.1'
    $EkuOid.Add($ServerAuthOid)
    $EkuExtension = New-Object -ComObject 'X509Enrollment.CX509ExtensionEnhancedKeyUsage.1'
    $EkuExtension.InitializeEncode($EkuOid)

    $Certificate = New-Object -ComObject 'X509Enrollment.CX509CertificateRequestCertificate.1'
    $Certificate.InitializeFromPrivateKey(2, $PrivateKey, '')
    $Certificate.Subject = $DN
    $Certificate.Issuer = $Certificate.Subject
    $Certificate.NotBefore = [DateTime]::Now.AddDays(-1)
    $Certificate.NotAfter = $Certificate.NotBefore.AddDays(90)
    $Certificate.X509Extensions.Add($EkuExtension)
    $Certificate.HashAlgorithm = $HashAlg
    $Certificate.Encode()

    $Enroll = New-Object -ComObject 'X509Enrollment.CX509Enrollment.1'
    $Enroll.InitializeFromRequest($Certificate)
    $Enroll.CertificateFriendlyName = $CommonName
    $Csr = $Enroll.CreateRequest()
    $Enroll.InstallResponse(2, $Csr, 1, '')
    $Base64 = $Enroll.CreatePFX('', 0)

    $Bytes = [Convert]::FromBase64String($Base64)
    $X509Cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($Bytes, '')
    
    return $X509Cert
}