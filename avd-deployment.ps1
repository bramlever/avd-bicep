#=== PARAMETERS ===
param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountName
)

#=== PADEN DEFINIËREN ===
$avdPath = "C:\Packages\AVD"
$logPath = "$avdPath\register.log"
$tokenPath = "$avdPath\registrationToken.txt"
$infraPath = "C:\Program Files\Microsoft RDInfra"
$infraTokenPath = "$infraPath\registrationToken.txt"

#=== VOORBEREIDING ===
New-Item -ItemType Directory -Path $avdPath -Force | Out-Null
"[$(Get-Date)] Script gestart" | Out-File -FilePath $logPath -Append
"[$(Get-Date)] Token ontvangen: $registrationToken" | Out-File -FilePath $logPath -Append

Set-Content -Path $tokenPath -Value $registrationToken
"[$(Get-Date)] Token opgeslagen in $tokenPath" | Out-File -FilePath $logPath -Append

#=== AANMAKEN RDInfra-PAD EN TOKENKOPIE ===
try {
    New-Item -ItemType Directory -Path $infraPath -Force | Out-Null
    Set-Content -Path $infraTokenPath -Value $registrationToken
    "[$(Get-Date)] Token ook opgeslagen in $infraTokenPath" | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij aanmaken RDInfra-map of tokenbestand: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== WACHTPERIODE VOOR SERVICES ===
Start-Sleep -Seconds 5
"[$(Get-Date)] Wachtperiode voltooid" | Out-File -FilePath $logPath -Append

#=== DOWNLOAD VAN INSTALLERS ===
try {
    $agentUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/Microsoft.RDInfra.RDAgent.Installer-x64-1.0.12183.900.msi"
    $bootloaderUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi"
    $sxsUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/SxSStack-1.0.2507.25500.msi"

    $agentDest = "$avdPath\RDAgent.msi"
    $bootloaderDest = "$avdPath\BootLoader.msi"
    $sxsDest = "$avdPath\SxSStack.msi"

    Invoke-WebRequest -Uri $agentUrl -OutFile $agentDest -UseBasicParsing
    Invoke-WebRequest -Uri $bootloaderUrl -OutFile $bootloaderDest -UseBasicParsing
    Invoke-WebRequest -Uri $sxsUrl -OutFile $sxsDest -UseBasicParsing

    "[$(Get-Date)] Installers gedownload." | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij downloaden van installers: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== INSTALLATIE VAN AVD AGENT MET TOKEN ===
try {
    Start-Process msiexec.exe -ArgumentList "/i `"$agentDest`" REGISTRATIONTOKEN=`"$registrationToken`" /quiet /norestart" -Wait
    "[$(Get-Date)] Agent geïnstalleerd met token." | Out-File -FilePath $logPath -Append
    Start-Sleep -Seconds 2
} catch {
    "[$(Get-Date)] Fout bij installatie van Agent: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== INSTALLATIE VAN BOOTLOADER ===
try {
    Start-Process msiexec.exe -ArgumentList "/i `"$bootloaderDest`" /quiet /norestart" -Wait
    "[$(Get-Date)] Bootloader geïnstalleerd." | Out-File -FilePath $logPath -Append
    Start-Sleep -Seconds 2
} catch {
    "[$(Get-Date)] Fout bij installatie van Bootloader: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== INSTALLATIE VAN SxSStack COMPONENT ===
try {
    Start-Process msiexec.exe -ArgumentList "/i `"$sxsDest`" /quiet /norestart" -Wait
    "[$(Get-Date)] SxSStack component geïnstalleerd." | Out-File -FilePath $logPath -Append
    Start-Sleep -Seconds 2
} catch {
    "[$(Get-Date)] Fout bij installatie van SxSStack: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== FSLogix configuratie ===
try {
    $fslogixRegPath = "HKLM:\SOFTWARE\FSLogix\Profiles"
    if (-not (Test-Path $fslogixRegPath)) {
        New-Item -Path $fslogixRegPath -Force | Out-Null
    }

    $fslogixShare = "\\$storageAccountName.file.core.windows.net\profiles"

    Set-ItemProperty -Path $fslogixRegPath -Name "Enabled" -Value 1 -Type DWord
    New-ItemProperty -Path $fslogixRegPath -Name "VHDLocations" -PropertyType MultiString -Value $fslogixShare -Force
    Set-ItemProperty -Path $fslogixRegPath -Name "VolumeType" -Value "vhdx" -Type String
    Set-ItemProperty -Path $fslogixRegPath -Name "SizeInMBs" -Value 30000 -Type DWord
    Set-ItemProperty -Path $fslogixRegPath -Name "IsDynamic" -Value 1 -Type DWord
    Set-ItemProperty -Path $fslogixRegPath -Name "AccessNetworkAsComputer" -Value 1 -Type DWord
    Set-ItemProperty -Path $fslogixRegPath -Name "DeleteLocalProfileWhenVHDMountFails" -Value 1 -Type DWord
    Set-ItemProperty -Path $fslogixRegPath -Name "FlipFlopProfileDirectoryName" -Value 1 -Type DWord

    "[$(Get-Date)] FSLogix registry settings toegepast." | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij FSLogix-configuratie: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== NTFS-permissies instellen op Azure Files share ===
try {
    $sharePath = "\\$storageAccountName.file.core.windows.net\profiles"
    $acl = Get-Acl $sharePath

    # Geef Modify-rechten aan Domain Users
    $identity = "GREEN\Domain Users"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($accessRule)

    Set-Acl -Path $sharePath -AclObject $acl
    "[$(Get-Date)] NTFS-permissies ingesteld voor $identity op $sharePath" | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij instellen NTFS-permissies: $_" | Out-File -FilePath $logPath -Append
}

#=== CONTROLE NA INSTALLATIE ===
if (Test-Path $infraPath) {
    "[$(Get-Date)] RDInfra-map aanwezig na installatie." | Out-File -FilePath $logPath -Append
    Get-ChildItem $infraPath -Recurse | Out-File -FilePath $logPath -Append
} else {
    "[$(Get-Date)] RDInfra-map ontbreekt na installatie. Agent mogelijk niet correct geïnstalleerd." | Out-File -FilePath $logPath -Append
}

"[$(Get-Date)] Herstart van de VM wordt uitgevoerd..." | Out-File -FilePath $logPath -Append
Restart-Computer -Force
