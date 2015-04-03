<#
.SYNOPSIS
Gather a quick report from all vCenters in the environment.  Takes an argument of a vCenter address, several addresses or a file of addresses.
.DESCRIPTION
Get-VMInventoryReport is intended to simplify gathering a quick snapshot of the VM environment for inventory,
licensing or some other concern.  The results are a CSV or a collection of CSVs, if using a file for input.
THIS WILL NOT WORK WITHOUT VMWARE POWERCLI INSTALLED!  On the other hand, it will load the needed modules for you.
.PARAMETER server
This should be the IP address or server name of a vCenter server in the environment.

.PARAMETER filePath
This is the path to a text file containing the IP or hostname of each vCenter Server in scope, one listed per line,
in order for this script to function correctly.  No data validation is currently performed on this file, so it must
 be in the correct format of one IP or name per line and nothing else.

.EXAMPLE
Get-VMInventoryReport -server 192.168.1.200

.EXAMPLE
Get-VMInventoryReport -filePath "C:\vCenter_Servers.txt"
#>


# This needs the PowerCLI modules from VMWare loaded.
Function Get-VMInventoryReport{
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$True,
		ValueFromPipeline=$True,
		ParameterSetName="address_array")]
		[string[]]$server,
		[Parameter(Mandatory=$True,
		ParameterSetName="file")]
		[String]$filePath
	)
	BEGIN{
	if (( Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null )
	{
		Add-PSSnapin VMware.VimAutomation.Core
	}
	}
	PROCESS{
		if ($psCmdlet.ParameterSetName -eq "file")
		{
			#Read in the input file.
			$vcenterservers = Get-Content $filePath
		} else {
			$vcenterservers = $server
		}

		#Connect to each vCenter listed and output the list of VMs with Name, Power, OS, and host info needed.
		ForEach ($vcenterserver in $vcenterservers)
		{
			Write-Verbose "Gathering information on $vcenterserver"
			Connect-VIServer -Server $vcenterserver -WarningAction SilentlyContinue | Out-Null
			$reportpath = $vcenterserver + "_VM_report.csv"
			$vmreport = foreach ($Datacenter in ( Get-Datacenter | Sort-Object -Property Name))
			{
				foreach ($Cluster in ( Get-Datacenter $Datacenter | Get-Cluster | Sort-Object -Property Name))
					{
						foreach ( $vm in  ($Cluster | Get-VM | Sort-Object -Property Name) )
						{
							"" | Select-Object -Property @{N="VM";E={$VM.Name}},
							@{N="Power";E={$vm.PowerState}},
							@{N="Guest OS";E={$VM.Guest.OSFullName}},
							@{N="Datacenter";E={$Datacenter.name}},
							@{N="Cluster";E={$Cluster.Name}},
							@{N="Host";E={$vm.VMHost.Name}},
							@{N="Host CPU#";E={$vm.VMHost.ExtensionData.Summary.Hardware.NumCpuPkgs}},
							@{N="Host CPU Core#";E={$vm.VMHost.ExtensionData.Summary.Hardware.NumCpuCores/$vm.VMHost.ExtensionData.Summary.Hardware.NumCpuPkgs}}
						}
					} 
			}
			Write-Verbose "Writing $vcenterserver data to CSV"
			$vmreport | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $reportpath
			Write-Verbose "Done!"
			Disconnect-VIServer -Server $vcenterserver -Force:$true -Confirm:$false
		}
	}
	END {}
}