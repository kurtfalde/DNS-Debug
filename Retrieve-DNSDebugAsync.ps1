#  The purpose of this script is to remotely connect to all DCs in a forest and retrieve the debug dns.log file
#  In order to make efficient use of networking need to compress the file prior to copying back to the collecting host
#  Requirements are that this must still run on 2003 systems and systems that we cannot rely on PS Remoting being enabled on
#  Cannot directly run makecab.exe against dns.log as the DNS service has the file in use, must copy prior to compressing
#
#
#  Script makes use of psasync module for runspaces / asynchronous operation https://psasync.codeplex.com/
#  psasync.psm1 must be in the same directory as script
#
#  Written by Kurt Falde kfalde@microsoft.com 3/28/2015
#
#


Import-Module .\psasync.psm1
 
$AsyncPipelines = @()
 
$ScriptBlock = `
{
    Param($DC)
     
$timestamp = (get-date).toString(‘yyyyMMddhhmm’)

$copyresult = ([WmiClass]"\\$DC\ROOT\CIMV2:Win32_Process").create("cmd /c copy c:\windows\system32\dns\dns.log c:\windows\system32\dns\$DC-$timestamp-dns.log")
	switch ($copyresult.returnvalue) 
	    { 
        	0 {"$DC Successful Completion."} 
	        2 {"$DC Access Denied."} 
        	3 {"$DC Insufficient Privilege."} 
	        8 {"$DC Unknown failure."} 
        	9 {"$DC Path Not Found."} 
	        21 {"$DC Invalid Parameter."} 
        	default {"$DC Could not be determined."}
	    }	
#Wait for completion of copy
$copyresultpid = $copyresult.ProcessId
$wait = $true
While ($wait) 
    {
    start-sleep -Milliseconds 250
    $test = Get-WmiObject -ComputerName $DC -query "select * from Win32_Process Where ProcessID='$copyresultpid'"
    if ((Measure-Object -InputObject $test).Count -eq 0)
        {
        $wait = $false
        }
    }

$makecabresult = ([WmiClass]"\\$DC\ROOT\CIMV2:Win32_Process").create("cmd /c makecab c:\windows\system32\dns\$DC-$timestamp-dns.log c:\windows\system32\dns\$DC-$timestamp-dns.cab")
	switch ($makecabresult.returnvalue) 
	    { 
        	0 {"$DC Successful Completion."} 
	        2 {"$DC Access Denied."} 
        	3 {"$DC Insufficient Privilege."} 
	        8 {"$DC Unknown failure."} 
        	9 {"$DC Path Not Found."} 
	        21 {"$DC Invalid Parameter."} 
        	default {"$DC Could not be determined."}
	    }	
#Wait for completion of makecab process
$makecabresultpid = $makecabresult.ProcessId
$wait = $true
While ($wait) 
    {
    start-sleep -Milliseconds 250
    $test = Get-WmiObject -Computername $DC -query "select * from Win32_Process Where ProcessID='$makecabresultpid'"
    if ((Measure-Object -InputObject $test).Count -eq 0)
        {
        $wait = $false
        }
    }
#Move File back to Collection Server
move-item -path \\$DC\c$\windows\system32\dns\$DC-$timestamp-dns.cab C:\DNSDEBUG -Force
remove-item -path \\$DC\c$\windows\system32\dns\$DC-$timestamp-dns.log -Force

}
 
# Create a pool of 10 runspaces
$pool = Get-RunspacePool 10
 
$Forest = [system.directoryservices.activedirectory.Forest]::GetCurrentForest()   
$ForestDomainString=$Forest.domains.forest.tostring()
$DCS=$Forest.domains | ForEach-Object {$_.DomainControllers} | ForEach-Object {$_.Name} 

 
foreach($DC in $DCS)
{
     $AsyncPipelines += Invoke-Async -RunspacePool $pool -ScriptBlock $ScriptBlock -Parameters $DC
}
 
Receive-AsyncStatus -Pipelines $AsyncPipelines
 
Receive-AsyncResults -Pipelines $AsyncPipelines -ShowProgress
