"""Read-only exhaustive declaration diff for the two scoped Upheaval unit folders.

This compares XML facts, not runtime parity or native engine CPU implementation.
Output belongs under refs; no source XML is modified and no MOD script is run.
"""
import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[2]
EA = ROOT / 'refs/ea-modding-support/Uprising/Xml'
ZIP = ROOT / 'refs/ra3-expansion/upheaval/ra3-upheaval-source-code.zip'
UNITS = ['Future Tank X-1', 'Harbinger Gunship']


def tag(e):
    return e.tag.split('}')[-1]


def flatten(e, prefix=''):
    result = {prefix + '/@' + k.split('}')[-1]: v for k, v in e.attrib.items()}
    if e.text and e.text.strip():
        result[prefix + '/text'] = e.text.strip()
    counts = Counter()
    for child in e:
        name = tag(child)
        identity = child.get('id')
        if identity is None:
            identity = str(counts[name])
        counts[name] += 1
        result.update(flatten(child, prefix + '/' + name + '[' + identity + ']'))
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    index = defaultdict(list)
    parse_errors = []
    for path in EA.rglob('*.xml'):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            parse_errors.append({'file': path.relative_to(EA).as_posix(), 'error': str(exc)})
            continue
        for e in root:
            if e.get('id'):
                index[(tag(e), e.get('id'))].append((path.relative_to(EA).as_posix(), e))
    rows, files = [], {}
    with ZipFile(ZIP) as archive:
        for name in archive.namelist():
            unit = next((u for u in UNITS if name.startswith('Upheaval/Data/Mod/Units/' + u + '/')), None)
            if unit is None or not name.endswith('.xml'):
                continue
            raw = archive.read(name)
            files[name] = hashlib.sha256(raw).hexdigest()
            for e in ET.fromstring(raw):
                if not e.get('id'):
                    continue
                a = flatten(e)
                candidates = index[(tag(e), e.get('id'))]
                # Report all matches; no silent winner when declarations are ambiguous.
                comparisons = []
                for path, other in candidates:
                    b = flatten(other)
                    differences = [{'path': k, 'ea': b.get(k), 'upheaval': a.get(k)}
                                   for k in sorted(a.keys() | b.keys()) if a.get(k) != b.get(k)]
                    comparisons.append({'ea_file': path, 'differences': differences})
                rows.append({'unit': unit, 'file': name, 'type': tag(e), 'id': e.get('id'),
                    'status': 'not_in_ea_xml' if not candidates else ('identical' if any(not c['differences'] for c in comparisons) else 'different'),
                    'upheaval': a, 'ea_candidates': comparisons})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result = {'package_sha256': hashlib.sha256(ZIP.read_bytes()).hexdigest(), 'files': files,
              'parse_errors': parse_errors, 'rows': rows,
              'scope': 'Every root declaration in both unit folders; inheritance links retained, not flattened as runtime defaults'}
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    for unit in UNITS:
        subset = [r for r in rows if r['unit'] == unit]
        print(unit, len({r['file'] for r in subset}), 'files', len(subset), 'declarations', dict(Counter(r['status'] for r in subset)))
    print('EA parse errors:', len(parse_errors), 'report:', args.output)


if __name__ == '__main__':
    main()
