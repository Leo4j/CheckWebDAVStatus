function CheckWebDAVStatus
{
	
    [CmdletBinding()] Param(

        [Parameter (Mandatory=$False, Position = 0, ValueFromPipeline=$true)]
        [int]
        $threads,

 	[Parameter (Mandatory=$False, Position = 1, ValueFromPipeline=$true)]
        [String]
        $Targets

 	)

  	if($threads){}
   	else{$threads = "20"}

	Write-Host "   ____ _               _   __        __   _     ____    ___     ______  _        _             "
	Write-Host "  / ___| |__   ___  ___| | _\ \      / /__| |__ |  _ \  / \ \   / / ___|| |_ __ _| |_ _   _ ___ "
	Write-Host " | |   | '_ \ / _ \/ __| |/ /\ \ /\ / / _ \ '_ \| | | |/ _ \ \ / /\___ \| __/ _`  | __| | | / __|"
	Write-Host " | |___| | | |  __/ (__|   <  \ V  V /  __/ |_) | |_| / ___ \ V /  ___) | || (_| | |_| |_| \__ \"
	Write-Host "  \____|_| |_|\___|\___|_|\_\  \_/\_/ \___|_.__/|____/_/   \_\_/  |____/ \__\__,_|\__|\__,_|___/"
	Write-Host "                                                                                                "
	Write-Host ""
	
	$ErrorActionPreference = "SilentlyContinue"
	
	Write-Host " Checking Hosts..." -ForegroundColor Yellow

 	if($Targets){
  		$Computers = $Targets
	}
  	else{
		# Get a list of all the computers in the domain
		$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
		$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
		$objSearcher.Filter = "(&(sAMAccountType=805306369))"
		$Computers = $objSearcher.FindAll() | %{$_.properties.dnshostname}
		
		$jcurrentdomain = Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select Domain | Format-Table -HideTableHeaders | out-string | ForEach-Object { $_.Trim() }
		$Computers = $Computers | Where-Object {-not ($_ -cmatch "$env:computername")}
		$Computers = $Computers | Where-Object {-not ($_ -match "$env:computername")}
		$Computers = $Computers | Where-Object {$_ -ne "$env:computername"}
		$Computers = $Computers | Where-Object {$_ -ne "$env:computername.$jcurrentdomain"}
		$Computers = $Computers | ForEach-Object { $_.Replace(".$($jcurrentdomain)", "") }
  		$Computers = ($Computers -join ',')
  	}
	
	iex(new-object net.webclient).downloadstring('https://raw.githubusercontent.com/Leo4j/Tools/main/Invoke-GetWebDAVStatus.ps1')

	$WebDAVStatusEnabled = Invoke-Expression "Invoke-GetWebDAVStatus -Command `"$Computers --tc $threads`""
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
