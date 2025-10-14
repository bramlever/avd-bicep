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
Start-Sleep -Seconds 30
"[$(Get-Date)] Wachtperiode voltooid" | Out-File -FilePath $logPath -Append

#=== DOWNLOAD EN INSTALLATIE VAN AVD TOOLING ===
try {
    $agentUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/AVDAgent.msi"
    $bootloaderUrl = "https://raw.githubusercontent.com/bramlever/avd-bicep/main/RDAgentBootLoader.msi"
    $agentDest = "$avdPath\AVDAgent.msi"
    $bootloaderDest = "$avdPath\RDAgentBootLoader.msi"

    Invoke-WebRequest -Uri $agentUrl -OutFile $agentDest -UseBasicParsing
    Invoke-WebRequest -Uri $bootloaderUrl -OutFile $bootloaderDest -UseBasicParsing

    $agentSize = (Get-Item $agentDest).Length
    "[$(Get-Date)] Bestandsgrootte van AVDAgent.msi: $agentSize bytes" | Out-File -FilePath $logPath -Append

    if ($agentSize -lt 1000000) {
        "[$(Get-Date)] Download via Invoke-WebRequest lijkt corrupt. Probeer alternatieve methode..." | Out-File -FilePath $logPath -Append
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($agentUrl, $agentDest)
        $agentSize = (Get-Item $agentDest).Length
        "[$(Get-Date)] Alternatieve download voltooid. Nieuwe bestandsgrootte: $agentSize bytes" | Out-File -FilePath $logPath -Append
    }

    Start-Process msiexec.exe -ArgumentList "/i $agentDest /quiet /norestart" -Wait
    Start-Process msiexec.exe -ArgumentList "/i $bootloaderDest /quiet /norestart" -Wait
    "[$(Get-Date)] Agent en bootloader geïnstalleerd." | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij downloaden/installeren van tooling: $_" | Out-File -FilePath $logPath -Append
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