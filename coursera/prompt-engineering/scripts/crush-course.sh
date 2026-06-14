#!/usr/bin/env bash
set -euo pipefail

# crush-course.sh v2 — 1 command end-to-end Coursera extraction pipeline
# Tools: BROWSER_TOOL_CREATE_TASK + GOOGLEDRIVE_* + CODEINTERPRETER_EXECUTE_CODE
# Usage: bash scripts/crush-course.sh <COURSE_URL> [COURSE_NAME]

COURSE_URL="${1:?Usage: crush-course.sh <COURSE_URL> [COURSE_NAME]}"
COURSE_NAME="${2:-Course-$(date +%Y%m%d)}"
BASE="./course-output/$(echo "$COURSE_NAME" | tr ' /' '_')"
mkdir -p "$BASE"/{recon,transcripts,notes,consolidation,certificates,failed}

echo "[0] Checking connections..."
composio connections list 2>&1 | grep -q browser_tool || { echo "  Run: composio link browser_tool"; exit 1; }
composio connections list 2>&1 | grep -q googledrive || { echo "  Run: composio link googledrive"; exit 1; }
echo "  browser_tool: ok  googledrive: ok"

echo "[1] Recon: $COURSE_URL"
composio execute BROWSER_TOOL_CREATE_TASK \
  -d '{"task":"Extract ALL module names and lecture URLs from '"$COURSE_URL"'. Return JSON.","max_steps":40}' \
  --skip-checks > "$BASE/recon/syllabus.json"

python3 << PYEOF
import json, re, os
base = "$BASE"
data = json.load(open(os.path.join(base, 'recon', 'syllabus.json')))
text = json.dumps(data)
urls = list(dict.fromkeys(re.findall(r'https://[^"\\s]*coursera[^"\\s]*lecture[^"\\s]*', text)))
with open(os.path.join(base, 'recon', 'lecture_urls.txt'), 'w') as f:
    f.write('\n'.join(urls))
print(f'  Found {len(urls)} lectures')
PYEOF

echo "[2] Transcripts (batches of 4)..."
B=0
while IFS= read -r u1 && IFS= read -r u2 && IFS= read -r u3 && IFS= read -r u4; do
  B=$((B+1))
  echo "  Batch $B..."
  composio execute BROWSER_TOOL_CREATE_TASK \
    -d '{"task":"Extract transcripts from these 4 Coursera lectures. For each: navigate to URL, click Transcript button, wait 5s, capture ALL visible text. Write each transcript to a file named by video ID. URLs: '"$u1 $u2 $u3 $u4"'","max_steps":80}' \
    --skip-checks > "$BASE/transcripts/batch_$B.json"

  python3 << PYEOF
import json, re, os
base = "$BASE"
b = "$B"
data = json.load(open(os.path.join(base, 'transcripts', f'batch_{b}.json')))
text = json.dumps(data)
found = 0
for pattern in [r'Write file: ([^\\n]+)\\n```([^`]+)```', r'filename: ([^,]+), content: (.+)']:
    for m in re.finditer(pattern, text):
        fname = m.group(1).strip()
        content = m.group(2).strip()
        clen = len(content)
        status = 'complete' if clen >= 1200 else ('partial' if clen >= 400 else 'failed')
        with open(os.path.join(base, status, fname), 'w') as f: f.write(content)
        found += 1
        print(f'  {status}: {fname} ({clen}c)')
if found == 0:
    with open(os.path.join(base, 'transcripts', f'batch_{b}_raw.txt'), 'w') as f: f.write(text[:5000])
    print(f'  No files parsed. Raw output saved.')
PYEOF
done < "$BASE/recon/lecture_urls.txt"

echo "[3] Study notes..."
HAS_OPENAI=$(composio connections list 2>&1 | grep -c openai || true)
HAS_KIEAI=$(composio connections list 2>&1 | grep -c kieai || true)
for f in "$BASE"/complete/*.txt "$BASE"/partial/*.txt; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .txt)
  note_file="$BASE/notes/${base}_notes.json"
  [ -f "$note_file" ] && continue
  b64=$(python3 -c "import base64; print(base64.b64encode(open('$f','rb').read()[:8000]).decode())")
  if [ "$HAS_KIEAI" -gt 0 ]; then
    echo "  $base (KIEAI)..."
    composio execute KIEAI_EXECUTE_GPT_CODEX -d '{"messages":[{"role":"user","content":"Generate study notes JSON from this base64 transcript: '"$b64"'. Return JSON with lecture_title, module, video_number, summary, key_concepts[], patterns_techniques[{pattern_name,category,template}], quiz_questions[3]{question,options[],correct_answer,explanation}, confidence"}],"model":"gpt-5-codex"}' --skip-checks > "$note_file" 2>/dev/null
  elif [ "$HAS_OPENAI" -gt 0 ]; then
    echo "  $base (Code Interpreter)..."
    composio execute CODEINTERPRETER_EXECUTE_CODE -d '{"code_to_execute":"import json, base64, openai; client = openai.OpenAI(); b64 = \"'"$b64"'\"; text = base64.b64decode(b64).decode(\"utf-8\", errors=\"replace\"); r = client.chat.completions.create(model=\"gpt-4o\", messages=[{\"role\":\"user\",\"content\":f\"Generate study notes JSON from: {text[:3000]}\"}], response_format={\"type\":\"json_object\"}); print(r.choices[0].message.content)"}' --skip-checks > "$note_file" 2>/dev/null
  else
    echo "  SKIP $base (composio link openai or composio link kieai)"
  fi
done

echo "[4] Consolidation..."
python3 << PYEOF
import json, glob, os
base = "$BASE"
notes_dir = os.path.join(base, 'notes')
cons_dir = os.path.join(base, 'consolidation')
os.makedirs(cons_dir, exist_ok=True)
note_files = sorted(glob.glob(os.path.join(notes_dir, '*_notes.json')))
all_n = []
for f in note_files:
    try:
        with open(f) as fh: d = json.load(fh)
        if isinstance(d, dict) and 'lecture_title' in d: all_n.append(d)
    except: pass
print(f'  Processing {len(all_n)} notes...')
pat = {}
for n in all_n:
    for p in n.get('patterns_techniques', []):
        name = p.get('pattern_name', '?')
        if name not in pat: pat[name] = {'name': name, 'category': p.get('category', ''), 'lectures': [], 'templates': []}
        pat[name]['lectures'].append(n.get('lecture_title', ''))
        if p.get('template'): pat[name]['templates'].append(p['template'])
json.dump({'version': '2.0', 'patterns': list(pat.values())}, open(os.path.join(cons_dir, 'pattern_index.json'), 'w'), indent=2)
mods = {}
for n in all_n:
    m = n.get('module', '?')
    if m not in mods: mods[m] = {'module': m, 'lectures': [], 'concepts': set()}
    mods[m]['lectures'].append(n.get('lecture_title', ''))
    for c in n.get('key_concepts', []): mods[m]['concepts'].add(c)
modules_out = []
for m in sorted(mods.keys()): v = mods[m]; v['concepts'] = list(v['concepts']); modules_out.append(v)
json.dump({'version': '2.0', 'modules': modules_out}, open(os.path.join(cons_dir, 'module_summaries.json'), 'w'), indent=2)
qs = []
for n in all_n:
    for q in n.get('quiz_questions', []): q['source'] = n.get('lecture_title', ''); qs.append(q)
json.dump({'version': '2.0', 'total': len(qs), 'questions': qs}, open(os.path.join(cons_dir, 'global_quiz_bank.json'), 'w'), indent=2)
print(f'  Patterns: {len(pat)}  Modules: {len(mods)}  Questions: {len(qs)}')
PYEOF

echo "[5] Upload to Drive..."
FOLDER_ID=$(composio execute GOOGLEDRIVE_CREATE_FOLDER -d "{\"folder_name\":\"$COURSE_NAME - Study Notes\"}" --skip-checks | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('id',''))")
python3 << PYEOF
import json, os, subprocess, glob
base = "$BASE"
folder = "$FOLDER_ID"
for f in sorted(glob.glob(os.path.join(base, 'consolidation', '*.json'))):
    content = open(f).read()
    subprocess.run(['composio', 'execute', 'GOOGLEDRIVE_CREATE_FILE_FROM_TEXT', '-d', json.dumps({"file_name": os.path.basename(f), "text_content": content, "mime_type": "application/json", "parent_id": folder}), '--skip-checks'], capture_output=True, timeout=30)
    print(f'    {os.path.basename(f)}')
PYEOF
echo "  Folder: https://drive.google.com/drive/folders/$FOLDER_ID"

echo "[6] Certificate..."
composio execute BROWSER_TOOL_CREATE_TASK -d '{"task":"Go to https://www.coursera.org/account/accomplishments. Find certificate for '"$COURSE_NAME"'. Extract certificate ID. Return JSON {certificate_id:\"...\"}.","max_steps":20}' --skip-checks > "$BASE/certificates/cert.json"
CERT_ID=$(python3 -c "import json,re; t=json.dumps(json.load(open('$BASE/certificates/cert.json'))); m=re.search(r'[A-Z0-9]{10,15}',t); print(m.group() if m and not m.group().isdigit() else '')")
[ -n "$CERT_ID" ] && echo "  Certificate: $CERT_ID -> https://coursera.org/verify/$CERT_ID"
echo "=== DONE ==="
echo "  Local: $BASE"
echo "  Drive: https://drive.google.com/drive/folders/$FOLDER_ID"
echo "  Cert: ${CERT_ID:-N/A}"
