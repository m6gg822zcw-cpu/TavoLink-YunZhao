#!/usr/bin/env python3
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
checks = []

def jpeg_size(path):
    data = path.read_bytes()
    if len(data) < 4 or data[:2] != b'\xff\xd8':
        return None
    offset = 2
    sof_markers = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
    while offset + 4 <= len(data):
        if data[offset] != 0xFF:
            offset += 1
            continue
        marker = data[offset + 1]
        offset += 2
        if marker in {0xD8, 0xD9}:
            continue
        if offset + 2 > len(data):
            break
        length = int.from_bytes(data[offset:offset + 2], 'big')
        if length < 2 or offset + length > len(data):
            break
        if marker in sof_markers and length >= 7:
            height = int.from_bytes(data[offset + 3:offset + 5], 'big')
            width = int.from_bytes(data[offset + 5:offset + 7], 'big')
            return width, height
        offset += length
    return None

def ok(name, condition, detail=''):
    checks.append((name, bool(condition), detail))
    if not condition:
        errors.append(name + (f': {detail}' if detail else ''))

pub = (ROOT/'pubspec.yaml').read_text()
ok('pubspec version 1.1.0', 'version: 1.1.0+2' in pub)
ok('YunZhao asset declared', 'assets/images/yunzhao_hero.jpg' in pub)
asset = ROOT/'assets/images/yunzhao_hero.jpg'
ok('YunZhao asset exists', asset.exists())
if asset.exists():
    dimensions = jpeg_size(asset)
    ok('YunZhao asset readable', dimensions is not None and dimensions[0] >= 600 and dimensions[1] >= 700, f'{dimensions}')

all_dart = list((ROOT/'lib').rglob('*.dart'))
source = '\n'.join(p.read_text() for p in all_dart)
for dart_file in all_dart:
    text = dart_file.read_text()
    for imp in re.findall(r"import 'package:tavolink/([^']+)'", text):
        ok(f'local import {imp}', (ROOT/'lib'/imp).exists(), str(dart_file.relative_to(ROOT)))
ok('No demo empty onPressed', 'onPressed: () {}' not in source)
ok('No demo empty onTap', 'onTap: () {}' not in source)
ok('YunZhao identity present', source.count('云昭') >= 8, f'count={source.count("云昭")}')
ok('MCP stateless protocol present', '2026-07-28' in source)
ok('MCP legacy fallback present', '2025-11-25' in source)
ok('Tavo direct JSON-RPC fallback present', 'direct-jsonrpc' in source)
ok('MCP tool calling present', 'tools/call' in source)
ok('OpenAI tool calling present', 'tool_calls' in source and 'tool_choice' in source)
ok('Search tool present', 'web_search' in source)
ok('Secure storage present', 'FlutterSecureStorage' in source)
ok('Learning core present', 'class LearningService' in source and 'class LearningRepository' in source)
ok('Layered memory kinds present', all(x in source for x in ['MemoryKind.preference', 'MemoryKind.project', 'MemoryKind.toolLesson']))
ok('Learning retrieval injected', 'buildContext(userText)' in source and 'yunzhao_relevant_memory' in source)
ok('AI memory extraction present', '云昭长期记忆提取器' in source)
ok('Tool experience learning present', 'recordToolOutcome' in source and 'recordTool(' in source)
ok('Learning secret filter present', 'looksLikeSecret' in source and 'Bearer ***' in source)
ok('Memory poisoning evidence guard present', 'acceptExtracted' in source and "map['evidence']" in source and 'userText.contains(cleanEvidence)' in source)
ok('No obvious hard-coded secret', not re.search(r'(sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9_-]{20,})', source))

# Raw delimiters are still useful here because the project contains no bracket-heavy
# code samples in comments; this catches accidental truncation during generation.
for p in all_dart:
    s = p.read_text()
    for left, right in [('(', ')'), ('[', ']'), ('{', '}')]:
        ok(f'delimiters {p.relative_to(ROOT)} {left}{right}', s.count(left) == s.count(right), f'{s.count(left)}:{s.count(right)}')

for rel in [
    '.metadata',
    'pubspec.lock',
    'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'android/gradle/wrapper/gradle-wrapper.jar',
    'ios/Runner.xcodeproj/project.pbxproj',
    'ios/Runner/Info.plist',
    'tool/bootstrap_platforms.sh',
    'tool/patch_platforms.py',
    '.github/workflows/flutter.yml',
    'lib/features/agent/agent_service.dart',
    'test/mcp_client_test.dart',
    'test/openai_client_test.dart',
    'test/learning_similarity_test.dart',
    'test/learning_guard_test.dart',
    'lib/features/learning/learning_guard.dart',
    'lib/features/learning/learning_service.dart',
    'lib/features/learning/learning_page.dart',
    '.github/workflows/release-mobile.yml',
    'tool/learning_contract_test.py',
    'tool/final_test.py',
]:
    ok(f'file {rel}', (ROOT/rel).exists())

print('\nTavoLink v1 source self-check')
for name, passed, detail in checks:
    print(('PASS' if passed else 'FAIL').ljust(5), name, detail)
print(f'\nSummary: {len(checks)-len(errors)}/{len(checks)} passed')
if errors:
    print(json.dumps(errors, ensure_ascii=False, indent=2))
    sys.exit(1)
