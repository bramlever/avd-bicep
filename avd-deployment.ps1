param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$fileShareName
)

# === Logging setup ===
$avdPath = "C:\Packages\AVD"
$logPath = "$avdPath\setup.log"
New-Item -ItemType Directory -Path $avdPath -Force | Out-Null
Start-Transcript -Path $logPath -Append
"[$(Get-Date)] Script gestart" | Out-File -FilePath $logPath -Append

# === AVD agent installatie ===
$infraPath = "C:\Program Files\Microsoft RDInfra"
$infraTokenPath = "$infraPath\registrationToken.txt"
New-Item -ItemType Directory -Path $infraPath -Force | Out-Null
Set-Content -Path $infraTokenPath -Value $registrationToken

$agentUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/Microsoft.RDInfra.RDAgent.Installer-x64-1.0.12183.900.msi"
$bootloaderUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi"
$sxsUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/SxSStack-1.0.2507.25500.msi"

$agentDest = "$avdPath\RDAgent.msi"
$bootloaderDest = "$avdPath\BootLoader.msi"
$sxsDest = "$avdPath\SxSStack.msi"

Invoke-WebRequest -Uri $agentUrl -OutFile $agentDest -UseBasicParsing
Invoke-WebRequest -Uri $bootloaderUrl -OutFile $bootloaderDest -UseBasicParsing
Invoke-WebRequest -Uri $sxsUrl -OutFile $sxsDest -UseBasicParsing

Start-Process msiexec.exe -ArgumentList "/i `"$agentDest`" REGISTRATIONTOKEN=`"$registrationToken`" /quiet /norestart" -Wait
Start-Process msiexec.exe -ArgumentList "/i `"$bootloaderDest`" /quiet /norestart" -Wait
Start-Process msiexec.exe -ArgumentList "/i `"$sxsDest`" /quiet /norestart" -Wait

"[$(Get-Date)] AVD agent en componenten geïnstalleerd." | Out-File -FilePath $logPath -Append

# === FSLogix installatie ===
$fslogixUrl = "https://aka.ms/fslogix_download"
$tempZip = "$env:TEMP\fslogix.zip"
$tempDir = "$env:TEMP\fslogix"
Invoke-WebRequest -Uri $fslogixUrl -OutFile $tempZip
Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
$installer = Get-ChildItem -Path $tempDir -Recurse -Filter "*FSLogixAppsSetup.exe" | Select-Object -First 1
Start-Process -FilePath $installer.FullName -ArgumentList "/quiet /norestart" -Wait
"[$(Get-Date)] FSLogix geïnstalleerd." | Out-File -FilePath $logPath -Append

# === FSLogix configuratie ===
$fslogixRegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
$fslogixLogPath = "HKLM:\SOFTWARE\FSLogix\Logging"
New-Item -Path $fslogixRegPath -Force | Out-Null
New-Item -Path $fslogixLogPath -Force | Out-Null

$fslogixShare = "\\$storageAccountName.file.core.windows.net\$fileShareName"
Set-ItemProperty -Path $fslogixRegPath -Name "Enabled" -Value 1
New-ItemProperty -Path $fslogixRegPath -Name "VHDLocations" -PropertyType MultiString -Value $fslogixShare -Force
Set-ItemProperty -Path $fslogixRegPath -Name "VolumeType" -Value "vhdx"
Set-ItemProperty -Path $fslogixRegPath -Name "SizeInMBs" -Value 30000
Set-ItemProperty -Path $fslogixRegPath -Name "IsDynamic" -Value 1
Set-ItemProperty -Path $fslogixRegPath -Name "FlipFlopProfileDirectoryName" -Value 1
Set-ItemProperty -Path $fslogixRegPath -Name "ProfileType" -Value 3
Set-ItemProperty -Path $fslogixRegPath -Name "SIDDirNamePattern" -Value "%sid%_%username%"

Set-ItemProperty -Path $fslogixLogPath -Name "Enabled" -Value 1
Set-ItemProperty -Path $fslogixLogPath -Name "LogPath" -Value "C:\ProgramData\FSLogix\Logs"

# === Entra Kerberos registry keys ===
$cloudKerbPath1 = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\CloudKerberosTicketRetrieval"
New-Item -Path $cloudKerbPath1 -Force | Out-Null
Set-ItemProperty -Path $cloudKerbPath1 -Name "Enabled" -Value 1

$cloudKerbPath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters"
New-Item -Path $cloudKerbPath2 -Force | Out-Null
Set-ItemProperty -Path $cloudKerbPath2 -Name "CloudKerberosTicketRetrievalEnabled" -Value 1

"[$(Get-Date)] FSLogix en Entra Kerberos geconfigureerd." | Out-File -FilePath $logPath -Append

# === SMB firewall rule (optioneel) ===
New-NetFirewallRule -DisplayName "Allow SMB Outbound" -Direction Outbound -Protocol TCP -RemotePort 445 -Action Allow

"[$(Get-Date)] Script voltooid. VM wordt herstart..." | Out-File -FilePath $logPath -Append
Stop-Transcript

# === Reboot to finalize registration ===
Restart-Computer -Force
