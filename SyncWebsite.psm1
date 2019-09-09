function crawl(
    [string]$url,
    [string]$Thumbprint
) {
    $url = $url.TrimEnd('/')
    $uri = $url | makeUri

    $html = (isHtml $url $Thumbprint)

    if ($html) {
        $result = request $url "GET" $proxy $Thumbprint

        $validLinks = $result.links | % {$_.href } | noGarbageHref | makeAbsolute $uri | makeUri | noExternalDomains $uri | noParentLinks $uri

        foreach ($link in $validLinks) {
            $html = (isHtml $link.AbsoluteUri $Thumbprint)
            if ($html -and $link.Absoluteuri -notin $global:visted) {
                $global:visted += $link.AbsoluteUri
                $global:urls += $link.AbsoluteUri
            } else {
                $relativeDest = (Join-Path $Destination (pathDifference $originalUri $link.AbsoluteUri))
                $filename = (Join-Path $relativeDest $link.Segments[-1])

                # Skip the download if the file already exists, unless overwrite_existing_files=True
                if ($overwrite_existing_files -or (!(Test-Path $filename))) {
                    if ($Save_File_List -eq $true) {
                        $global:downloaded += $filename
                    }
		    # If the thumprint is available we *must* use the Invoke-Webrequest
		    # command because Start-BitsTransfer does *not* have any options to pass in a
		    # certificate. 
                    if($Thumbprint -notlike $null) {
                        if(!(Test-Path $relativeDest)) {
                            mkdir -Path $relativeDest | Out-Null
                        }
                        $args = @{
                            Uri = $link.AbsoluteUri
                            Method = "GET"
                            CertificateThumbprint = $Thumbprint
                            OutFile = $filename
                        }
                        if($proxy -notlike $null) {
                            $args.Proxy = $proxy
                            $args.proxyUseDefaultCredentials = $true
                        }
                        Invoke-WebRequest @args
                    } else {
                        download $link.AbsoluteUri $relativeDest
                    }
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

function request(
    [string]$url, 
    [string]$method = "GET", 
    [string]$proxy = '', 
    [string]$Thumbprint = ''
) {
    $arguments = @{
        Method = $method
        Uri = $url
    }
    if ($proxy -notlike $null) {
        $arguments.proxy = $proxy
        $arguments.proxyUseDefaultCredentials = $true
    }
    if ($Thumbprint -notlike $null) {
        $arguments.CertificateThumbprint = $Thumbprint
    }

    $result = Invoke-WebRequest @arguments
    
    return $result
}

filter makeUri {
        New-Object -typeName 'System.Uri' -argumentList $_    
}

function isHTML(
    [string]$url,
    [string]$Thumbprint = ''
) {
    $result = request $url "HEAD" "" $Thumbprint

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
            return $($parent.Scheme + "://" + $parent.Host), $_ -join "/"
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
   .PARAMETER Destination
   Root directory that the files will be downloaded into. This directory will be created if it does not exist.

   .PARAMETER Proxy
   Be sure to include the protocol in the proxy value. If the host is `192.168.1.10`, and the port is `443`,
   then the proxy value should be `http://192.168.1.10:443`.

   .PARAMETER Overwrite_Existing_Files
   By default the script will not download a file if it already exists at the destination. Set this switch to force the file to be downloaded.

   .PARAMETER Save_File_List
   Write a file to the root of the provided `Destination` that includes the fully qualified path of the downloaded file; One file per line.
   This allows you to easily pass the newest files to stdin for a copy job.
   
   The filename will be 'downloaded_files.txt'.

    .PARAMETER Certificate
    Use a client certificate to authenticate to the website.

   .EXAMPLE
    Sync-Website.ps1 -url https://example.com/packages -dest .\downloadDir -proxy 'http://XX.XX.X.XXX:443'

   #>
   
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] 
        $Url,
    
        [Parameter(Mandatory=$false)]
        [string]
        $Destination = (Get-Location),
    
        [Parameter(Mandatory=$false)]
        [string] 
        $Proxy = '',

        [Parameter(Mandatory=$false)]
        [Switch] 
        $Overwrite_Existing_Files = $false,
        
        [Parameter(Mandatory=$false)]
        [switch]
        $Save_File_List = $false,

        [Parameter(Mandatory=$false)]
        [switch]
        $Certificate = $false
    )

    begin {
        if($Certificate) {
            Add-Type -AssemblyName System.Security
            $ValidCerts = [System.Security.Cryptography.X509Certificates.X509Certificate2[]](Get-ChildItem Cert:\CurrentUser\My)
            $Cert = ([System.Security.Cryptography.X509Certificates.X509Certificate2UI]::SelectfromCollection($ValidCerts,'Choose a certificate','Choose a certificate', 0))[0]
        }
    }

    Process {
        $originalUri = $url | makeUri

        [string[]]$global:urls = @($url)
        [string[]]$global:visited = @()
        [string[]]$global:downloaded = @()
        while($global:urls.count -gt 0){
	        $current = $global:urls[0]
	        $global:urls[0] = $null
            $global:urls = ($global:urls | Where-Object { $_ -ne $null -and $_ -ne ''})
            if($Certificate) {
                crawl $current ($Cert.Thumbprint)
            } else {
                crawl($current)
            }
        }

        if ($Save_File_List -eq $true) {
            $global:downloaded | Out-File -FilePath "$Destination\downloaded_files.txt"
        }

    }
}

Export-ModuleMember -Function Sync-Website
