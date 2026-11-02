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
$dateNavMarkup = ''
$latestHref = ''
$latestLabel = ''
$editionCount = $posts.Count
if ($editionCount -gt 0) {
    $latest = $posts[0]
    $latestHref = [System.Uri]::EscapeDataString($latest.FileName)
    $latestLabel = [System.Net.WebUtility]::HtmlEncode($latest.Date.ToString('MMMM d, yyyy', $culture))
    $dateLines = [System.Collections.Generic.List[string]]::new()
    $yearGroups = @($posts | Group-Object { $_.Date.ToString('yyyy', $culture) })
    $yearIndex = 0

    foreach ($yearGroup in $yearGroups) {
        $yearPosts = @($yearGroup.Group | Sort-Object Date -Descending)
        $year = $yearPosts[0].Date.ToString('yyyy', $culture)
        $yearId = 'year-' + $year
        $months = @($yearPosts | Group-Object { $_.Date.ToString('yyyy-MM', $culture) })
        $yearCount = $months.Count
        $yearCountLabel = if ($yearCount -eq 1) { '1 month' } else { "$yearCount months" }
        $yearExpanded = if ($yearIndex -eq 0) { 'true' } else { 'false' }

        $dateLines.Add('    <section class="archive-year">')
        $dateLines.Add("      <h2 class=`"archive-year-heading`"><button class=`"archive-year-toggle`" type=`"button`" aria-expanded=`"$yearExpanded`" aria-controls=`"$yearId`"><span class=`"archive-year-name`">$year</span><span class=`"archive-year-count`">$yearCountLabel</span><span class=`"archive-year-chevron`" aria-hidden=`"true`"></span></button></h2>")
        $yearHidden = if ($yearExpanded -eq 'true') { '' } else { ' hidden' }
        $dateLines.Add("      <div class=`"archive-year-months`" id=`"$yearId`"$yearHidden>")
        $monthIndex = 0

        foreach ($monthGroup in $months) {
            $monthPosts = @($monthGroup.Group | Sort-Object Date -Descending)
            $monthDate = $monthPosts[0].Date
            $monthLabel = $monthDate.ToString('MMMM', $culture)
            $monthId = 'month-' + $monthDate.ToString('yyyy-MM', $culture)
            $monthCount = $monthPosts.Count
            $countLabel = if ($monthCount -eq 1) { '1 edition' } else { "$monthCount editions" }
            $monthExpanded = if ($yearIndex -eq 0 -and $monthIndex -eq 0) { 'true' } else { 'false' }

            $dateLines.Add('        <section class="archive-month">')
            $dateLines.Add("          <h3 class=`"archive-month-heading`"><button class=`"archive-month-toggle`" type=`"button`" aria-expanded=`"$monthExpanded`" aria-controls=`"$monthId`"><span class=`"archive-month-name`">$monthLabel</span><span class=`"archive-month-count`">$countLabel</span><span class=`"archive-month-chevron`" aria-hidden=`"true`"></span></button></h3>")
            $monthHidden = if ($monthExpanded -eq 'true') { '' } else { ' hidden' }
            $dateLines.Add("          <ul class=`"archive-days`" id=`"$monthId`"$monthHidden>")

            foreach ($post in $monthPosts) {
                $href = [System.Uri]::EscapeDataString($post.FileName)
                $dateIso = $post.Date.ToString('yyyy-MM-dd', $culture)
                $dateLabel = [System.Net.WebUtility]::HtmlEncode($post.Date.ToString('MMMM d, yyyy', $culture))
                $weekday = [System.Net.WebUtility]::HtmlEncode($post.Date.ToString('ddd', $culture))
                $dayNumber = $post.Date.ToString('dd', $culture)
                $current = if ($post.FileName -eq $latest.FileName) { ' aria-current="page"' } else { '' }
                $dateLines.Add("            <li><a class=`"archive-day`" href=`"$href`" data-iso=`"$dateIso`" data-title=`"$dateLabel`" aria-label=`"$dateLabel edition`"$current><span class=`"archive-day-date`"><span class=`"archive-day-number`">$dayNumber</span><span class=`"archive-day-weekday`">$weekday</span></span><span class=`"archive-day-action`">Read <span aria-hidden=`"true`">&rarr;</span></span></a></li>")
            }

            $dateLines.Add('          </ul>')
            $dateLines.Add('        </section>')
            $monthIndex++
        }

        $dateLines.Add('      </div>')
        $dateLines.Add('    </section>')
        $yearIndex++
    }
    $dateNavMarkup = $dateLines -join "`r`n"
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
  <link rel="stylesheet" href="../site.css?v=20261102-5">
  <link rel="alternate" type="application/rss+xml" title="The Morning Post RSS" href="../feed.xml">
</head>
<body class="archive-body">
  <main class="archive-shell">
    <div class="archive-topline">
      <a class="archive-brand" href="../" aria-label="The Morning Post home"><span class="archive-brand-mark" aria-hidden="true"><svg viewBox="0 0 64 64" fill="none"><path d="M21 27a11 11 0 0 1 22 0M32 5v7M17 11l4 7M47 11l-4 7M8 25l8 2M56 25l-8 2" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/><path d="M7 32c9-3 18-1 25 5v20c-7-6-16-8-25-5V32Zm50 0c-9-3-18-1-25 5v20c7-6 16-8 25-5V32Z" fill="rgba(255,255,255,.08)" stroke="currentColor" stroke-width="2.6" stroke-linejoin="round"/><path d="M13 38c6-1 11 0 15 3M13 45c6-1 11 0 15 3M51 38c-6-1-11 0-15 3M51 45c-6-1-11 0-15 3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg></span><span><strong>The Morning Post</strong><small>by eSkillsAI</small></span></a>
      <section class="archive-intro" aria-labelledby="archive-title">
        <h1 id="archive-title">Explore the archive</h1>
        <p>Browse daily briefings by year, month, and date.</p>
      </section>
      <a class="archive-return" href="../"><span aria-hidden="true">&larr;</span> Today's edition</a>
    </div>
    <div class="archive-layout">
      <aside class="archive-sidebar" aria-label="Archive navigation">
        <div class="archive-sidebar-heading"><div><p class="archive-sidebar-title">Browse by Date</p><p class="archive-sidebar-count">$editionCountLabel</p></div><span class="archive-calendar-mark" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5" stroke="currentColor" stroke-width="1.7"/><path d="M7.5 3.5v3M16.5 3.5v3M3.5 9.5h17M8 13h.01M12 13h.01M16 13h.01M8 16.5h.01M12 16.5h.01M16 16.5h.01" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></span></div>
        <nav class="archive-date-nav" aria-label="Archive by year, month and date">
$(if ($editionCount -gt 0) { $dateNavMarkup } else { '          <p class="archive-no-posts">No archived editions yet.</p>' })
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
        const year=link.closest('.archive-year');
        const yearMonths=link.closest('.archive-year-months');
        const yearToggle=year?year.querySelector('.archive-year-toggle'):null;
        if(yearToggle)yearToggle.setAttribute('aria-expanded','true');
        if(yearMonths)yearMonths.hidden=false;
        const month=link.closest('.archive-month');
        const days=link.closest('.archive-days');
        const toggle=month?month.querySelector('.archive-month-toggle'):null;
        if(toggle)toggle.setAttribute('aria-expanded','true');
        if(days)days.hidden=false;
        if(frame.src!==src)frame.src=src;
        if(updateHash)history.replaceState(null,'','#'+link.dataset.iso);
      }
      document.querySelectorAll('.archive-year-toggle, .archive-month-toggle').forEach(function(toggle){
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
