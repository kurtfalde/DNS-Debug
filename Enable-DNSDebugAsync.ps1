#  The default purpose of this script is to quickly enable DNS Debug logging across all DC's in a forest
#  The DNS Debug log file is hard coded to create in C:\Windows\System32\dns\dns.log
#  The DNS Debug log file max size is set to 500Mb, it is a circular log and will not fill up the system
#  The DNS Debug level is set to log incoming UDP Query Requests only = 0x00006101
#  DNS Debug level explained https://technet.microsoft.com/en-us/library/cc772069.aspx
#  4000 (Log UDP Packets + 2000 (Log Receive Packets) + 100 (Log Question Transactions) + 1 (Log Queries) = 6101 or 0x00006101
#
#  Script makes use of psasync module for runspaces / asynchronous operation https://psasync.codeplex.com/
#  psasync.psm1 must be in the same directory as script
#
#  The Same Script can be used to disable DNS Debug Logging as well just change the line with /LogLevel to a value of 0 and run again
#
#
#


Import-Module .\psasync.psm1
 
$AsyncPipelines = @()
 
$ScriptBlock = `
{
    Param($DC)
     
Write-Output "Setting DNS LogFilePath, LogFileMaxSize (500Mb), LogLevel (0x00006101) on '$DC'"
Invoke-Expression "DNSCMD '$DC' /Config /LogFilePath C:\Windows\System32\dns\dns.log"
Invoke-Expression "DNSCMD '$DC' /Config /LogFileMaxSize 500000000"
Invoke-Expression "DNSCMD '$DC' /Config /LogLevel 0x00006101"

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
