import json, sys, re, pathlib
src = pathlib.Path('/root/.claude/projects/-root-claude2')
out = pathlib.Path('/root/claude2/docs/sessions')
cur = '8b8e2c0e-a8f8-4930-be58-29aceafb450a'
secret = re.compile(r'(\d{8,10}:AA[\w-]{30,}|sk-ant-[\w-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY)')
for f in sorted(src.glob('*.jsonl')):
    if f.stem == cur: continue
    lines = []; first = last = None; kind = 'chat'
    for raw in f.read_bytes().decode('utf-8', 'ignore').splitlines():
        try: d = json.loads(raw)
        except: continue
        if d.get('type') == 'queue-operation': kind = 'bot911'
        if d.get('type') not in ('user', 'assistant'): continue
        c = d.get('message', {}).get('content')
        t = c if isinstance(c, str) else ' '.join(x.get('text', '') for x in c or [] if x.get('type') == 'text')
        t = t.strip()
        if not t or t.startswith('<'): continue
        ts = d.get('timestamp', '')[:16].replace('T', ' ')
        first = first or ts; last = ts
        t = secret.sub('[секрет вырезан]', t)
        lines.append(f"### {ts} — {'Владелец' if d['type']=='user' else 'Claude'}\n\n{t}\n")
    if not lines: continue
    name = f"{first[:10]}_{last[:10]}_{kind}_{f.stem[:8]}.md"
    (out / name).write_text(f"# Сессия {f.stem} ({kind}), {first} — {last} UTC\n\n" + '\n'.join(lines), encoding='utf-8')
    print(name, len(lines), 'сообщений')
