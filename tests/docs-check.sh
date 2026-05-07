#!/usr/bin/env bash
# tests/docs-check.sh

set -u
set -o pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$repo_root" <<'PY'
from pathlib import Path
from urllib.parse import unquote
import re
import sys

repo_root = Path(sys.argv[1]).resolve()
link_pattern = re.compile(r'(?<!\!)\[[^\]]+\]\(([^)]+)\)')
markdown_suffixes = {'.md', '.markdown'}
text_suffixes = {'.md', '.markdown', '.yml', '.yaml', '.sh', '.txt'}
skip_dirs = {'.git', '.hg', '.svn', '.tox', '__pycache__'}

def rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(repo_root))
    except ValueError:
        return str(path)

def normalize_target(raw: str):
    target = raw.strip()
    if not target:
        return None
    if target.startswith('<') and target.endswith('>'):
        target = target[1:-1].strip()
    if not target:
        return None
    lowered = target.lower()
    if target.startswith('#') or lowered.startswith(('http://', 'https://', 'mailto:', 'tel:')):
        return None
    target = target.split('#', 1)[0].split('?', 1)[0].strip()
    if not target:
        return None
    return unquote(target)

def iter_files(suffixes):
    for path in repo_root.rglob('*'):
        if not path.is_file():
            continue
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.suffix.lower() in suffixes:
            yield path

failures = []

def fail(category: str, message: str):
    failures.append(f'FAIL: {category}: {message}')

def collect_link_targets(source_path: Path):
    text = source_path.read_text(encoding='utf-8', errors='ignore')
    targets = []
    for raw in link_pattern.findall(text):
        target = normalize_target(raw)
        if target is None:
            continue
        targets.append(target)
    return targets

def check_local_links():
    for path in iter_files(markdown_suffixes):
        for target in collect_link_targets(path):
            linked = (path.parent / target).resolve()
            if not linked.exists():
                fail('local links', f'{rel(path)} -> {target} -> missing {rel(linked)}')

def index_targets():
    index_path = repo_root / 'docs' / 'INDEX.md'
    targets = set()
    for target in collect_link_targets(index_path):
        linked = (index_path.parent / target).resolve()
        try:
            targets.add(str(linked.relative_to(repo_root)))
        except ValueError:
            targets.add(str(linked))
    return targets

def check_docs_index_coverage():
    covered = index_targets()
    docs_files = []
    for path in iter_files(markdown_suffixes):
        rel_path = str(path.resolve().relative_to(repo_root))
        if rel_path == 'docs/INDEX.md':
            continue
        if rel_path.startswith('docs/'):
            docs_files.append(rel_path)
    missing = sorted(p for p in docs_files if p not in covered)
    if missing:
        fail('docs index coverage', 'missing from docs/INDEX.md: ' + ', '.join(missing))

def check_public_entry_points():
    required = [
        'README.md',
        'CHANGELOG.md',
        'CONTRIBUTING.md',
        'SUPPORT.md',
        'docs/KNOWN_LIMITATIONS.md',
        'docs/WORKFLOW_AUDIT_CHECKLIST.md',
        'examples/downstream/docs/repo-automation/README.md',
        '.github/ISSUE_TEMPLATE/automation-bug.yml',
        '.github/ISSUE_TEMPLATE/automation-feature.yml',
    ]
    covered = index_targets()
    missing = [path for path in required if path not in covered]
    if missing:
        fail('public entry points', 'missing from docs/INDEX.md: ' + ', '.join(missing))

def check_phrase_group(category, phrases):
    for phrase in phrases:
        hits = []
        for path in iter_files(text_suffixes):
            text = path.read_text(encoding='utf-8', errors='ignore')
            if phrase in text:
                hits.append(rel(path))
        if hits:
            fail(category, f'"{phrase}" found in: ' + ', '.join(sorted(set(hits))))

check_local_links()
check_docs_index_coverage()
check_public_entry_points()
check_phrase_group('stale phrasing', [
    ''.join(['docs-first ', 'bootstrap']),
    ''.join(['Most script implementation is not included ', 'yet']),
    ''.join(['first scaffold ', 'form']),
])
check_phrase_group('forbidden public phrase', [
    ''.join(['Prompt Template ', 'V1']),
    ''.join(['Heartloom ', 'Identity']),
])

if failures:
    for message in failures:
        print(message)
    sys.exit(1)

print('PASS: docs checks passed')
print('PASS: local markdown links')
print('PASS: docs index coverage')
print('PASS: public entry points')
print('PASS: phrase scans')
PY
status=$?
if [ "$status" -eq 0 ]; then
  printf '%s\n' 'PASS: tests/docs-check.sh'
else
  printf '%s\n' 'FAIL: tests/docs-check.sh'
fi
exit "$status"
# tests/docs-check.sh EOF
