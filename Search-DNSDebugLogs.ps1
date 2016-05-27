#
#  Script to unpack directory of DNS Debug Log files that have been .cabbed up
#  Followed by deleting the .cab files and then searching them for a specific list of URL's
#  
#  Modify the $match array to include a list of DNS queries of interest, just use the DNS Domain name
#  Default list has " TXT " to dump all TXT record queries looking for DNS TXT Extraction
#
#
#  Written by Kurt Falde kfalde@microsoft.com 3/28/2015
#

$timestamp = (get-date).toString(‘yyyyMMddhhmm’)
$BadThings = " TXT ", "baddomainnamehere", "whyohwhydidIpickIT", "gladmyresumeisuptodate"

# Expand all .cab's to .log files

expand -R *-dns.cab

# Loop through DNS log files looking for things of interest

$DNSLogs = Get-ChildItem -Filter *-dns.log


Foreach ($DNSLog in $DNSLogs)
    {
     (Get-Content $DNSLog -ReadCount 0) | Select-String -AllMatches $BadThings | Out-File -FilePath .\DNSDebugHits-$timestamp.txt


    }
