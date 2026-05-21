#!/usr/bin/env bash
# repo-automation/tests/docs-check.sh

set -u
set -o pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$script_dir/../lib/common.sh"

docs_check_quiet=0
docs_check_explain=0

docs_check_usage() {
  printf 'Usage: repo-automation/tests/docs-check.sh [--quiet] [--explain] [--help]\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet)
      docs_check_quiet=1
      ;;
    --explain)
      docs_check_explain=1
      ;;
    --help)
      docs_check_usage
      exit 0
      ;;
    --*)
      repo_auto_flag_error "unknown flag" "$1" "run repo-automation/tests/docs-check.sh --help" >&2
      exit 1
      ;;
    *)
      repo_auto_stop "unknown argument: $1"
      exit 1
      ;;
  esac
  shift
done

repo_root="$(cd "$script_dir/../.." && pwd)"

DOCS_CHECK_QUIET="$docs_check_quiet" DOCS_CHECK_EXPLAIN="$docs_check_explain" python3 - "$repo_root" <<'PY'
from pathlib import Path
from urllib.parse import unquote
import re
import os
import sys

repo_root = Path(sys.argv[1]).resolve()
quiet = os.environ.get('DOCS_CHECK_QUIET') == '1'
explain = os.environ.get('DOCS_CHECK_EXPLAIN') == '1'
link_pattern = re.compile(r'(?<!\!)\[[^\]]+\]\(([^)]+)\)')
markdown_suffixes = {'.md', '.markdown'}
text_suffixes = {'.md', '.markdown', '.yml', '.yaml', '.sh', '.txt'}
skip_dirs = {'.git', '.hg', '.svn', '.tox', '__pycache__'}
fence_pattern = re.compile(r'^[ \t]{0,3}(`{3,}|~{3,})')
heading_pattern = re.compile(r'^[ \t]{0,3}#{1,6}\s+\S')
trailing_whitespace_pattern = re.compile(r'[ \t]+$', re.M)
portability_allow_marker = 'portability:allow'
portability_targets = {
    'README.md',
    'repo-automation/docs',
    'examples',
}
gnu_flag_checks = [
    (re.compile(r'\bsed\s+-r\b'), 'use sed -E or a portable equivalent'),
    (re.compile(r'\bgrep\s+-P\b'), 'use grep -E or a portable equivalent'),
    (re.compile(r'\bfind\b.*\s-printf\b'), 'use a portable find pipeline without -printf'),
    (re.compile(r'\bstat\s+-c\b'), 'use a portable stat alternative or shell globbing'),
    (re.compile(r'\bxargs\s+-r\b'), 'drop -r or guard the pipeline explicitly'),
    (re.compile(r'\breadlink\s+-f\b'), 'use a repo helper or a portable path resolver'),
    (re.compile(r'\bdate\s+-I\b'), 'spell out the date format explicitly'),
    (re.compile(r'\bsort\s+-V\b'), 'use a portable sort key or document the GNU dependency'),
]


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
    failures.append((category, message))


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


def check_readme_integrity():
    path = repo_root / 'README.md'
    text = path.read_text(encoding='utf-8', errors='ignore')
    required_fragments = [
        'Current version:',
        'docs/INDEX.md',
        'docs/VERSIONING.md',
        'repo-automation/docs/version-modes.md',
        'repo-automation/bin/run-tests',
        'repo-automation/bin/repo-doctor',
        'repo-automation/bin/prepare-release',
        'repo-automation/bin/automation-freshness',
        'repo-automation/bin/touched-files',
        'repo-automation/bin/ci-log-dump',
    ]
    missing = [fragment for fragment in required_fragments if fragment not in text]
    if missing:
        fail('readme integrity', 'missing required text in README.md: ' + ', '.join(missing))


def check_phrase_group(category, phrases, *, allowed_paths=None):
    for phrase in phrases:
        hits = []
        for path in iter_files(text_suffixes):
            rel_path = rel(path)
            if rel_path == 'repo-automation/tests/docs-check.sh':
                continue
            if allowed_paths is not None and rel_path not in allowed_paths:
                continue
            text = path.read_text(encoding='utf-8', errors='ignore')
            if phrase.lower() in text.lower():
                hits.append(rel_path)
        if hits:
            fail(category, f'"{phrase}" found in: ' + ', '.join(sorted(set(hits))))


def check_markdown_formatting():
    for path in iter_files(markdown_suffixes):
        rel_path = rel(path)
        text = path.read_text(encoding='utf-8', errors='ignore')
        if not text.endswith('\n'):
            fail('markdown formatting', f'{rel_path} does not end with a newline')
        if trailing_whitespace_pattern.search(text):
            fail('markdown formatting', f'{rel_path} has trailing whitespace')

        lines = text.splitlines()
        in_fence = False
        fence_char = None
        fence_len = 0
        for index, line in enumerate(lines):
            fence_match = fence_pattern.match(line)
            if fence_match:
                fence = fence_match.group(1)
                if not in_fence:
                    in_fence = True
                    fence_char = fence[0]
                    fence_len = len(fence)
                    continue
                if fence[0] == fence_char and len(fence) >= fence_len:
                    in_fence = False
                    fence_char = None
                    fence_len = 0
                    continue
            if in_fence:
                continue
            if heading_pattern.match(line):
                if index > 0 and lines[index - 1].strip():
                    fail('markdown formatting', f'{rel_path} heading on line {index + 1} is missing a blank line before it')
                if index + 1 >= len(lines) or lines[index + 1].strip():
                    fail('markdown formatting', f'{rel_path} heading on line {index + 1} is missing a blank line after it')
        if in_fence:
            fail('markdown formatting', f'{rel_path} has an unbalanced fenced code block')


def check_portability_examples():
    for path in iter_files(text_suffixes):
        rel_path = rel(path)
        if rel_path == 'repo-automation/docs/CHANGELOG.md':
            continue
        if not (
            rel_path == 'README.md'
            or rel_path.startswith('repo-automation/docs/')
            or rel_path.startswith('examples/')
        ):
            continue

        text = path.read_text(encoding='utf-8', errors='ignore')
        for line in text.splitlines():
            if portability_allow_marker in line:
                continue
            if '/tmp' in line:
                fail('portability examples', f'path: {rel_path}; fix: replace /tmp with ${{TMPDIR:-$HOME/.cache}}')
                break
            if '/var/tmp' in line:
                fail('portability examples', f'path: {rel_path}; fix: replace /var/tmp with ${{TMPDIR:-$HOME/.cache}}')
                break
            for pattern, fix in gnu_flag_checks:
                if pattern.search(line):
                    fail('portability examples', f'path: {rel_path}; fix: {fix}')
                    break
            else:
                continue
            break

check_local_links()
check_docs_index_coverage()
check_public_entry_points()
check_readme_integrity()
check_phrase_group('stale phrasing', [
    ''.join(['docs-first ', 'bootstrap']),
    ''.join(['most script implementation']),
    ''.join(['initial scaffold']),
    ''.join(['helper scaffold']),
], allowed_paths=None)
check_phrase_group('stale public release framing', [
    ''.join(['future scripts']),
], allowed_paths={'README.md'})
check_phrase_group('forbidden public phrase', [
    ''.join(['Prompt Template ', 'V1']),
    ''.join(['Heartloom ', 'Identity']),
])
check_markdown_formatting()
check_portability_examples()

if failures:
    if quiet:
        category, message = failures[0]
        print(f'FAIL: docs-check: {category}: {message}')
    else:
        for category, message in failures:
            print(f'FAIL: docs-check: {category}: {message}')
    sys.exit(1)

if explain:
    print('PASS: docs checks passed')
    print('PASS: local markdown links')
    print('PASS: docs index coverage')
    print('PASS: public entry points')
    print('PASS: readme integrity')
    print('PASS: phrase scans')
    print('PASS: markdown formatting')
elif not quiet:
    print('pass')
PY
status=$?
exit "$status"
# repo-automation/tests/docs-check.sh EOF
