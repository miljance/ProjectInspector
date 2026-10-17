<#
.SYNOPSIS
Puts the six demo projects back to the state of the RapidStart packages.

.DESCRIPTION
Reviews and answers change the demo projects (Project Inspector applies the salesperson's answers), so run this
before an evaluation (Run-ReviewEval.ps1) or a recording:
1. Deletes the six demo projects; the base application deletes their tasks and planning lines.
2. Imports and applies the packages SCRIBE-DEMO, SCRIBE-PRJ-HEADERS and SCRIBE-PRJ-LINES, in that order, through the
   configurationPackages API.
3. Sets Unit Price and Line Discount % again on every planning line of SCRIBE-PRJ-LINES. RapidStart writes them before
   Business Central takes the price from the resource card, so the card price wins (TAI-01-IMP would show 22,200 and
   no discount instead of 20,025 with a discount of 375).
The standard CRONUS projects are not touched. Uses the OCPF APIs v3 for projects and planning lines.
Needs the Azure CLI signed in to the tenant (az account get-access-token).

.EXAMPLE
./tools/Reset-DemoData.ps1 -Tenant <tenant id> -PackageFolder <folder with the .rapidstart files>

.EXAMPLE
./tools/Reset-DemoData.ps1 -Tenant <tenant id> -PackageFolder <folder> -FixLinesOnly
#>
param(
    [Parameter(Mandatory)] [string] $Tenant,
    [Parameter(Mandatory)] [string] $PackageFolder,
    [string] $Environment = 'bc29',
    [string] $Company = 'OneVoiceNote',
    [switch] $DeleteOnly,
    [switch] $FixLinesOnly
)
$ErrorActionPreference = 'Stop'
$projects = 'FAB-01-IMP', 'TAI-01-IMP', 'PRO-01-WSH', 'LIT-01-SUP', 'WWI-01-IMP', 'WWI-02-IMP'
$packages = 'SCRIBE-DEMO', 'SCRIBE-PRJ-HEADERS', 'SCRIBE-PRJ-LINES'

# Not "H": in PowerShell the alias h (Get-History) wins over a function with that name.
function Get-AuthHeader {
    @{ Authorization = "Bearer $(az account get-access-token --resource https://api.businesscentral.dynamics.com --tenant $Tenant --query accessToken -o tsv)" }
}
$api = "https://api.businesscentral.dynamics.com/v2.0/$Tenant/$Environment/api"
$companyId = ((Invoke-RestMethod "$api/v2.0/companies" -Headers (Get-AuthHeader)).value | Where-Object name -eq $Company).id
if (-not $companyId) { throw "Company $Company not found." }
$ocpf = "$api/OnlyCopilotFans/ocpf_projectsAndAssets/v3.1/companies($companyId)"
$auto = "$api/microsoft/automation/v2.0/companies($companyId)/configurationPackages"
$anyVersion = @{ 'If-Match' = '*' }

if (-not $FixLinesOnly) {
    # 1. Delete the demo projects
    foreach ($no in $projects) {
        $project = (Invoke-RestMethod "$ocpf/ocpfProjects?`$filter=no eq '$no'&`$select=systemId,no" -Headers (Get-AuthHeader)).value
        if (-not $project) { Write-Host "$no not found"; continue }
        Invoke-RestMethod "$ocpf/ocpfProjects($($project.systemId))" -Method Delete -Headers ((Get-AuthHeader) + $anyVersion) | Out-Null
        Write-Host "$no deleted"
    }
    if ($DeleteOnly) { return }

    # 2. Import and apply the packages in order
    foreach ($code in $packages) {
        $existing = (Invoke-RestMethod "$auto`?`$filter=code eq '$code'" -Headers (Get-AuthHeader)).value
        if ($existing) { Invoke-RestMethod "$auto($($existing.id))" -Method Delete -Headers ((Get-AuthHeader) + $anyVersion) | Out-Null }
        $package = Invoke-RestMethod $auto -Method Post -Headers (Get-AuthHeader) -ContentType 'application/json' -Body (@{ code = $code; packageName = $code } | ConvertTo-Json)
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $PackageFolder "$code.rapidstart"))
        Invoke-RestMethod "$auto($($package.id))/file('$code')/content" -Method Patch -Headers ((Get-AuthHeader) + $anyVersion) -ContentType 'application/octet-stream' -Body $bytes | Out-Null

        Invoke-RestMethod "$auto($($package.id))/Microsoft.NAV.import" -Method Post -Headers (Get-AuthHeader) | Out-Null
        do { Start-Sleep -Seconds 5; $state = Invoke-RestMethod "$auto($($package.id))" -Headers (Get-AuthHeader) } while ($state.importStatus -in 'InProgress', 'Scheduled')
        Write-Host "$code import: $($state.importStatus) ($($state.numberOfRecords) records)"
        if ($state.importStatus -ne 'Completed') { throw "$code import failed: $($state.importError)" }

        Invoke-RestMethod "$auto($($package.id))/Microsoft.NAV.apply" -Method Post -Headers (Get-AuthHeader) | Out-Null
        do { Start-Sleep -Seconds 5; $state = Invoke-RestMethod "$auto($($package.id))" -Headers (Get-AuthHeader) } while ($state.applyStatus -in 'InProgress', 'Scheduled')
        Write-Host "$code apply: $($state.applyStatus), errors: $($state.numberOfErrors)"
        if ($state.applyStatus -ne 'Completed') { throw "$code apply failed: $($state.applyError)" }
    }
}

# 3. Unit Price and Line Discount % as in the package
Add-Type -AssemblyName System.IO.Compression
$gzip = [System.IO.Compression.GZipStream]::new([System.IO.File]::OpenRead((Join-Path $PackageFolder 'SCRIBE-PRJ-LINES.rapidstart')), [System.IO.Compression.CompressionMode]::Decompress)
$reader = [System.IO.StreamReader]::new($gzip, [System.Text.Encoding]::Unicode)
[xml]$xml = $reader.ReadToEnd()
$reader.Close()

# Package fields with attributes come back as XML elements, the others as text.
function Get-Value($node) { if ($node -is [System.Xml.XmlElement]) { $node.InnerText } else { [string]$node } }

foreach ($row in $xml.DataList.JobPlanningLineList.JobPlanningLine) {
    $jobNo = Get-Value $row.JobNo; $jobTaskNo = Get-Value $row.JobTaskNo; $lineNo = [int](Get-Value $row.LineNo)
    $price = [decimal](Get-Value $row.UnitPrice); $discount = [decimal](Get-Value $row.LineDiscount)
    $line = (Invoke-RestMethod "$ocpf/ocpfProjectPlanningLines?`$filter=jobNo eq '$jobNo' and jobTaskNo eq '$jobTaskNo'" -Headers (Get-AuthHeader)).value |
        Where-Object { $_.lineNo -eq $lineNo }
    if (-not $line) { Write-Host "missing line $jobNo $jobTaskNo $lineNo"; continue }
    $expected = [math]::Round($line.quantity * $price * (100 - $discount) / 100, 2)
    if ($line.unitPrice -eq $price -and $line.lineDiscountPct -eq $discount -and $line.lineAmount -eq $expected) { continue }

    $url = "$ocpf/ocpfProjectPlanningLines($($line.systemId))"
    Invoke-RestMethod $url -Method Patch -Headers ((Get-AuthHeader) + $anyVersion) -ContentType 'application/json' -Body (@{ unitPrice = $price } | ConvertTo-Json) | Out-Null
    Invoke-RestMethod $url -Method Patch -Headers ((Get-AuthHeader) + $anyVersion) -ContentType 'application/json' -Body (@{ lineDiscountPct = $discount } | ConvertTo-Json) | Out-Null
    $line = Invoke-RestMethod $url -Headers (Get-AuthHeader)
    if ($line.lineAmount -ne $expected) {
        # The same Unit Price again does not recalculate the line; set the Line Amount the package means.
        Invoke-RestMethod $url -Method Patch -Headers ((Get-AuthHeader) + $anyVersion) -ContentType 'application/json' -Body (@{ lineAmount = $expected } | ConvertTo-Json) | Out-Null
        $line = Invoke-RestMethod $url -Headers (Get-AuthHeader)
    }
    Write-Host "$jobNo $jobTaskNo $lineNo`: price $($line.unitPrice), discount $($line.lineDiscountPct)%, line amount $($line.lineAmount)"
}
