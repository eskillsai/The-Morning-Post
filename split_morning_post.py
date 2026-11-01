#!/usr/bin/env python3
"""
Split the eskillsai Morning Post Studio into two standalone pages:

  editorial.html -> LEFT side  (the editing form)
  content.html   -> RIGHT side (the live card preview + PNG/PDF download)

The two pages stay in sync through localStorage / BroadcastChannel:
edit in editorial.html, and content.html updates live.

Usage:
    python split_morning_post.py [optional_src_file_path] [out_dir]
"""
import re
import sys
import pathlib
import datetime

# --- FIXED FILENAME LOGIC ---
if len(sys.argv) > 1:
    src = pathlib.Path(sys.argv)
else:
    current_dir = pathlib.Path(".")
    pattern = "eskillsai Morning Post Studio — *.html"
    
    # Sort files by modification time so the newest matching file is last
    matching_files = sorted(current_dir.glob(pattern), key=lambda p: p.stat().st_mtime)
    
    if not matching_files:
        sys.exit(f"Error: No file found matching '{pattern}' in the current directory:\n{current_dir.resolve()}")
        
    src = matching_files[-1]

# Set up output folder
out = pathlib.Path(sys.argv if len(sys.argv) > 2 else "split_output")
out.mkdir(parents=True, exist_ok=True)

print(f"Reading source file: {src.name}")
html = src.read_text(encoding="utf-8")


def must(m, what):
    if not m:
        sys.exit(f"Could not find {what} in {src.name}")
    return m


# ---------- pull the pieces out of the original file ----------
css = must(re.search(r"<style>(.*?)</style>", html, re.S), "<style>").group(1)
js = must(re.search(r"<script>(.*?)</script>", html, re.S), "inline <script>").group(1)
font_link = must(re.search(r'<link rel="stylesheet"[^>]+>', html), "font <link>").group(0)
lib_scripts = "\n".join(re.findall(r'<script src="[^"]+"></script>', html))


def idx(marker):
    i = js.find(marker)
    if i < 0:
        sys.exit(f"Marker not found in script: {marker}")
    return i


i_refs = idx("const $=s=>")          # DOM refs start
i_card = idx("const safeUrl=")       # card (RIGHT side) helpers start
i_edit = idx("const fld=")           # editor (LEFT side) start
i_dl = idx("let dl=null;")           # download code start
i_init = idx("buildEditor();render();initDl();")

core = js[:i_refs]                   # LOGO, COLORS, KEY, sample, load/persist, S
card = js[i_card:i_edit]             # safeUrl, lk, curBlock, cardHTML, fit, render
edit = js[i_edit:i_dl]               # fld, inp, ta, buildEditor, onEdit, handlers
dl = js[i_dl:i_init]                 # initDl, grab, exportAs

shared_lines = [l for l in js.splitlines()
                if l.startswith("const esc=") or l.startswith("const today=")]
shared = "\n".join(shared_lines)

# --- DYNAMIC DATE OVERWRITE ---
today_str = datetime.date.today().strftime("%B %d, %Y")
core = core.replace('"October 31, 2026"', f'"{today_str}"')
core = core.replace("'October 31, 2026'", f"'{today_str}'")

# --- MOBILE RESPONSIVENESS & BLOGGER DATE HIDING RULES ---
css += """
/* 1. Hide Blogger's internal hardcoded dates */
.date-header, .post-timestamp, .post-meta, .post-header-line-1, .header-date { 
    display: none !important; 
}

/* 2. Overwrite fixed sizing to force full device mobile scaling responsiveness */
#pv, .card {
    max-width: 1080px !important;
}
@media (max-width: 1120px) {
    #pvh {
        overflow: visible !important;
        display: flex !important;
        justify-content: center !important;
    }
    #pv, .card {
        width: 100% !important;
        min-height: auto !important;
        transform: none !important;
        position: relative !important;
    }
    .c-top, .c-hero, .c-body, .c-foot {
        padding: 20px !important;
    }
    .c-hero h1 {
        font-size: 32px !important;
    }
    .c-h {
        font-size: 24px !important;
    }
    .c-ih {
        font-size: 20px !important;
    }
    .c-is {
        font-size: 16px !important;
    }
    .c-q {
        font-size: 16px !important;
        padding: 15px !important;
    }
}
"""

# ---------- LEFT: editorial.html ----------
core_editor = re.sub(r'const LOGO="[^"]*";', 'const LOGO="";', core)

editor_js = (
    core_editor
    + 'const $=s=>document.querySelector(s), ed=$("#ed");\n'
    + shared + "\n"
    + 'const bc=(()=>{try{return new BroadcastChannel(KEY)}catch(e){return null}})();\n'
    + 'function render(){persist();if(bc)bc.postMessage("u")}\n'
    + edit
    + "\nbuildEditor();render();\n"
)

editor_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>eskillsai Morning Post - Editorial</title>
{font_link}
<style>
{css}
.app{{grid-template-columns:minmax(0,1fr);max-width:680px}}
</style>
</head>
<body>
<div class="app"><div><div id="ed"></div></div></div>
<script>
{editor_js}
</script>
</body>
</html>
"""

# ---------- RIGHT: content.html ----------
card = card.replace("fit();persist()}", "fit()}")

dl = dl.replace(
    "let dl=null;",
    "let dl=null;const localSave={save:async({filename,data})=>{const a=document.createElement('a');"
    "a.href=URL.createObjectURL(data);a.download=filename;document.body.appendChild(a);a.click();"
    "a.remove();setTimeout(()=>URL.revokeObjectURL(a.href),1000)}};",
)
dl = dl.replace("catch(e){dl=null}", "catch(e){dl=null}\n if(!dl)dl=localSave;")

content_js = (
    core
    + 'const $=s=>document.querySelector(s), pv=$("#pv"), pvh=$("#pvh"), msg=$("#msg"), xhost=$("#xhost");\n'
    + shared + "\n"
    + card
    + dl
    + """
function reload(){const v=load();if(v){S=v;render()}}
window.addEventListener("storage",e=>{if(e.key===KEY)reload()});
try{new BroadcastChannel(KEY).onmessage=reload}catch(e){}
render();initDl();
if(document.fonts&&document.fonts.ready)document.fonts.ready.then(fit);
"""
)

content_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>eskillsai Morning Post - Content</title>
{font_link}
{lib_scripts}
<style>
{css}
.app{{grid-template-columns:minmax(0,1fr);max-width:1120px}}
.pvbox{{position:static}}
</style>
</head>
<body>
<div class="app"><div>
 <div class="tools"><button class="dl" data-x="png" disabled>Download PNG</button><button class="dl" data-x="pdf" disabled>Download PDF</button><span class="msg" id="msg"></span></div>
 <div class="pvbox"><div id="pvh"><div id="pv"></div></div></div>
</div></div>
<div id="xhost"></div>
<script>
{content_js}
</script>
</body>
</html>
"""

editor_html = editor_html.replace("October 31, 2026", today_str)
content_html = content_html.replace("October 31, 2026", today_str)

(out / "editorial.html").write_text(editor_html, encoding="utf-8")
(out / "content.html").write_text(content_html, encoding="utf-8")
print(f"Wrote {out/'editorial.html'}  (left side: editor)")
print(f"Wrote {out/'content.html'}    (right side: preview + downloads)")
