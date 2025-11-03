param (
    [string]$storageAccountName,
    [string]$fileShareName,
    [string]$domainNetbiosName
)

$sharePath = "\\$storageAccountName.file.core.windows.net\$fileShareName"

if (Test-Path $sharePath) {
    $acl = Get-Acl $sharePath
    $identity = "$domainNetbiosName\Domain Users"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($accessRule)
    Set-Acl -Path $sharePath -AclObject $acl
    Write-Output "NTFS-permissies succesvol toegepast op $sharePath voor $identity"
} else {
    Write-Output "Sharepad niet bereikbaar: $sharePath"
}
