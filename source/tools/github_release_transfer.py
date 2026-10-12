#!/usr/bin/env python3
"""Send the approved release to its GitHub repo for runner-side asset upload.

The local connector authenticates api.github.com but not uploads.github.com.
Use bounded Git blobs on a disposable orphan branch; a GitHub Actions runner
assembles the exact ZIP and uploads it with its own repository token.
No credential is read, stored, printed or sent to another service by this tool.
Delete the transfer branch after verifying the release asset.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def api(repo, endpoint, payload, method='POST'):
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir='/tmp', suffix='.json') as stream:
        json.dump(payload, stream, separators=(',', ':'))
        stream.flush()
        result = subprocess.run(['gh', 'api', '--method', method,
                                 f'repos/{repo}/git/{endpoint}', '--input', stream.name],
                                capture_output=True, text=True, timeout=180)
    if result.returncode:
        try:
            detail = json.loads(result.stdout)
        except ValueError:
            detail = {}
        raise RuntimeError(f'GitHub {endpoint} failed: {result.stderr[-1000:]} {detail}')
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--branch', default='release-transfer-0.22')
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    archive = args.archive.resolve()
    chunk_bytes = 32 * 1024 * 1024
    size = archive.stat().st_size
    count = (size + chunk_bytes - 1) // chunk_bytes
    record = json.loads(args.report.read_text()) if args.report.exists() else {}
    with archive.open('rb') as stream:
        archive_hash = hashlib.file_digest(stream, 'sha256').hexdigest()
    if record and (record.get('archive_sha256') != archive_hash or record.get('repo') != args.repo):
        raise RuntimeError('Transfer report belongs to a different archive or repository')
    record.update(repo=args.repo, branch=args.branch, archive_sha256=archive_hash, bytes=size)
    parts = {p['index']: p for p in record.get('parts', [])}

    def send(index):
        with archive.open('rb') as stream:
            stream.seek(index * chunk_bytes)
            raw = stream.read(chunk_bytes)
        digest = hashlib.sha256(raw).hexdigest()
        blob_sha = hashlib.sha1(f'blob {len(raw)}\0'.encode() + raw).hexdigest()
        if index in parts:
            if parts[index]['sha256'] != digest or parts[index]['blob'] != blob_sha:
                raise RuntimeError('Saved part checksum mismatch')
            return parts[index]
        # A gateway 502 can occur after GitHub has stored the blob. Git content
        # addresses let us recover that response without retransmitting bytes.
        found = subprocess.run(['gh', 'api', '--method', 'HEAD',
                                f'repos/{args.repo}/git/blobs/{blob_sha}'],
                               capture_output=True, text=True, timeout=60)
        if found.returncode:
            response = api(args.repo, 'blobs', {'content': base64.b64encode(raw).decode('ascii'), 'encoding': 'base64'})
            if response['sha'] != blob_sha:
                raise RuntimeError('GitHub blob SHA differs from its exact local bytes')
        return dict(index=index, name=f'parts/{index:03d}.bin', bytes=len(raw), sha256=digest, blob=blob_sha)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    errors = []
    with ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(send, i) for i in range(count)]
        for job in as_completed(jobs):
            try:
                part = job.result()
            except Exception as error:
                errors.append(str(error))
                print(f'Transfer response failed: {error}', flush=True)
                continue
            parts[part['index']] = part
            record['parts'] = [parts[i] for i in sorted(parts)]
            args.report.write_text(json.dumps(record, indent=2) + '\n')
            print(f'GitHub transfer: {len(parts)}/{count} parts stored', flush=True)
    if errors:
        raise RuntimeError('Transfer incomplete; successful responses preserved: ' + '; '.join(errors))
    manifest = {'archive_name': archive.name, 'archive_sha256': archive_hash, 'bytes': size,
                'parts': record['parts']}
    manifest_blob = api(args.repo, 'blobs', {'content': json.dumps(manifest, indent=2), 'encoding': 'utf-8'})['sha']
    entries = [{'path': p['name'], 'mode': '100644', 'type': 'blob', 'sha': p['blob']} for p in record['parts']]
    entries.append({'path': 'manifest.json', 'mode': '100644', 'type': 'blob', 'sha': manifest_blob})
    tree = api(args.repo, 'trees', {'tree': entries})['sha']
    commit = api(args.repo, 'commits', {'message': 'Temporary transfer of verified Bakugan Arena 0.22 ZIP',
                                      'tree': tree, 'parents': []})['sha']
    record['tree'] = tree
    record['commit'] = commit
    args.report.write_text(json.dumps(record, indent=2) + '\n')
    api(args.repo, 'refs', {'ref': f'refs/heads/{args.branch}', 'sha': commit})
    args.report.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'repo': args.repo, 'branch': args.branch, 'commit': commit, 'parts': count,
                      'archive_sha256': archive_hash}), flush=True)


if __name__ == '__main__':
    main()
