##final script

param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken
)

New-Item -ItemType Directory -Path "C:\AVD" -Force | Out-Null

# Download agent en bootloader
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bramlever/avd-bicep/main/AVDAgent.msi" -OutFile "C:\AVD\AVDAgent.msi"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bramlever/avd-bicep/main/RDAgentBootLoader.msi" -OutFile "C:\AVD\AVDBootLoader.msi"

# Installeer silent
Start-Process msiexec.exe -ArgumentList "/i C:\AVD\AVDAgent.msi /quiet /norestart" -Wait
Start-Process msiexec.exe -ArgumentList "/i C:\AVD\AVDBootLoader.msi /quiet /norestart" -Wait

# Controleer of agent nu aanwezig is
$agentExe = "C:\Program Files\Microsoft RDInfra\RDInfraAgent\RDInfraAgent.exe"
if (Test-Path $agentExe) {
    & "$agentExe" /register:$registrationToken
    "[$(Get-Date)] Registratie geslaagd" | Out-File -FilePath $logPath -Append
} else {
    "[$(Get-Date)] Fout: Agent nog steeds niet gevonden" | Out-File -FilePath $logPath -Append
}


$agentPath = "C:\Program Files\Microsoft RDInfra\RDInfraAgent.exe"
if (-not (Test-Path $agentPath)) {
    Write-Output "AVD-agent niet gevonden. Installatie wordt gestart..."
    Invoke-WebRequest -Uri "https://aka.ms/avdagent" -OutFile "C:\AVD\AVDAgent.msi" -UseBasicParsing
    Start-Process msiexec.exe -ArgumentList "/i C:\AVD\AVDAgent.msi /quiet /norestart" -Wait
}

# Logging pad
$logPath = "C:\AVD\register.log"
New-Item -ItemType Directory -Path "C:\AVD" -Force | Out-Null

# Start logging
"[$(Get-Date)] Script gestart" | Out-File -FilePath $logPath -Append
"[$(Get-Date)] Token ontvangen: $registrationToken" | Out-File -FilePath $logPath -Append

# Wacht even zodat services kunnen opstarten
Start-Sleep -Seconds 30
"[$(Get-Date)] Wachtperiode voltooid" | Out-File -FilePath $logPath -Append

# Pad naar AVD-agent
$agentPath = "C:\Program Files\Microsoft RDInfra\RDInfraAgent.exe"

# Controleer of agent bestaat
if (-not (Test-Path $agentPath)) {
    "[$(Get-Date)] AVD-agent niet gevonden. Installatie wordt gestart..." | Out-File -FilePath $logPath -Append

    try {
        $installer = "C:\AVD\AVDAgent.msi"
        Invoke-WebRequest -Uri "https://aka.ms/avdagent" -OutFile $installer -UseBasicParsing
        Start-Process msiexec.exe -ArgumentList "/i $installer /quiet /norestart" -Wait
        "[$(Get-Date)] AVD-agent installatie voltooid." | Out-File -FilePath $logPath -Append
    } catch {
        "[$(Get-Date)] Fout bij installatie van AVD-agent: $_" | Out-File -FilePath $logPath -Append
        exit 1
    }
} else {
    "[$(Get-Date)] AVD-agent is al geïnstalleerd." | Out-File -FilePath $logPath -Append
}

# Probeer registratie
try {
    & $agentPath /register:$registrationToken
    "[$(Get-Date)] Registratie bij hostpool succesvol uitgevoerd." | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij registratie: $_" | Out-File -FilePath $logPath -Append
    exit 1
}
