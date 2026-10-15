"""Check a generated .sm against its .qua: every note's time must match within 2 ms."""
import sys, re, yaml, bisect
sm_path, qua_path, desc = sys.argv[1], sys.argv[2], None
qua = yaml.safe_load(open(qua_path, encoding='utf-8-sig'))
desc = qua['DifficultyName']
txt = open(sm_path, encoding='utf-8').read()
offset = float(re.search(r'#OFFSET:([^;]+);', txt).group(1))
bpms = [tuple(map(float, x.split('='))) for x in re.search(r'#BPMS:([^;]+);', txt, re.S).group(1).replace('\n','').split(',')]
def ms(beat):
    t, i = -offset * 1000, 0
    for j, (b, bpm) in enumerate(bpms):
        nb = bpms[j+1][0] if j+1 < len(bpms) else float('inf')
        if beat <= nb:
            return t + (beat - b) * 60000 / bpm
        t += (nb - b) * 60000 / bpm
for block in txt.split('#NOTES:')[1:]:
    parts = block.split(':')
    if parts[1].strip() != desc.replace(':', '\\:'):
        continue
    data = parts[5].split(';')[0].strip()
    times = []
    for m, meas in enumerate(data.split(',')):
        lines = [l for l in meas.split('\n') if l.strip() and not l.startswith('//')]
        for i, l in enumerate(lines):
            for lane, ch in enumerate(l.strip()):
                if ch in '12':
                    times.append((round(ms(4*m + 4*i/len(lines))), lane+1))
    src = sorted((h['StartTime'], h['Lane']) for h in qua['HitObjects'])
    got = sorted(times)
    err = max(abs(a[0]-b[0]) for a, b in zip(src, got)) if got else None
    print(f"{desc}: {len(src)} notes in .qua, {len(got)} in .sm, worst timing error {err} ms, lanes match {all(a[1]==b[1] for a,b in zip(src,got))}")
    break
