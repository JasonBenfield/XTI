
function Xti-ExportWeb {
    param(
        [switch] $Prod,
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
        [string] $AppName,
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
        [string] $ProjectDir
    )

    if(Test-Path "$($ProjectDir)\Exports") {
        Remove-Item "$($ProjectDir)\Exports\*" -Recurse -Force
    }
    $tsConfig = "$($ProjectDir)\Scripts\$($AppName)\tsconfig.json"
    if(-not (Test-Path $tsConfig)) {
        $tsConfig = "$($ProjectDir)\Scripts\tsconfig.json"
    }
    tsc -p $tsConfig --outDir "$($ProjectDir)\Exports\Scripts\" --declaration true

    $source = "$($ProjectDir)\Scripts\$($AppName)"
    $target = "$($ProjectDir)\Exports\Scripts"
    robocopy $source $target *.d.ts /e /njh /njs /np /ns /nc /nfl /ndl
    robocopy $source $target *.html /e /njh /njs /np /ns /nc /nfl /ndl
    robocopy $source $target *.scss /e /njh /njs /np /ns /nc /nfl /ndl
    
    $source = "$($ProjectDir)\Views\Exports\$($AppName)"
    if(Test-Path $source) {
        $target = "$($ProjectDir)\Exports\Views"
        robocopy $source $target /e /njh /njs /np /ns /nc /nfl /ndl
    }

    if($Prod) {
        $envName = "Production"
    }
    else {
        $envName = "Development"
    }
    $source = "$($ProjectDir)\Exports"
    $target = "$($env:XTI_WebExports)\$EnvName\$($AppName)"
    robocopy $source $target /e /purge /njh /njs /np /ns /nc /nfl /ndl /a+:R
}

function Xti-ImportWeb {
    param(
        [switch] $Prod,
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
        [string] $AppToImport,
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory)]
        [string] $ProjectDir
    )
    
    if($Prod) {
        $envName = "Production"
    }
    else {
        $envName = "Development"
    }

    $source = "$($env:XTI_WebExports)\$EnvName\$($AppToImport)\Scripts"
    $target = "$($ProjectDir)\Imports\$($AppToImport)"
    robocopy $source $target /e /purge /njh /njs /np /ns /nc /nfl /ndl /a+:R
    
    $source = "$($env:XTI_WebExports)\$EnvName\$($AppToImport)\Views"
    if(Test-Path $source) {
        $target = "$($ProjectDir)\Views\Exports\$($AppToImport)"
        robocopy $source $target /e /purge /njh /njs /np /ns /nc /nfl /ndl /a+:R
    }
}