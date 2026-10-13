#!/usr/bin/env python3
"""Reassemble exact Godot PCK v3 bytes from a pinned prior pack and small literals.

Only data copies are described by the manifest. No executable commands, engine
modification, or unverified downloads are performed by this tool.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

BUFFER = 1024 * 1024


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def index(path):
    path = Path(path)
    with path.open('rb') as stream:
        header = stream.read(112)
        magic, version = struct.unpack_from('<II', header)
        assert magic == 0x43504447 and version == 3
        assert struct.unpack_from('<I', header, 20)[0] == 2
        base, directory_offset = struct.unpack_from('<QQ', header, 24)
        assert base == 112 and base < directory_offset < path.stat().st_size
        stream.seek(directory_offset)
        directory = stream.read()
    count = struct.unpack_from('<I', directory)[0]
    assert 0 < count <= 20000
    entries = []
    position = 4
    for _ in range(count):
        size = struct.unpack_from('<I', directory, position)[0]
        position += 4
        assert size <= 4096
        name = directory[position:position+size].decode('utf-8').rstrip('\0')
        position += size
        offset, length = struct.unpack_from('<QQ', directory, position)
        md5 = directory[position+16:position+32].hex()
        flags = struct.unpack_from('<I', directory, position+32)[0]
        position += 36
        assert flags == 0 and base + offset + length <= directory_offset
        entries.append({'name': name, 'offset': base+offset, 'size': length, 'md5': md5})
    assert position == len(directory)
    return {'version': version, 'bytes': path.stat().st_size, 'base': base,
            'directory_offset': directory_offset, 'entries': entries}


def build(base_index, target, output):
    old = json.loads(Path(base_index).read_text())
    new = index(target)
    previous = {(entry['name'], entry['size'], entry['md5']): entry for entry in old['entries']}
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    payload_path = output / 'payload.bin'
    segments = []
    with Path(target).open('rb') as source, payload_path.open('wb') as payload:
        def literal(offset, size):
            if not size:
                return
            source.seek(offset)
            start = payload.tell()
            left = size
            while left:
                chunk = source.read(min(BUFFER, left))
                assert chunk
                payload.write(chunk)
                left -= len(chunk)
            segments.append({'target': offset, 'size': size, 'payload': start})
        end = 0
        for entry in sorted(new['entries'], key=lambda entry: entry['offset']):
            assert entry['offset'] >= end
            literal(end, entry['offset']-end)
            match = previous.get((entry['name'], entry['size'], entry['md5']))
            if match:
                segments.append({'target': entry['offset'], 'size': entry['size'], 'base': match['offset']})
            else:
                literal(entry['offset'], entry['size'])
            end = entry['offset']+entry['size']
        literal(end, new['bytes']-end)
    manifest = {'schema': 1, 'version': '0.24.0', 'base_bytes': old['bytes'],
                'base_sha256': old['sha256'], 'target_bytes': new['bytes'],
                'target_sha256': digest(target), 'payload_bytes': payload_path.stat().st_size,
                'payload_sha256': digest(payload_path), 'segments': segments,
                'copied_bytes': sum(item['size'] for item in segments if 'base' in item)}
    (output / 'manifest.json').write_text(json.dumps(manifest, separators=(',', ':'))+'\n')
    print(json.dumps({key: value for key, value in manifest.items() if key != 'segments'}, indent=2))


def apply(base, transfer, target):
    base = Path(base)
    target = Path(target)
    transfer = Path(transfer)
    manifest = json.loads((transfer / 'manifest.json').read_text())
    payload_path = transfer / 'payload.bin'
    assert manifest['schema'] == 1
    assert target.resolve() not in [base.resolve(), payload_path.resolve()]
    assert base.stat().st_size == manifest['base_bytes'] and digest(base) == manifest['base_sha256']
    assert payload_path.stat().st_size == manifest['payload_bytes']
    assert digest(payload_path) == manifest['payload_sha256']
    assert 0 < manifest['target_bytes'] <= 4 * 1024**3
    assert len(manifest['segments']) <= 40000
    target.parent.mkdir(parents=True, exist_ok=True)
    result = hashlib.sha256()
    with base.open('rb') as original, payload_path.open('rb') as payload, target.open('wb') as output:
        for item in manifest['segments']:
            assert item['target'] == output.tell() and 0 <= item['size'] <= manifest['target_bytes']
            reader = original if 'base' in item else payload
            offset = item.get('base', item.get('payload'))
            assert isinstance(offset, int) and offset >= 0
            assert offset + item['size'] <= (manifest['base_bytes'] if 'base' in item else manifest['payload_bytes'])
            reader.seek(offset)
            left = item['size']
            while left:
                chunk = reader.read(min(BUFFER, left))
                assert chunk
                output.write(chunk); result.update(chunk); left -= len(chunk)
        assert output.tell() == manifest['target_bytes']
    assert result.hexdigest() == manifest['target_sha256'], 'Reconstructed PCK hash mismatch'
    print('Exact PCK verified:', result.hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('build')
    create.add_argument('--base-index', required=True)
    create.add_argument('--target', required=True)
    create.add_argument('--output', required=True)
    restore = commands.add_parser('apply')
    restore.add_argument('--base', required=True)
    restore.add_argument('--transfer', required=True)
    restore.add_argument('--target', required=True)
    args = parser.parse_args()
    if args.command == 'build':
        build(args.base_index, args.target, args.output)
    else:
        apply(args.base, args.transfer, args.target)


if __name__ == '__main__':
    main()
