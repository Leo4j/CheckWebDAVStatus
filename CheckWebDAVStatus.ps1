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
        $Targets

 	)

  	if($Threads){}
   	else{$Threads = "20"}

	Write-Host ""
	
	$ErrorActionPreference = "SilentlyContinue"
	
	Write-Host " Checking Hosts..." -ForegroundColor Yellow

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
	
		$WebDAVStatusEnabled | Out-File $pwd\WebDAVStatusEnabled.txt
		Write-Host ""
		$WebDAVStatusEnabled
		Write-Host ""
		Write-Host " Output saved to: $pwd\WebDAVStatusEnabled.txt"
		Write-Host ""
	 }
	
	 else{
	 	Write-Host " No hosts found where the WebClient Service is active."
	  	Write-Host ""
	  }
}
