param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$IdentityName,

    [Parameter(Mandatory = $true)]
    [string]$CredentialName,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedIssuer,

    [Parameter(Mandatory = $true)]
    [string]$ExpectedSubject,

    [string[]]$ExpectedAudiences = @('api://AzureADTokenExchange')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required to validate federated identity credentials.'
}

$credential = az identity federated-credential show `
    --resource-group $ResourceGroupName `
    --identity-name $IdentityName `
    --name $CredentialName `
    --output json | ConvertFrom-Json

$errors = @()

if ($credential.issuer -ne $ExpectedIssuer) {
    $errors += "Issuer mismatch. Expected '$ExpectedIssuer' but found '$($credential.issuer)'."
}

if ($credential.subject -ne $ExpectedSubject) {
    $errors += "Subject mismatch. Expected '$ExpectedSubject' but found '$($credential.subject)'."
}

$actualAudiences = @($credential.audiences)
$missingAudiences = @($ExpectedAudiences | Where-Object { $_ -notin $actualAudiences })

if ($missingAudiences.Count -gt 0) {
    $errors += "Missing expected audiences: $($missingAudiences -join ', ')."
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "✅ Federated credential '$CredentialName' on identity '$IdentityName' matches the expected issuer, subject, and audiences."
