#!/usr/bin/env python3
"""Decode supplied DS ADX/AHX and single-note SDAT cues for Godot.

Requires ffmpeg, vgmstream-cli and ndspy. Source hashes and cue references
are retained. Numeric music/voice IDs are not renamed as invented characters.
"""
import argparse
import concurrent.futures
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import subprocess
import tempfile
import wave
import numpy as np
from ndspy import soundArchive

STEPS = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
INDEX = [-1,-1,-1,-1,2,4,6,8]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def decode_swav(w):
    if int(w.waveType)==0:
        return np.frombuffer(w.data,dtype=np.int8).astype(np.int16)*256
    if int(w.waveType)==1:
        return np.frombuffer(w.data,dtype='<i2').copy()
    predictor,index = struct.unpack_from('<hH',w.data)
    index = min(88,index&127)
    samples=[]
    for byte in w.data[4:]:
        for nibble in (byte&15,byte>>4):
            step=STEPS[index]
            delta=(step>>3)+(step if nibble&4 else 0)+(step>>1 if nibble&2 else 0)+(step>>2 if nibble&1 else 0)
            predictor=max(-32768,min(32767,predictor-delta if nibble&8 else predictor+delta))
            index=max(0,min(88,index+INDEX[nibble&7]))
            samples.append(predictor)
    return np.asarray(samples,dtype='<i2')


def write_wav(path,pcm,rate):
    channels=1 if pcm.ndim==1 else pcm.shape[1]
    with wave.open(str(path),'wb') as out:
        out.setnchannels(channels);out.setsampwidth(2);out.setframerate(rate);out.writeframes(pcm.astype('<i2').tobytes())


def encode(path,target,loop_start=None):
    cmd=['ffmpeg','-v','error','-y','-i',str(path),'-c:a','libvorbis','-q:a','5']
    if loop_start is not None: cmd += ['-metadata',f'LOOPSTART={loop_start}']
    subprocess.run(cmd+[str(target)],check=True,capture_output=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw',type=Path,required=True)
    parser.add_argument('--vgmstream',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=Path('assets/ds/audio'))
    parser.add_argument('--sdat-only',action='store_true')
    args=parser.parse_args();out=args.output;out.mkdir(parents=True,exist_ok=True)
    for name in ['music','effects','voices']: (out/name).mkdir(exist_ok=True)
    manifest=json.loads((out/'manifest.json').read_text()) if args.sdat_only else {'version':1,'origin':'user_ds_nitrofs','music':{},'effects':{},'voices':{},'voice_language':'English (source suffix 0, verified separately)','voice_routing':'Curated source clip IDs; original game dispatcher is not reconstructed.','screen_music_routing':'Desktop mapping; original numeric ADX screen dispatch is not recovered.'}
    source=args.raw/'cridata'
    files=[] if args.sdat_only else [*sorted(source.glob('bgm*.adx')),*sorted(source.glob('se*.ahx')),*sorted(source.glob('vo*0.ahx'))]
    def convert(path):
        kind='music' if path.stem.startswith('bgm') else 'voices' if path.stem.startswith('vo') else 'effects'
        target=out/kind/(path.stem+'.ogg')
        metadata=subprocess.run([str(args.vgmstream),'-m',str(path)],check=True,capture_output=True,text=True).stdout
        rate=int(re.search(r'sample rate: (\d+)',metadata)[1]);count=int(re.search(r'stream total samples: (\d+)',metadata)[1]);channels=int(re.search(r'channels: (\d+)',metadata)[1])
        match=re.search(r'loop start: (\d+)',metadata);loop=int(match[1]) if match else 0
        end=re.search(r'loop end: (\d+)',metadata);loop_end=int(end[1]) if end else None
        assert loop_end is None or loop_end==count, 'Non-terminal loop requires an explicit trim: '+path.name
        with tempfile.TemporaryDirectory(prefix='ds-audio-',dir='/tmp') as temp:
            wav=Path(temp)/'source.wav'
            subprocess.run([str(args.vgmstream),'-i','-o',str(wav),str(path)],check=True,capture_output=True)
            encode(wav,target,loop if kind=='music' else None)
        return kind,path.stem,{'path':'res://'+str(target),'source_path':str(path.relative_to(args.raw)),'source_sha256':sha(path),'sha256':sha(target),'samples':count,'sample_rate':rate,'channels':channels,'seconds':count/rate,'loop_start':loop,'loop_offset_seconds':loop/rate,'loop':kind=='music' and bool(match),'source_loop':bool(match),'source_loop_end':loop_end}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        for index,(kind,name,record) in enumerate(executor.map(convert,files)):
            manifest[kind][name]=record
            if index%50==0: print('CRI converted',index+1,'/',len(files),flush=True)
    sdat_path=args.raw/'Snd/sound_data.sdat';sdat=soundArchive.SDAT(sdat_path.read_bytes());manifest['sdat_sha256']=sha(sdat_path)
    for archive_name,archive in sdat.sequenceArchives:
        archive.parse()
        for name,sequence in archive.sequences:
            index=archive.events.index(sequence.firstEvent);events=archive.events[index:index+3]
            assert [type(e).__name__ for e in events]==['InstrumentSwitchSequenceEvent','NoteSequenceEvent','EndTrackSequenceEvent'],name
            instrument,note=events[:2];bank=sdat.banks[sequence.bankID][1];definition=bank.instruments[instrument.instrumentID].noteDefinition
            archive_id=bank.waveArchiveIDs[definition.waveArchiveIDID];native=sdat.waveArchives[archive_id][1].waves[definition.waveID]
            assert (note.velocity,note.duration,definition.attack,definition.decay,definition.sustain,definition.release,definition.pan)==(127,0,127,127,127,127,64), name
            pcm=decode_swav(native);rate=round(native.sampleRate*pow(2,(note.type-definition.pitch)/12))
            target=out/'effects'/(name+'.ogg')
            with tempfile.TemporaryDirectory(prefix='ds-sdat-',dir='/tmp') as temp:
                wav=Path(temp)/'source.wav';write_wav(wav,pcm,rate);encode(wav,target)
            manifest['effects'][name]={'path':'res://'+str(target),'sha256':sha(target),'source_path':'Snd/sound_data.sdat','source_archive':archive_name,'bank_id':sequence.bankID,'instrument':instrument.instrumentID,'wave_archive_id':archive_id,'wave_id':definition.waveID,'note':note.type,'source_volume':sequence.volume,'volume_db':20*math.log10(max(1,sequence.volume)/127),'seconds':len(pcm)/rate,'loop':False,'source_looped_wave':native.isLooped,'source_event_format':'Instrument + Note + End, verified'}
    # The two original music sequences play separate hard-panned left/right
    # source waves. Battle has an intro followed by two looped samples.
    for name,archive_id,pairs in [('SEQ_BTL_BGM',1,[(0,1),(2,3)]),('SEQ_BGM_TUTORIAL',6,[(0,1)])]:
        archive=sdat.waveArchives[archive_id][1];chunks=[]
        for left,right in pairs:
            l,r=decode_swav(archive.waves[left]),decode_swav(archive.waves[right]);assert len(l)==len(r)
            chunks.append(np.column_stack([l,r]))
        pcm=np.concatenate(chunks);rate=archive.waves[0].sampleRate;loop=len(chunks[0]) if len(chunks)>1 else 0
        target=out/'music'/(name+'.ogg')
        with tempfile.TemporaryDirectory(prefix='ds-bgm-',dir='/tmp') as temp:
            wav=Path(temp)/'source.wav';write_wav(wav,pcm,rate);encode(wav,target,loop)
        manifest['music'][name]={'path':'res://'+str(target),'sha256':sha(target),'source_path':'Snd/sound_data.sdat','source_sequence':name,'source_wave_archive':sdat.waveArchives[archive_id][0],'source_wave_pairs':pairs,'sample_rate':rate,'seconds':len(pcm)/rate,'loop_start':loop,'loop_offset_seconds':loop/rate,'loop':True,'sequence_basis':'Native two-channel hard-pan sequence, intro/loop sample order verified'}
    manifest['counts']={name:len(manifest[name]) for name in ['music','effects','voices']}
    (out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    print('Finished:',json.dumps(manifest['counts']),flush=True)


if __name__=='__main__':main()
