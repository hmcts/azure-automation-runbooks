param
(
    [Parameter (Mandatory = $false)]
    [object] $webhookData
)

$subscriptionName = "DCD-CNP-DEV"

function Get-TriggerBuild {

    # Azure DevOps token
    $token = Get-AzKeyVaultSecret -AsPlainText -vaultName "cftptl-intsvc" -name "azure-devops-token" 
    
    # Authentication - username:token. The username can be anything, the token is a Personal Access Token in an Azure DevOps account
    $plainTextCreds = "hmcts@hmcts.net:$token"

    # Azure DevOps Endpoint.  This includes the org and project name of the build we're triggering
    $build_definition = 449
    $azureDevOpsEndpoint = "https://dev.azure.com/hmcts/PlatformOperations/_apis/pipelines/$build_definition/runs?api-version=6.0-preview.1"

    # HTTP request body
    $Body = @"
{
	"stagesToSkip": [],
	"templateParameters": {
		"email_account": "$upn"
	}
}
"@

    #Prepare credentials
    $AuthBytes  = [System.Text.Encoding]::Ascii.GetBytes($plainTextCreds)
    $base64AuthInfo = [Convert]::ToBase64String($AuthBytes)

    $Result = Invoke-RestMethod -Uri $azureDevOpsEndpoint -Method Post -ContentType "application/json" -Body $body -Headers @{"Authorization"="Basic $base64AuthInfo"} 
    Write-Output $Result
}


if ($webhookData) {

    # Get the UPN from the webhook payload
    $requestBody = (ConvertFrom-Json -InputObject $webhookData.RequestBody)
    $upn = $requestBody.data.alertContext.SearchResults.tables.rows[0]


    #Authenticate as "Run-As Account" using certificate
    $connection = Get-AutomationConnection -Name AzureRunAsConnection
    Connect-AzAccount -ServicePrincipal -Tenant $connection.TenantID -ApplicationId $connection.ApplicationID -CertificateThumbprint $connection.CertificateThumbprint
    
    # Trigger the build
    Get-TriggerBuild

}

