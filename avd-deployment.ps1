#=== PARAMETERS ===
param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken
)

#=== PADEN DEFINIËREN ===
$avdPath = "C:\AVD"
$logPath = "$avdPath\register.log"
$tokenPath = "$avdPath\registrationToken.txt"
$tokenFallbackPath = "C:\Program Files\Microsoft RDInfra\registrationToken.txt"
$installScriptPath = "$avdPath\InstallAVDAgent.ps1"

#=== VOORBEREIDING ===
New-Item -ItemType Directory -Path $avdPath -Force | Out-Null
"[$(Get-Date)] Script gestart" | Out-File -FilePath $logPath -Append
"[$(Get-Date)] Token ontvangen: $registrationToken" | Out-File -FilePath $logPath -Append

Set-Content -Path $tokenPath -Value $registrationToken
"[$(Get-Date)] Token opgeslagen in $tokenPath" | Out-File -FilePath $logPath -Append

try {
    Copy-Item -Path $tokenPath -Destination $tokenFallbackPath -Force
    "[$(Get-Date)] Token ook geplaatst in $tokenFallbackPath" | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij kopiëren van token naar fallback-pad: $_" | Out-File -FilePath $logPath -Append
}

#=== WACHTPERIODE VOOR SERVICES ===
Start-Sleep -Seconds 30
"[$(Get-Date)] Wachtperiode voltooid" | Out-File -FilePath $logPath -Append

#=== DOWNLOAD EN INSTALLATIE VAN AVD TOOLING VIA MICROSOFT SCRIPT ===
try {
    $installScriptUrl = "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
    Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath -UseBasicParsing
    "[$(Get-Date)] Installatiescript gedownload naar $installScriptPath" | Out-File -FilePath $logPath -Append

    powershell -ExecutionPolicy Unrestricted -File $installScriptPath
    "[$(Get-Date)] Installatiescript uitgevoerd." | Out-File -FilePath $logPath -Append
} catch {
    "[$(Get-Date)] Fout bij downloaden of uitvoeren van installatiescript: $_" | Out-File -FilePath $logPath -Append
    exit 1
}

#=== CONTROLE NA INSTALLATIE ===
$agentFolder = "C:\Program Files\Microsoft RDInfra"
if (Test-Path $agentFolder) {
    "[$(Get-Date)] RDInfra-agentmap gevonden: $agentFolder" | Out-File -FilePath $logPath -Append
    Get-ChildItem $agentFolder -Recurse | Out-File -FilePath $logPath -Append
} else {
    "[$(Get-Date)] RDInfra-agentmap niet gevonden. Installatie lijkt mislukt." | Out-File -FilePath $logPath -Append
}
