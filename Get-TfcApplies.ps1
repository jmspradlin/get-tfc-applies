<#
.Synopsis
Gathers the applies for a Terraform Cloud organization

.Description
List the applies for an organization, organized based on Workspace, Project and within time scope. Uses Terraform Cloud API to access Project, Workspace and Successful Applies for the org.

.PARAMETER tfcOrganization
The name of the Terraform Cloud organization

.PARAMETER tfcToken
The Organization Token for the Terraform Cloud organization. More information can be found at: https://developer.hashicorp.com/terraform/cloud-docs/api-docs/organization-tokens

.PARAMETER start
The start datetime of applies counted. Defaults to the first day of the month

.PARAMETER end
The end datetime of applies counted. Defaults to the last day of the month

.PARAMETER file
Path to output to .csv

.EXAMPLE
Get applied runs less than 6 months ago.
Get-TfcApplies -tfcOrganization 'my-org' -tfcToken $token -start (Get-Date).AddMonths(-6)

.EXAMPLE
Get applied runs greater than 1 month ago but less than 6 months ago.
Get-TfcApplies -tfcOrganization 'my-org' -tfcToken $token -start (Get-Date).AddMonths(-6) -end (Get-Date).AddMonths(-1)

.EXAMPLE
Export results to .csv file
Get-TfcApplies -tfcOrganization 'my-org' -tfcToken $token -file '.\runs.csv'

.EXAMPLE
Use previously saved token
$token = "kjfenkfjnef..."
Get-TfcApplies -tfcOrganization 'my-org' -tfcToken $token -file '.\runs.csv'

#>
function Get-TfcApplies {
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string[]] $tfcOrganization,
    [string[]] $tfcToken,
    [Parameter(Mandatory=$false)][DateTime] $start = (Get-Date -Day 1),
    [Parameter(Mandatory=$false)][DateTime] $end = (Get-Date),
    [Parameter(Mandatory=$false)]$file = $null
)
#Add Organization token headers for API calls
$orgHeaders = @{
    Authorization = "Bearer $tfcToken"
}
$orgToken = $null
# Workspace API list
Write-Host -ForegroundColor Yellow "Selecting all runs between $($start) and $($end) for $($tfcOrganization) organization"

$workspaces = (Invoke-RestMethod -Uri "https://app.terraform.io/api/v2/organizations/$($tfcOrganization)/workspaces" -Method Get -ContentType "application/vnd.api+json" -Headers $orgHeaders).data

# Create empty array for collected list of workspaces, projects and runs
$workspaceList = @()

# Collect all relevant workspace, project and run information
foreach ($w in $workspaces){
    # Get Run information based on workspace
    $runs = Invoke-RestMethod -Uri "https://app.terraform.io/api/v2/workspaces/$($w.id)/runs" -Method Get -ContentType "application/vnd.api+json" -Headers $orgHeaders
    # Get Project name based on workspace
    $projectName = Invoke-RestMethod -Uri "https://app.terraform.io/api/v2/projects/$($w.relationships.project.data.id)" -Method Get -ContentType "application/vnd.api+json" -Headers $orgHeaders

    # Select only successfully Applied workspace runs
    $totals = $runs.data | where {$_.attributes.status -eq "applied"}
    Write-Host -ForegroundColor DarkYellow "Writing properties for workspace" $w.attributes.name
    # Collate for each successful total
    foreach ($t in $totals){
        $wl = New-Object psobject
            $wl | Add-Member -type NoteProperty -name 'WorkspaceName' -Value $w.attributes.name
            $wl | Add-Member -type NoteProperty -Name 'WorkspaceId' -Value $w.id
            $wl | Add-Member -type NoteProperty -Name 'ProjectName' -Value $projectName.data.attributes.name
            $wl | Add-Member -type NoteProperty -Name 'ProjectId' -Value $w.relationships.project.data.id
            $wl | Add-Member -type NoteProperty -Name 'RunId' -Value $t.id
            $wl | Add-Member -type NoteProperty -Name 'RunStatus' -Value $t.attributes.status
            $wl | Add-Member -type NoteProperty -Name 'AppliedAt' -Value $t.attributes.'status-timestamps'.'applied-at'
            $workspaceList += $wl
    }
}

$startDate = $start.ToString("yyyy-MM-ddT00:00:00+00:00")
$endDate = $end.ToString("yyyy-MM-ddThh:mm:ss-05:00")
# Sort and organize
$appliedScope = $workspaceList | where {($_.AppliedAt -gt "$($startDate)") -and ($_.AppliedAt -lt "$($endDate)")}
$workspaceCount = $appliedScope.count
$appliedScope | Group-Object WorkspaceId | select Count,@{L="Percent";e={([math]::Round($_.count / $($workspaceCount),4) * 100)}}, @{L="WorkspaceName";e={$_.Group.WorkspaceName[0]}},@{L="ProjectName";e={$_.Group.ProjectName[0]}},@{L="WorkspaceID";e={$_.Group.WorkspaceId[0]}},@{L="ProjectId";e={$_.Group.Projectid[0]}} | sort ProjectName | Format-Table
if ($file -ne $null){
    $appliedScope | Group-Object WorkspaceId | select Count,@{L="Percent";e={([math]::Round($_.count / $($workspaceCount),4) * 100)}}, @{L="WorkspaceName";e={$_.Group.WorkspaceName[0]}},@{L="ProjectName";e={$_.Group.ProjectName[0]}},@{L="WorkspaceID";e={$_.Group.WorkspaceId[0]}},@{L="ProjectId";e={$_.Group.Projectid[0]}} | sort ProjectName | Export-Csv -Path $file -NoTypeInformation
}
}