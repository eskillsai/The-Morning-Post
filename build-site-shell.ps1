param(
    [Parameter(Mandatory = $true)]
    [string]$TemplatePath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [Parameter(Mandatory = $true)]
    [string]$ArchiveFile
)

$ErrorActionPreference = 'Stop'
$template = [System.IO.File]::ReadAllText($TemplatePath)
$placeholder = '__CURRENT_POST_URL__'
if (([regex]::Matches($template, [regex]::Escape($placeholder))).Count -ne 1) {
    throw 'The site shell must contain exactly one current-post placeholder.'
}
$fileName = [System.IO.Path]::GetFileName($ArchiveFile)
$postUrl = './archives/' + [System.Uri]::EscapeDataString($fileName)
$page = $template.Replace($placeholder, $postUrl)
[System.IO.File]::WriteAllText($OutputPath, $page, [System.Text.UTF8Encoding]::new($false))