#!/usr/bin/env python3
"""Finish the approved temporary transfer using bounded native Git pushes.

Only missing parts are sent. A bare repo avoids duplicating the ZIP worktree.
No force pushes, credentials in arguments or third-party storage are used.
"""
import hashlib
import json
from pathlib import Path
import subprocess

PROJECT = Path(__file__).resolve().parents[1]
REPORT = PROJECT/'builds/qa-0.22/github-transfer.json'
ARCHIVE = PROJECT/'builds/Bakugan-0.22-Windows.zip'
BARE = Path('/tmp/bakugan022-git-transfer.git')
BRANCH = 'release-transfer-0.22-b'

def git(*args, data=None):
    result = subprocess.run(['git', '--git-dir='+str(BARE), *args], input=data,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=240)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', 'replace')[-2000:])
    return result.stdout.decode().strip()

def main():
    record = json.loads(REPORT.read_text())
    if not BARE.exists():
        subprocess.run(['git', 'init', '--bare', str(BARE)], check=True, capture_output=True)
        git('remote', 'add', 'origin', 'https://github.com/'+record['repo']+'.git')
        git('config', 'user.name', 'Codex')
        git('config', 'user.email', 'codex@openai.com')
        git('config', 'core.compression', '1')
        git('config', 'pack.window', '0')
        git('config', 'pack.threads', '1')
        git('config', 'gc.auto', '0')
    git('fetch', '--depth=1', 'origin', BRANCH)
    current = git('rev-parse', 'FETCH_HEAD')
    git('read-tree', current)
    sent = record.setdefault('native_git_parts', [])
    with ARCHIVE.open('rb') as source:
        for part in record['parts'][20:]:
            present = git('ls-tree', current, '--', part['name'])
            if present:
                assert part['blob'] in present, 'Existing temporary file has unexpected bytes'
                continue
            source.seek(part['index']*32*1024*1024); raw=source.read(part['bytes'])
            assert hashlib.sha256(raw).hexdigest()==part['sha256']
            blob = git('hash-object', '-w', '--stdin', data=raw)
            assert blob==part['blob']
            git('update-index','--add','--cacheinfo','100644,'+blob+','+part['name'])
            tree = git('write-tree')
            commit = git('commit-tree',tree,'-p',current,'-m',f'Approved temporary ZIP part {part["index"]}')
            git('push','origin',commit+':refs/heads/'+BRANCH)
            current=commit
            sent.append(part['index']); record['native_git_commit']=commit
            REPORT.write_text(json.dumps(record,indent=2)+'\n')
            print(f'Native Git: part {part["index"]} available ({len(sent)}/41)',flush=True)

if __name__=='__main__': main()
