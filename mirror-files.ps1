clear;

function crawl([string]$url) {
    if (isHtml($url)) {
        write-output "Recursing URL $url"
        $result = (Invoke-WebRequest -uri $url)
	    $links = ($result.links | ? { $_.href -like "http*" } | Select -expand href) 
        foreach ($link in $links) {
            $global:urls += $_
        }
    } else {
        $global:files += $_
    }
}

function isHTML([string]$url) {
    write-output "Checking if $url is html"
    $result = (Invoke-WebRequest -Method "Head" -uri $url)
    $contentType = $result.headers.'Content-Type'
    if ($contentType -match '^text/html') {
        write-output "$url is html"
        return $true
    }else{
        write-output "$url is not html"
        return $false
    }
}


[string[]]$global:urls = @("http://mirror.centos.org/centos/7/configmanagement/x86_64/ansible27/")
[string[]]$global:files = @()
while($global:urls.count -gt 0){
	$current = $global:urls[0]
	write-host $current
	$global:urls[0] = $null
	$global:urls = ($global:urls | ? { $_ -ne $null -and $_ -ne ''})
	crawl($current)
}


Write-Output $global:urls
Write-Output $global:files
