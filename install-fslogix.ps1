param (
    [string]$storageAccountName,
    [string]$fileShareName = "profiles"
)

# UNC-pad genereren
$fslogixPath = "\\$storageAccountName.file.core.windows.net\$fileShareName"

# Registry pad voor FSLogix
$regPath = "HKLM:\SOFTWARE\FSLogix\Profiles"

# Zorg dat het pad bestaat
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# FSLogix instellingen
Set-ItemProperty -Path $regPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name "VHDLocations" -Value $fslogixPath -Type MultiString
Set-ItemProperty -Path $regPath -Name "VolumeType" -Value "vhdx" -Type String
Set-ItemProperty -Path $regPath -Name "SizeInMBs" -Value 30000 -Type DWord
Set-ItemProperty -Path $regPath -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $regPath -Name "AccessNetworkAsComputer" -Value 1 -Type DWord

Write-Output "FSLogix configuratie toegepast voor: $fslogixPath"
