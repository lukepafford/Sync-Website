function crawl([string]$url) {
    $url = $url.TrimEnd('/')

    $uri = (makeUri $url)
    $html = (isHtml $url)
    if ($html) {
        $result = request $url "GET" $proxy

        $absoluteLinks = @()
        foreach ($link in $result.links) {
            try {
                $absoluteLink = (makeAbsolute $uri $link.href)
                $linkUri = (makeUri $absoluteLink)
            } catch {
                # If creating a [system.uri] fails then the URL isn't valid
                # and it should not be crawled
                continue
            }

            # Skip a garbage href
            if ($link.href -eq "/" -or $link.href.StartsWith('?')) {
                continue
            } 
   
            # Skip links that point to external sites.
            elseif ((isDifferentDomain $uri $linkUri) -eq $true) {
                continue
            }
            # Skip any parent directories.
            elseif ((isParentDirectory $uri $linkUri) -eq $true) {
                continue   
            }
            else {
                $html = (isHtml $absoluteLink)
                if ($html -and $absoluteLink -notin $global:visted) {
                    $global:visted += $absoluteLink
                    $global:urls += $absoluteLink
                } else {
                    $relativeDest = (Join-Path $dest (pathDifference $originalUri $linkUri))
                    
                    # Skip the download if the file already exists, unless overwrite_existing_files=True
                    if ($overwrite_existing_files -or (!(Test-Path (Join-Path $relativeDest $linkUri.Segments[-1])))) {
                        download $absoluteLink $relativeDest
                    } else {
		    	Write-Host "Skipping existing file: $absoluteLink"
		    }
                }
            }
        }
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

function makeUri([string]$url) {
    $uri = (New-Object -typeName 'System.Uri' -argumentList ([system.uri]$url).AbsoluteUri)
    return $uri
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

function isParentDirectory([System.Uri]$parent, [System.Uri]$child) {
    if ($parent.AbsolutePath.length -gt $child.AbsolutePath.length) {
        return $true
    } else {
        return $false
    }
}

function makeAbsolute([System.Uri]$parent, [string]$child) {
    if ((isAbsolute $child) -eq $true) {
        return $child
    } else {
      if ($child.StartsWith('/')) {
        return $($parent.Scheme) + '://' + $($parent.Host) + $child
      } else {
        return $($parent.AbsoluteUri), $child -join "/"
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
        $originalUri = makeUri $url

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
