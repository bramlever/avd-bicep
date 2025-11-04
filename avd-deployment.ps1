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
Set-ItemProperty -Path $fslogixRegPath -Name "AccessNetworkAsComputer" -Value 1
Set-ItemProperty -Path $fslogixRegPath -Name "DeleteLocalProfileWhenVHDMountFails" -Value 1
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

# === NTFS-permissies voorbereiden ===
$paramObject = @{
    storageAccountName = $storageAccountName
    fileShareName = $fileShareName
}
$paramPath = "$avdPath\ntfsparams.json"
$paramObject | ConvertTo-Json | Out-File -FilePath $paramPath -Encoding UTF8

$ntfsScriptPath = "$avdPath\ntfs-after-reboot.ps1"
@"
`$log = '$avdPath\ntfs-after-reboot.log'
function Log(`$m) { "`$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - `$m" | Out-File -FilePath `$log -Append }

Log "Script gestart"

`$params = Get-Content '$paramPath' | ConvertFrom-Json
`$share = "\\`$(`$params.storageAccountName).file.core.windows.net\`$(`$params.fileShareName)"

`$attempt = 0
`$max = 10
`$ok = `$false

while (-not `$ok -and `$attempt -lt `$max) {
    if (Test-Path `$share) {
        `$ok = `$true
        Log "Share bereikbaar: `$share"
    } else {
        Log "Share niet bereikbaar, poging `$(`$attempt + 1)"
        Start-Sleep -Seconds 15
        `$attempt++
    }
}

if (`$ok) {
    try {
        `$acl = Get-Acl `$share
        `$rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        `$acl.AddAccessRule(`$rule)
        Set-Acl -Path `$share -AclObject `$acl
        Log "NTFS-permissies succesvol toegepast"
    } catch {
        Log "FOUT bij Set-Acl: `$($_)"
    }
} else {
    Log "Share niet bereikbaar na `$max pogingen"
}
"@ | Out-File -FilePath $ntfsScriptPath -Encoding UTF8

$taskName = "RunNTFSSetupAfterReboot"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ntfsScriptPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force

# === SMB firewall rule (optioneel) ===
New-NetFirewallRule -DisplayName "Allow SMB Outbound" -Direction Outbound -Protocol TCP -RemotePort 445 -Action Allow

"[$