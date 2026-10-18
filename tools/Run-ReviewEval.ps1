<#
.SYNOPSIS
Runs Project Inspector on the six demo projects and checks each report against the expected results.

.DESCRIPTION
Restarts the review of every demo project through the reviewReports API (the old task is stopped, a new one
starts with the current instructions), waits for the agent's reports and compares facts, not wording:
status, total, days, and for every finding and question its rule ID and task or number.
It also checks that every line of the project's Open Points field is asked in the first report (PCR-24),
except the lines checks 6b and 6c already ask ("Quote numbers", "Services").
Each run uses Copilot credits. The reports wait for the reviewer's decision on the Review Result card, so no
question goes to Teams.
Needs the Azure CLI signed in to the tenant (az account get-access-token).

.EXAMPLE
./tools/Run-ReviewEval.ps1 -Tenant <tenant id> -Environment bc29 -Company OneVoiceNote
#>
param(
    [Parameter(Mandatory)] [string] $Tenant,
    [string] $Environment = 'bc29',
    [string] $Company = 'OneVoiceNote',
    [string[]] $Projects = @('FAB-01-IMP', 'TAI-01-IMP', 'PRO-01-WSH', 'LIT-01-SUP', 'WWI-01-IMP', 'WWI-02-IMP'),
    [int] $TimeoutMinutes = 20
)
$ErrorActionPreference = 'Stop'
# pwsh -File passes a comma-separated list as one string
$Projects = @($Projects | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# Expected results (README, "Expected review results"). Each pattern must match exactly one line of its section.
$Expected = @{
    'FAB-01-IMP' = @{ Status = 'OPEN POINTS'; Total = '75,250'; Days = '44'; Findings = @()
        Questions = @('002000.*PCR-12', '003000.*PCR-12', '004000.*PCR-12', '005000.*PCR-12',
            'App users.*PCR-24', 'Travel.*PCR-24', 'Go-live.*PCR-24', 'Discount.*PCR-24') }
    'TAI-01-IMP' = @{ Status = 'ERRORS'; Total = '20,025'; Days = '15'
        Findings = @('1,100.*1,250.*PCR-14', '375.*PCR-16'); Questions = @('003000.*PCR-12') }
    'PRO-01-WSH' = @{ Status = 'ERRORS'; Total = '3,150'; Days = '2'
        Findings = @('Standard block.*PCR-10'); Questions = @('001010.*PCR-22') }
    'LIT-01-SUP' = @{ Status = 'ERRORS'; Total = '8,400'; Days = '0'
        Findings = @('C90040.*PCR-07'); Questions = @('PCR-20', '60 hours.*PCR-23') }
    'WWI-01-IMP' = @{ Status = 'ERRORS'; Total = '19,500'; Days = '10'
        Findings = @('WWI-02-IMP.*PCR-03'); Questions = @('50 hours.*PCR-23') }
    'WWI-02-IMP' = @{ Status = 'ERRORS'; Total = '12,500'; Days = '10'
        Findings = @('WWI-01-IMP.*PCR-03'); Questions = @('002000.*PCR-12', '10 days.*002010.*PCR-23') }
}

function Get-Token {
    az account get-access-token --resource https://api.businesscentral.dynamics.com --tenant $Tenant --query accessToken -o tsv
}
$root = "https://api.businesscentral.dynamics.com/v2.0/$Tenant/$Environment/api"
$companyId = ((Invoke-RestMethod "$root/v2.0/companies" -Headers @{ Authorization = "Bearer $(Get-Token)" }).value |
    Where-Object name -eq $Company).id
if (-not $companyId) { throw "Company $Company not found." }
$base = "$root/contoso/projectInspector/v1.0/companies($companyId)/reviewReports"

function Get-Reports {
    (Invoke-RestMethod "$base`?`$filter=status eq 'Planning'" -Headers @{ Authorization = "Bearer $(Get-Token)" }).value
}

function Get-OpenPoints {
    $url = "$root/contoso/projectInspector/v1.0/companies($companyId)/projectReviews?`$select=number,openPoints"
    $map = @{}
    (Invoke-RestMethod $url -Headers @{ Authorization = "Bearer $(Get-Token)" }).value | ForEach-Object { $map[$_.number] = $_.openPoints }
    $map
}

# Open Points lines that checks 6b and 6c ask in their own words
$CoveredTopics = '^(Quote numbers|Services)\s*:'

function Test-OpenPoints([string] $OpenPoints, [string[]] $Questions) {
    $problems = @()
    foreach ($point in ($OpenPoints -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        if ($point -match $CoveredTopics) { continue }
        $topic = ($point -split ':', 2)[0].Trim()
        if (-not ($Questions | Where-Object { $_.Contains($topic) -and $_ -match 'PCR-24' })) { $problems += "open point not asked: '$point'" }
    }
    $problems
}

function ConvertTo-Lines([string] $Report) {
    $plain = $Report -replace '(?i)<br\s*/?>|</p\s*>', "`n" -replace '<[^>]+>', ''
    $plain = $plain.Replace('&nbsp;', ' ').Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"').Replace('&#39;', "'").Replace('&amp;', '&')
    $plain -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

function Test-Report([string] $ProjectNo, [string] $Report) {
    $exp = $Expected[$ProjectNo]; $problems = @()
    $lines = @(ConvertTo-Lines $Report)
    if ($lines.Count -lt 2) { return @("no report") }
    if ($lines[0] -notmatch "review:\s*(.+)$" -or $Matches[1].Trim() -ne $exp.Status) { $problems += "status: '$($lines[0])'" }
    if ($lines[1] -notmatch "Total:\s*([\d,]+)\s*\|\s*Days:\s*([\d,]+)") { $problems += "totals line: '$($lines[1])'" }
    else {
        if ($Matches[1] -ne $exp.Total) { $problems += "total $($Matches[1]) instead of $($exp.Total)" }
        if ($Matches[2] -ne $exp.Days) { $problems += "days $($Matches[2]) instead of $($exp.Days)" }
    }
    $section = ''; $found = @{ Findings = @(); Questions = @() }
    foreach ($line in $lines) {
        if ($line -eq 'Findings:') { $section = 'Findings'; continue }
        if ($line -eq 'Questions for the salesperson:') { $section = 'Questions'; continue }
        if ($line.StartsWith('- ') -and $section) { $found[$section] += $line.Substring(2) } elseif (-not $line.StartsWith('- ')) { $section = '' }
    }
    foreach ($kind in 'Findings', 'Questions') {
        $remaining = [System.Collections.ArrayList]@($found[$kind])
        foreach ($pattern in $exp[$kind]) {
            $hit = $remaining | Where-Object { $_ -match $pattern } | Select-Object -First 1
            if ($hit) { $remaining.Remove($hit) } else { $problems += "missing $($kind.TrimEnd('s').ToLower()): /$pattern/" }
        }
        foreach ($extra in $remaining) { $problems += "extra $($kind.TrimEnd('s').ToLower()): '$extra'" }
    }
    $problems += @(Test-OpenPoints $OpenPointsByProject[$ProjectNo] $found.Questions)
    $problems
}

# 1. Restart every review (Open Points are read first: the agent changes them only when it applies answers)
$OpenPointsByProject = Get-OpenPoints
$started = [DateTime]::UtcNow
$reports = Get-Reports
foreach ($projectNo in $Projects) {
    $project = $reports | Where-Object number -eq $projectNo
    if (-not $project) { throw "$projectNo is not in status Planning in $Company." }
    Invoke-RestMethod "$base($($project.id))/Microsoft.NAV.restartReview" -Method Post -Headers @{ Authorization = "Bearer $(Get-Token)" } | Out-Null
    Write-Host "$projectNo restarted"
}

# 2. Wait for a report written after the restart
$deadline = $started.AddMinutes($TimeoutMinutes)
do {
    Start-Sleep -Seconds 30
    $reports = Get-Reports | Where-Object { $Projects -contains $_.number }
    $done = @($reports | Where-Object { $_.report -and ([DateTime]$_.reportCreatedAt).ToUniversalTime() -gt $started })
    Write-Host ("{0:HH:mm:ss} {1}/{2} reports" -f (Get-Date), $done.Count, $Projects.Count)
} until ($done.Count -eq $Projects.Count -or [DateTime]::UtcNow -gt $deadline)

# 3. Compare
$passed = 0
$credits = 0
foreach ($projectNo in $Projects) {
    $r = $reports | Where-Object number -eq $projectNo
    $credits += [decimal]$r.copilotCredits
    $fresh = $r.report -and ([DateTime]$r.reportCreatedAt).ToUniversalTime() -gt $started
    $problems = if ($fresh) { @(Test-Report $projectNo $r.report) } else { @("no new report (task $($r.taskId), $($r.taskStatus))") }
    if ($problems.Count -eq 0) { $passed++; Write-Host "PASS $projectNo (task $($r.taskId), $($r.copilotCredits) credits)" -ForegroundColor Green }
    else { Write-Host "FAIL $projectNo (task $($r.taskId), $($r.copilotCredits) credits)" -ForegroundColor Red; $problems | ForEach-Object { Write-Host "     - $_" } }
    if ($fresh) { (ConvertTo-Lines $r.report) | ForEach-Object { Write-Host "       | $_" -ForegroundColor DarkGray } }
}
Write-Host "$passed of $($Projects.Count) projects as expected, $credits Copilot credits"
