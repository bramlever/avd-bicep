param (
    [Parameter(Mandatory = $true)]
    [string]$registrationToken
)

# Pad naar de AVD-agent
$agentPath = "C:\Program Files\Microsoft RDInfra\RDInfraAgent.exe"

# Controleren of de agent bestaat
if (-not (Test-Path $agentPath)) {
    Write-Error "AVD Agent is niet geïnstalleerd op deze machine."
    exit 1
}

# Registratie uitvoeren
try {
    & $agentPath /register:$registrationToken
    Write-Output "Registratie bij hostpool succesvol uitgevoerd."
} catch {
    Write-Error "Registratie mislukt: $_"
    exit 1
}
