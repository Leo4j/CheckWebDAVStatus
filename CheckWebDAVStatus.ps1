function CheckWebDAVStatus
{
	
    [CmdletBinding()] Param(

        [Parameter (Mandatory=$False, Position = 0, ValueFromPipeline=$true)]
        [int]
        $Threads,

 	[Parameter (Mandatory=$False, Position = 1, ValueFromPipeline=$true)]
        [String]
        $Domain,

 	[Parameter (Mandatory=$False, Position = 2, ValueFromPipeline=$true)]
        [String]
        $Targets,

 	[Parameter (Mandatory=$False, Position = 3, ValueFromPipeline=$true)]
        [String]
        $OutputFile

 	)

  	if($Threads){}
   	else{$Threads = "20"}

	Write-Output ""
	
	$ErrorActionPreference = "SilentlyContinue"
	
	Write-Output " Checking Hosts..."

 	if($Targets){
  		$Computers = $Targets
	}
  	else{	
   		if($Domain){
     			# Get a list of all the computers in the domain
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Domain")
			$objSearcher.Filter = "(&(sAMAccountType=805306369))"
			$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
			$Computers = ($Computers -join ',')
		}

       		else{
			# Get a list of all the computers in the domain
			$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
			$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
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
	  		$Computers = ($Computers -join ',')
     		}
  	}
	
	iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Tools/main/Invoke-GetWebDAVStatus.ps1')

	$WebDAVStatusEnabled = Invoke-Expression "Invoke-GetWebDAVStatus -Command `"$Computers --tc $Threads`""
	$WebDAVStatusEnabled = ($WebDAVStatusEnabled | Out-String) -split "`n"
	$WebDAVStatusEnabled = $WebDAVStatusEnabled | Select-String "[+]"
	$WebDAVStatusEnabled = ($WebDAVStatusEnabled | Out-String) -split "`n"
	$WebDAVStatusEnabled = $WebDAVStatusEnabled.Trim()
	$WebDAVStatusEnabled = $WebDAVStatusEnabled | Where-Object { $_ -ne "" }
	#$WebDAVStatusEnabled = $WebDAVStatusEnabled | ForEach-Object { $_.Replace("[+] WebClient Service is active on ", "") }
	$WebDAVStatusEnabled = $WebDAVStatusEnabled | Sort-Object -Unique

	
	if($WebDAVStatusEnabled){
	
		if($OutputFile){$WebDAVStatusEnabled | Out-File $OutputFile}
  		else{$WebDAVStatusEnabled | Out-File $pwd\WebDAVStatusEnabled.txt}
		Write-Output ""
		$WebDAVStatusEnabled
		Write-Output ""
  		if($OutputFile){Write-Output " Output saved to: $OutputFile"}
		else{Write-Output " Output saved to: $pwd\WebDAVStatusEnabled.txt"}
		Write-Output ""
	 }
	
	 else{
	 	Write-Output " No hosts found where the WebClient Service is active."
	  	Write-Output ""
	  }
}
