<#
.Synopsis
   metricBEAT agent deployment 
.DESCRIPTION
   Queries AD for Windows Servers that do not have the metricBEAT service
   Make sure to configure the 'metricbeat.yml' file before deployment
.EXAMPLE
   deploy-metricBEAT -installerPATH '\\fileserver\share\metricbeat'
#>
function deploy-metricBEAT
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Path to metricBEAT files
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$installerPath
    )

    Begin
    {
    $winservers = [System.Collections.Generic.List[Microsoft.ActiveDirectory.Management.ADComputer]]::new();
    (Get-ADComputer -Filter 'OperatingSystem -like "Windows Server*"' -Properties Description,serviceprincipalname).Where({`
        $_.enabled -and ($_.serviceprincipalname[0] -notlike "MSServerCluster*") -and $_.description -notlike "Failover*"}).foreach({write-verbose "$($_.dnshostname)";$winservers.add($_)})
    $onlineNeedInstall = (($winservers).where({(Test-NetConnection -ComputerName $_.dnshostname) -and -not (Get-Service -Name 'metricbeat' -ComputerName $_.dnsHostname)}))
    }
    Process
    {
    $installedMetricBEAT = @();
    $onlineNeedInstall.ForEach({$computername = $_.name;
        Write-Verbose "Starting install on $($_.dnshostname)";
        $sesh = New-PSSession -ComputerName $computername;
        copy-item -Path $installerPath -Recurse -Destination "\\$($computername)\c$\Program Files\" -Force;
        Invoke-Command -Session $sesh -Verbose -ScriptBlock {Unblock-File -Path "C:\Program Files\METRICBEAT\install-service-metricbeat.ps1"; Unblock-File -Path "C:\Program Files\METRICBEAT\uninstall-service-metricbeat.ps1";`
        & "C:\Program Files\METRICBEAT\install-service-metricbeat.ps1" ; start-service metricbeat};
        if(($svc = get-service -ComputerName $computername -Name 'metricBEAT' -ErrorAction Ignore).status -eq 'Running'){$installedMetricBEAT += "$computername"}
        Remove-PSSession $sesh})
    }
    End
    {
    Write-Verbose "Installed metricBEAT on;"
    ($installedMetricBEAT).ForEach({Write-Verbose "$_"})
    }
}
