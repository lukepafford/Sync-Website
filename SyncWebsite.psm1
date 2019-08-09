function crawl([string]$url) {
    $url = $url.TrimEnd('/')

    $uri = $url | makeUri
    $html = (isHtml $url)
    if ($html) {
        $result = request $url "GET" $proxy

        $validLinks = $result.links | % {$_.href } | noGarbageHref | makeAbsolute $uri | makeUri | noExternalDomains $uri | noParentLinks $uri

        foreach ($link in $validLinks) {
            $html = (isHtml $link.AbsoluteUri)
            if ($html -and $link.Absoluteuri -notin $global:visted) {
                $global:visted += $link.AbsoluteUri
                $global:urls += $link.AbsoluteUri
            } else {
                $relativeDest = (Join-Path $dest (pathDifference $originalUri $link.AbsoluteUri))
                    
                # Skip the download if the file already exists, unless overwrite_existing_files=True
                if ($overwrite_existing_files -or (!(Test-Path (Join-Path $relativeDest $link.Segments[-1])))) {
                    download $link.AbsoluteUri $relativeDest
                } else {
                    Write-Host "Skipping existing file: $link.AbsoluteUri"
                }
            }
        }
    }
}

filter noGarbageHref {
    if (!($_ -eq "/" -or $_.StartsWith('?'))) {
        $_
    }
}


filter noExternalDomains([System.Uri]$uri) {
    if (!(isdifferentDomain $uri $_)) {
        $_
    }
}

filter noParentLinks([System.Uri]$uri) {
    if (!(isParentLink $uri $_)) {
        $_
    }
}

function request([string]$url, [string]$method = "GET", [string]$proxy = '') {
    $arguments = @{
        Method = $method
        URI = $url
    }
    if ($proxy) {
        $arguments.proxy = $proxy
        $arguments.proxyUseDefaultCredentials = $true
    }

    $result = Invoke-WebRequest @arguments
    return $result
}

filter makeUri {
        New-Object -typeName 'System.Uri' -argumentList $_    
}

function isHTML([string]$url) {
    $result = request $url "HEAD" $proxy
    $contentType = $result.headers.'Content-Type'
    if ($contentType -match '^text/html') {
        return $true
    }else{
        return $false
    }
}

function isAbsolute([string]$url) {
    if ($url.IndexOf('://') -gt 0 -or $url.IndexOf('//') -eq 0) {
        return $true
    } else {
        return $false
    }
}

function isDifferentDomain([System.Uri]$parent, [System.Uri]$child) {
    if ($($parent.Host) -ne $($child.Host)) {
        return $true
    } else {
        return $false
    }
}

function isParentLink([System.Uri]$parent, [System.Uri]$child) {
    if ($parent.AbsolutePath.length -gt $child.AbsolutePath.length) {
        return $true
    } else {
        return $false
    }
}

function makeAbsolute([System.Uri]$parent) {
    Process {
        if ((isAbsolute $_) -eq $true) {
            return $_
        } else {
          if ($_.StartsWith('/')) {
            return $($parent.Scheme) + '://' + $($parent.Host) + $_
          } else {
            return $($parent.AbsoluteUri), $_ -join "/"
          }
        }
    }
}

# Returns any child directories that the child url has that the parent doesnt
# This will allow the directory structure to be created at the destination
function pathDifference([System.Uri]$parent, [System.Uri]$child) {
    $path = ($child.AbsolutePath -split $parent.absolutePath) | ?{$_}
    $dirs = $path -split "/"
    if ($dirs.length -eq 1) {
        # The child is at the root of the parent. No directories need to be created
        return ""
    }

    # Select all but the last element (the last element is the filename)
    # The split array also has an empty item at the end which is why
    # its ($dirs.length - 2) and not ($dirs.length - 1)
    $dirItems = $dirs[0..($dirs.length - 2)]
 
    # Join the elements to create a relative path
    $dirPath = $dirItems -join "\"
  
    return $dirPath
}

function download([string]$url, [string]$dest) {
    if (!(test-path $dest)) {
        New-Item -ItemType Directory -Force -Path $dest
    }

    $arguments = @{
        Source = $url
        Destination = $dest
        DisplayName = "Downloading $url to $dest"
        Priority = "Normal"
        TransferType = "Download"
    }

    if ($proxy) {
        $arguments.proxyList = @($proxy)
        $arguments.UseStoredCredential = "Proxy"
        $arguments.ProxyUsage = "Override"
    }
        
    Start-BitsTransfer @arguments
}


function Sync-Website {
   <#
   .EXAMPLE

   PS> Sync-Website.ps1 -url https://example.com/packages -dest .\downloadDir -proxy 'http://XX.XX.X.XXX:443'

   #>
   
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] 
        $url,
    
        [Parameter(Mandatory=$false)]
        [string]
        $dest = (Get-Location),
    
        [Parameter(Mandatory=$false)]
        [string] 
        $proxy = '',

        [Parameter(Mandatory=$false)]
        [Switch] 
        $overwrite_existing_files = $false
    )

    Process {
        $originalUri = $url | makeUri

        [string[]]$global:urls = @($url)
        [string[]]$global:visited = @()
        while($global:urls.count -gt 0){
	        $current = $global:urls[0]
	        $global:urls[0] = $null
	        $global:urls = ($global:urls | ? { $_ -ne $null -and $_ -ne ''})
	        crawl($current)
        }
    }
}

Export-ModuleMember -Function Sync-Website
