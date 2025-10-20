#=== PARAMETERS ===
param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken
)

#=== PADEN DEFINIËREN ===
$avdPath = "C:\AVD"
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

    $agentDest = "$avdPath\Microsoft.RDInfra.RDAgent.Installer-x64-1.0.12183.900.msi"
    $bootloaderDest = "$avdPath\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64-1.0.11388.1600.msi"
    $sxsDest = "$avdPath\SxSStack-1.0.2507.25500.msi"

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

#=== CONTROLE NA INSTALLATIE ===
if (Test-Path $infraPath) {
    "[$(Get-Date)] RDInfra-map aanwezig na installatie." | Out-File -FilePath $logPath -Append
    Get-ChildItem $infraPath -Recurse | Out-File -FilePath $logPath -Append
} else {
    "[$(Get-Date)] RDInfra-map ontbreekt na installatie. Agent mogelijk niet correct geïnstalleerd." | Out-File -FilePath $logPath -Append
}

"[$(Get-Date)] Herstart van de VM wordt uitgevoerd..." | Out-File -FilePath $logPath -Append
Restart-Computer -Force
