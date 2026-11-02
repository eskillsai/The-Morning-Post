param(
    [Parameter(Mandatory = $true)]
    [string]$ArchivePath,
    [string]$PostPath
)

$ErrorActionPreference = 'Stop'
$archiveRoot = [System.IO.Path]::GetFullPath($ArchivePath)
$outputPath = Join-Path $archiveRoot 'index.html'
$culture = [System.Globalization.CultureInfo]::InvariantCulture

if ($PostPath -and (Test-Path -LiteralPath $PostPath)) {
    $postContent = [System.IO.File]::ReadAllText($PostPath)
    $oldArchiveLink = '<a class="archive-link" href="./archives/" aria-label="Browse past Morning Posts">Archives</a>'
    $postContent = $postContent.Replace($oldArchiveLink, '')
    [System.IO.File]::WriteAllText($PostPath, $postContent, [System.Text.UTF8Encoding]::new($false))
}

$records = foreach ($file in Get-ChildItem -LiteralPath $archiveRoot -Filter '*.html' -File) {
    if ($file.Name -eq 'index.html') { continue }

    $dateText = $null
    $priority = 99
    if ($file.Name -match '^The Morning post_(\d{4}-\d{2}-\d{2})\.html$') {
        $dateText = $Matches[1]
        $priority = 0
    } elseif ($file.Name -match '^The Morning post_(.+)\.html$') {
        $dateText = $Matches[1]
        $priority = 1
    } elseif ($file.Name -match '([A-Za-z]{3} \d{1,2} \d{4})\.html$') {
        $dateText = $Matches[1]
        $priority = 2
    }

    $parsedDate = [datetime]::MinValue
    if ($dateText -and [datetime]::TryParse($dateText, $culture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsedDate)) {
        [pscustomobject]@{
            Date = $parsedDate.Date
            FileName = $file.Name
            Priority = $priority
        }
    }
}

$byDate = @{}
foreach ($record in @($records)) {
    $dateKey = $record.Date.ToString('yyyy-MM-dd', $culture)
    if (-not $byDate.ContainsKey($dateKey) -or $record.Priority -lt $byDate[$dateKey].Priority) {
        $byDate[$dateKey] = $record
    }
}
$posts = @($byDate.Values | Sort-Object Date -Descending)
if ($posts.Count -eq 0) {
    $items = '      <li class="empty">No archived posts yet.</li>'
} else {
    $items = foreach ($post in $posts) {
        $href = [System.Uri]::EscapeDataString($post.FileName)
        $label = [System.Net.WebUtility]::HtmlEncode($post.Date.ToString('MMMM d, yyyy', $culture))
        "      <li><a href=`"$href`"><span>$label</span><span class=`"read`">Read post</span></a></li>"
    }
    $items = $items -join "`r`n"
}

$page = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Archives - eskillsai Morning Post</title>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;700;800&display=swap">
  <style>
    :root{color-scheme:light;--bg:#EEF0F8;--panel:#fff;--ink:#1B1E3A;--muted:#5A5F7D;--line:#DDE0EE;--acc:#7B2CFF}
    *{box-sizing:border-box}
    body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 Manrope,system-ui,-apple-system,'Segoe UI',Arial,sans-serif}
    main{width:min(760px,calc(100% - 32px));margin:40px auto}
    .back{display:inline-block;margin-bottom:24px;color:var(--acc);font-weight:700;text-decoration:none}
    .back:hover{text-decoration:underline}
    header,.archive-list{background:var(--panel);border:1px solid var(--line);border-radius:16px}
    header{padding:28px 32px;margin-bottom:18px}
    .brand{margin:0 0 8px;color:var(--muted);font-size:13px;font-weight:800;letter-spacing:.08em;text-transform:uppercase}
    h1{margin:0;font-size:clamp(32px,7vw,48px);line-height:1.1}
    header p:last-child{margin:12px 0 0;color:var(--muted)}
    .archive-list{list-style:none;margin:0;padding:0;overflow:hidden}
    .archive-list li+li{border-top:1px solid var(--line)}
    .archive-list a{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 22px;color:var(--ink);font-weight:700;text-decoration:none}
    .archive-list a:hover{background:#F6F3FF;color:var(--acc)}
    .read{color:var(--acc);font-size:13px;white-space:nowrap}
    .empty{padding:22px;color:var(--muted)}
    @media(prefers-color-scheme:dark){:root{color-scheme:dark;--bg:#070921;--panel:#12163F;--ink:#E8EAFB;--muted:#A3A8CF;--line:#272C63;--acc:#B99BFF}.archive-list a:hover{background:#1B2054}}
  </style>
</head>
<body>
  <main>
    <a class="back" href="../">&larr; Today's Morning Post</a>
    <header>
      <p class="brand">eSkillsAI Morning Post</p>
      <h1>Archives</h1>
      <p>Browse previous daily posts.</p>
    </header>
    <ol class="archive-list">
$items
    </ol>
  </main>
</body>
</html>
"@
[System.IO.File]::WriteAllText($outputPath, $page, [System.Text.UTF8Encoding]::new($false))