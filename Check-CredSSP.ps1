# Import the ActiveDirectory module
Import-Module ActiveDirectory

# Get list of servers from AD (adjust the filter as needed)
$servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -Properties OperatingSystem | Select-Object -ExpandProperty Name

if (!$servers) {
    Write-Error "No servers found in Active Directory."
    exit
}

# Run the check on each server
$results = Invoke-Command -ComputerName $servers -ScriptBlock {
    # Get OS info and computer name
    $os = Get-CimInstance Win32_OperatingSystem
    $osCaption = $os.Caption
    $computerName = $env:COMPUTERNAME

    # Set baseline version based on OS caption.
    if ($osCaption -like "*2019*") {
        $baseline = [version]"10.0.17134.48"
    } elseif ($osCaption -like "*2016*") {
        $baseline = [version]"10.0.14393.2125"
    } elseif ($osCaption -like "*2012 R2*") {
        $baseline = [version]"6.3.9600.18980"
    } elseif ($osCaption -like "*2012*") {
        $baseline = $null  # Baseline not defined for non-R2 Server 2012
    } else {
        $baseline = $null
    }

    # Path to TSpkg.dll and extract its numeric version part
    $filePath = "$env:SystemRoot\System32\TSpkg.dll"
    if (Test-Path $filePath) {
        $fileVersionFull = (Get-Item $filePath).VersionInfo.FileVersion
        $versionPart = $fileVersionFull.Split(" ")[0]
        $tspkgVersion = [version]$versionPart
    }
    else {
        $tspkgVersion = $null
    }

    # Determine update status
    if ($baseline -and $tspkgVersion) {
        if ($tspkgVersion -ge $baseline) {
            $status = "Update Installed"
        }
        else {
            $status = "Update Not Installed"
        }
    }
    else {
        $status = "Unknown (Baseline or file version missing)"
    }

    # Output the result as a custom object
    [PSCustomObject]@{
        ComputerName = $computerName
        OS           = $osCaption
        TSpkgVersion = if ($tspkgVersion) { $tspkgVersion.ToString() } else { "Not Found" }
        Baseline     = if ($baseline)     { $baseline.ToString() } else { "Unknown" }
        UpdateStatus = $status
    }
} -ErrorAction SilentlyContinue

# Export results to a CSV file
$results | Export-Csv -Path "CredSSP_Update_Check.csv" -NoTypeInformation
Write-Output "Results exported to CredSSP_Update_Check.csv"
