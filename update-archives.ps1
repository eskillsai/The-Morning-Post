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
            LastWriteTimeUtc = $file.LastWriteTimeUtc
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
$monthMarkup = ''
$latestHref = ''
$latestLabel = ''
$editionCount = $posts.Count
if ($editionCount -gt 0) {
    $latest = $posts[0]
    $latestHref = [System.Uri]::EscapeDataString($latest.FileName)
    $latestLabel = [System.Net.WebUtility]::HtmlEncode($latest.Date.ToString('MMMM d, yyyy', $culture))
    $monthLines = [System.Collections.Generic.List[string]]::new()
    $monthGroups = @($posts | Group-Object { $_.Date.ToString('yyyy-MM', $culture) })
    $monthIndex = 0

    foreach ($monthGroup in $monthGroups) {
        $monthPosts = @($monthGroup.Group | Sort-Object Date -Descending)
        $monthDate = $monthPosts[0].Date
        $monthLabel = $monthDate.ToString('MMMM yyyy', $culture)
        $monthId = 'month-' + $monthDate.ToString('yyyy-MM', $culture)
        $monthCount = $monthPosts.Count
        $countLabel = if ($monthCount -eq 1) { '1 edition' } else { "$monthCount editions" }
        $expanded = if ($monthIndex -eq 0) { 'true' } else { 'false' }

        $monthLines.Add('    <section class="archive-month">')
        $monthLines.Add("      <h2 class=`"archive-month-heading`"><button class=`"archive-month-toggle`" type=`"button`" aria-expanded=`"$expanded`" aria-controls=`"$monthId`"><span class=`"archive-month-name`">$monthLabel</span><span class=`"archive-month-count`">$countLabel</span><span class=`"archive-month-chevron`" aria-hidden=`"true`"></span></button></h2>")
        $hidden = if ($expanded -eq 'true') { '' } else { ' hidden' }
        $monthLines.Add("      <ul class=`"archive-days`" id=`"$monthId`"$hidden>")

        foreach ($post in $monthPosts) {
            $href = [System.Uri]::EscapeDataString($post.FileName)
            $dateIso = $post.Date.ToString('yyyy-MM-dd', $culture)
            $dateLabel = [System.Net.WebUtility]::HtmlEncode($post.Date.ToString('MMMM d, yyyy', $culture))
            $weekday = [System.Net.WebUtility]::HtmlEncode($post.Date.ToString('ddd', $culture))
            $dayNumber = $post.Date.ToString('dd', $culture)
            $current = if ($post.FileName -eq $latest.FileName) { ' aria-current="page"' } else { '' }
            $monthLines.Add("        <li><a class=`"archive-day`" href=`"$href`" data-iso=`"$dateIso`" data-title=`"$dateLabel`" aria-label=`"$dateLabel edition`"$current><span class=`"archive-day-date`"><span class=`"archive-day-number`">$dayNumber</span><span class=`"archive-day-weekday`">$weekday</span></span><span class=`"archive-day-action`">Read <span aria-hidden=`"true`">&rarr;</span></span></a></li>")
        }

        $monthLines.Add('      </ul>')
        $monthLines.Add('    </section>')
        $monthIndex++
    }
    $monthMarkup = $monthLines -join "`r`n"
}

$editionCountLabel = if ($editionCount -eq 1) { '1 archived edition' } else { "$editionCount archived editions" }
if ($editionCount -gt 0) {
    $viewerMarkup = @"
      <section class="archive-viewer" aria-labelledby="edition-title">
        <div class="archive-viewer-heading">
          <div>
            <p class="archive-viewer-kicker">Selected edition</p>
            <h2 id="edition-title">$latestLabel</h2>
            <p class="archive-viewer-meta" id="edition-meta">Daily AI briefing &middot; $latestLabel</p>
          </div>
          <a class="archive-open-link" id="open-edition" href="$latestHref" target="_blank" rel="noopener noreferrer">Open full edition <span aria-hidden="true">&#8599;</span></a>
        </div>
        <div class="archive-frame-wrap"><iframe class="archive-frame" id="archive-frame" src="$latestHref" title="$latestLabel - The Morning Post" scrolling="no"></iframe></div>
      </section>
"@
} else {
    $viewerMarkup = @"
      <section class="archive-viewer" aria-labelledby="edition-title">
        <div class="archive-viewer-heading"><div><p class="archive-viewer-kicker">Archive library</p><h2 id="edition-title">No editions yet</h2><p class="archive-viewer-meta">Daily editions will appear here when published.</p></div></div>
        <div class="archive-empty-reader"><span aria-hidden="true">MP</span><p>There are no archived editions to display yet.</p></div>
      </section>
"@
}

$page = @"
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="description" content="Browse past editions of The Morning Post by month and date.">
  <title>The Morning Post Archives | eSkillsAI</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;700;800&display=swap">
  <link rel="stylesheet" href="../site.css?v=20261102-3">
  <link rel="alternate" type="application/rss+xml" title="The Morning Post RSS" href="../feed.xml">
</head>
<body class="archive-body">
  <main class="archive-shell">
    <div class="archive-topline">
      <a class="archive-brand" href="../" aria-label="The Morning Post home"><span class="archive-brand-mark" aria-hidden="true">MP</span><span><strong>The Morning Post</strong><small>by eSkillsAI</small></span></a>
      <a class="archive-return" href="../"><span aria-hidden="true">&larr;</span> Today's edition</a>
    </div>
    <section class="archive-intro" aria-labelledby="archive-title">
      <p class="archive-eyebrow">The Morning Post &middot; Reading room</p>
      <h1 id="archive-title">Explore the archive</h1>
      <p>Browse daily AI briefings by month. Choose a date to read that edition here.</p>
    </section>
    <div class="archive-layout">
      <aside class="archive-sidebar" aria-label="Archive navigation">
        <div class="archive-sidebar-heading"><div><p class="archive-sidebar-title">Browse by month</p><p class="archive-sidebar-count">$editionCountLabel</p></div><span class="archive-calendar-mark" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3M16.5 3.5v3M3.5 9.5h17" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></span></div>
        <nav class="archive-months" aria-label="Archive months">
$(if ($editionCount -gt 0) { $monthMarkup } else { '          <p class="archive-no-posts">No archived editions yet.</p>' })
        </nav>
      </aside>
$viewerMarkup
    </div>
    <footer class="archive-footer"><span>The Morning Post by eSkillsAI</span><a href="../feed.xml">RSS feed</a></footer>
  </main>
  <script>
    (function(){
      const frame=document.getElementById('archive-frame');
      const links=Array.from(document.querySelectorAll('.archive-day'));
      if(!links.length)return;
      const title=document.getElementById('edition-title');
      const meta=document.getElementById('edition-meta');
      const openLink=document.getElementById('open-edition');
      let resizeObserver=null;
      function fitFrame(){
        try{
          const doc=frame.contentDocument;
          if(!doc)return;
          doc.documentElement.style.backgroundColor='#fff';
          if(doc.body)doc.body.style.backgroundColor='#fff';
          const card=doc.querySelector('.card');
          const preview=doc.querySelector('#pvh');
          const scroll=doc.defaultView?doc.defaultView.scrollY:0;
          const cardBottom=card?card.getBoundingClientRect().bottom+scroll:0;
          const previewBottom=preview?preview.getBoundingClientRect().bottom+scroll:0;
          const height=Math.max(doc.documentElement.scrollHeight,doc.body?doc.body.scrollHeight:0,cardBottom,previewBottom);
          frame.style.height=Math.max(820,height+32)+'px';
        }catch(e){}
      }
      function watchFrame(){
        fitFrame();
        try{
          const doc=frame.contentDocument;
          if(resizeObserver)resizeObserver.disconnect();
          if(doc&&'ResizeObserver' in window){
            resizeObserver=new ResizeObserver(fitFrame);
            resizeObserver.observe(doc.documentElement);
            const card=doc.querySelector('.card');
            if(card)resizeObserver.observe(card);
          }
          if(doc&&doc.fonts&&doc.fonts.ready)doc.fonts.ready.then(fitFrame);
        }catch(e){}
      }
      function selectEdition(link,updateHash){
        const src=link.href;
        title.textContent=link.dataset.title;
        meta.textContent='Daily AI briefing | '+link.dataset.title;
        openLink.href=src;
        frame.title=link.dataset.title+' - The Morning Post';
        links.forEach(function(item){if(item===link)item.setAttribute('aria-current','page');else item.removeAttribute('aria-current');});
        const month=link.closest('.archive-month');
        const days=link.closest('.archive-days');
        const toggle=month?month.querySelector('.archive-month-toggle'):null;
        if(toggle)toggle.setAttribute('aria-expanded','true');
        if(days)days.hidden=false;
        if(frame.src!==src)frame.src=src;
        if(updateHash)history.replaceState(null,'','#'+link.dataset.iso);
      }
      document.querySelectorAll('.archive-month-toggle').forEach(function(toggle){
        toggle.addEventListener('click',function(){
          const expanded=toggle.getAttribute('aria-expanded')==='true';
          const days=document.getElementById(toggle.getAttribute('aria-controls'));
          toggle.setAttribute('aria-expanded',String(!expanded));
          if(days)days.hidden=expanded;
        });
      });
      links.forEach(function(link){link.addEventListener('click',function(event){event.preventDefault();selectEdition(link,true);});});
      let initial=null;
      try{const requested=decodeURIComponent(location.hash.slice(1));initial=links.find(function(link){return link.dataset.iso===requested;})||null;}catch(e){}
      initial=initial||links.find(function(link){return link.getAttribute('aria-current')==='page';})||links[0];
      selectEdition(initial,false);
      frame.addEventListener('load',watchFrame);
      window.addEventListener('resize',fitFrame);
      setTimeout(watchFrame,500);
    })();
  </script>
</body>
</html>
"@
[System.IO.File]::WriteAllText($outputPath, $page, [System.Text.UTF8Encoding]::new($false))

$siteRoot = 'https://eskillsai.github.io/The-Morning-Post/'
$feedPath = Join-Path (Split-Path -Parent $archiveRoot) 'feed.xml'
$settings = [System.Xml.XmlWriterSettings]::new()
$settings.Encoding = [System.Text.UTF8Encoding]::new($false)
$settings.Indent = $true
$writer = [System.Xml.XmlWriter]::Create($feedPath, $settings)
try {
    $writer.WriteStartDocument()
    $writer.WriteStartElement('rss')
    $writer.WriteAttributeString('version', '2.0')
    $writer.WriteStartElement('channel')
    $writer.WriteElementString('title', 'The Morning Post - eSkillsAI')
    $writer.WriteElementString('link', $siteRoot)
    $writer.WriteElementString('description', 'Daily updates on artificial intelligence advancements from eSkillsAI.')
    $writer.WriteElementString('language', 'en')
    $writer.WriteElementString('lastBuildDate', [datetime]::UtcNow.ToString('r', $culture))
    $writer.WriteElementString('generator', 'eSkillsAI Morning Post archive publisher')
    foreach ($post in $posts) {
        $encodedName = [System.Uri]::EscapeDataString($post.FileName)
        $link = $siteRoot + 'archives/' + $encodedName
        $dateLabel = $post.Date.ToString('MMMM d, yyyy', $culture)
        $writer.WriteStartElement('item')
        $writer.WriteElementString('title', 'The Morning Post - ' + $dateLabel)
        $writer.WriteElementString('link', $link)
        $writer.WriteStartElement('guid')
        $writer.WriteAttributeString('isPermaLink', 'true')
        $writer.WriteString($link)
        $writer.WriteEndElement()
        $writer.WriteElementString('pubDate', $post.LastWriteTimeUtc.ToString('r', $culture))
        $writer.WriteElementString('description', 'Read the full AI advancement news edition on the eSkillsAI Morning Post website.')
        $writer.WriteEndElement()
    }
    $writer.WriteEndElement()
    $writer.WriteEndElement()
    $writer.WriteEndDocument()
} finally {
    $writer.Dispose()
}
