#=== PARAMETERS ===
param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken
)

#=== PADEN DEFINIËREN ===
$avdPath = "C:\AVD"
$logPath = "$avdPath\register.log"
$tokenPath = "$avdPath\registrationToken.txt"
$agentExe = "C:\Program Files\Microsoft RDInfra\RDInfraAgent\RDInfraAgent.exe"

#=== VOORBEREIDING ===
New-Item -ItemType Directory -Path $avdPath -Force | Out-Null
"[$(Get-Date)] Script gestart" | Out-File -FilePath $logPath -Append
"[$(Get-Date)] Token ontvangen: $registrationToken" | Out-File -FilePath $logPath -Append
Set-Content -Path $tokenPath -Value $registrationToken
"[$(Get-Date)] Token opgeslagen in $tokenPath" | Out-File -FilePath $logPath -Append

#=== WACHTPERIODE VOOR SERVICES ===
Start-Sleep -Seconds 30
"[$(Get-Date)] Wachtperiode voltooid" | Out-File -FilePath $logPath -Append

#=== DOWNLOAD EN INSTALLATIE VAN AVD TOOLING ===
try {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bramlever/avd-bicep/main/AVDAgent.msi" -OutFile "$avdPath\AVDAgent.msi"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bramlever/avd-bicep/main/RDAgentBootLoader.msi" -OutFile "$avdPath\RDAgentBootLoader.msi"
    "[$(Get-Date)] MSI-bestanden gedownload." | Out-File -FilePath $logPath -Append

    Start-Process msiexec.exe -ArgumentList "/i $avdPath\AVDAgent.msi /quiet /norestart" -Wait
    Start-Process msiexec.exe -ArgumentList "/i $avdPath\RDAgentBootLoader.msi /quiet /norestart" -Wait
    "[$(Get-Date)] Agent en bootloader geïnstalleerd." | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij downloaden/installeren van tooling: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== CONTROLEER OF DE AGENT BESTAAT ===
if (-not (Test-Path $agentExe)) {
    "[$(Get-Date)] AVD-agent niet gevonden. Alternatieve installatie via aka.ms wordt gestart..." | Out-File -FilePath $logPath -Append

    try {
        $fallbackInstaller = "$avdPath\AVDAgentFallback.msi"
        Invoke-WebRequest -Uri "https://aka.ms/avdagent" -OutFile $fallbackInstaller -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i $fallbackInstaller /quiet /norestart" -Wait
        "[$(Get-Date)] Alternatieve installatie voltooid." | Out-File -FilePath $logPath -Append
    } catch {
        "[$(Get-Date)] Fout bij alternatieve installatie: $_" | Out-File -FilePath $logPath -Append
        exit 1
    }
}

#=== REGISTRATIE BIJ HOSTPOOL ===
if (Test-Path $agentExe) {
    try {
        & "$agentExe" /register:$registrationToken
        "[$(Get-Date)] Registratie bij hostpool succesvol uitgevoerd." | Out-File -FilePath $logPath -Append
    } catch {
        "[$(Get-Date)] Fout bij registratie: $_" | Out-File -FilePath $logPath -Append
        exit 1
    }
} else {
    "[$(Get-Date)] Fout: AVD-agent executable nog steeds niet gevonden." | Out-File -FilePath $logPath -Append
    exit 1
}
