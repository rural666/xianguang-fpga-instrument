"""Independent CRC/audio audit: level-table reference for v4, CPython audioop for v3."""
from pathlib import Path
import audioop,binascii,json,struct,sys,wave
import numpy as np
import adpcm6_reference as codec6

root=Path(__file__).resolve().parents[1]
mode=sys.argv[1] if len(sys.argv)>1 else 'hardware'
path=root/('build/sim/adpcm_packets.bin' if mode=='simulation' else 'logs/hardware_music_capture.bin')
data=path.read_bytes();frames=[];position=0;crc_errors=0;skips=0;gaps=[];sources=[]
previous=None;output=[];codec_state=(0,0)
while True:
    at=data.find(b'T20A',position)
    if at<0 or at+24>len(data):break
    version=data[at+4];packet_size=122 if version==4 else 90
    if at+packet_size>len(data):break
    b=data[at:at+packet_size]
    if version not in (3,4) or struct.unpack_from('<IH',b,8)!=(46875,128) or b[22]>88:
        position=at+1;continue
    if binascii.crc_hqx(b[4:-2],0xffff)!=struct.unpack_from('<H',b,packet_size-2)[0]:
        crc_errors+=1;position=at+1;continue
    seq=struct.unpack_from('<H',b,6)[0]
    if frames and seq!=(frames[-1]['seq']+1)&65535:gaps.append([frames[-1]['seq'],seq])
    if frames:skips+=at-position
    state=(struct.unpack_from('<h',b,20)[0],b[22])
    if version==4:
        codes=codec6.unpack(b[24:-2]);decoded,end_state=codec6.decode(codes,state);source=np.asarray(decoded,dtype='<i2')
    else:
        packed=bytes((v>>4)|((v&15)<<4) for v in b[24:88])
        decoded,end_state=audioop.adpcm2lin(packed,2,state);source=np.frombuffer(decoded,dtype='<i2').copy()
    if mode=='simulation':
        start=len(frames)*128
        original=np.array([((start+n)*523)%24000-12000 for n in range(128)],dtype='<i2')
        assert state==codec_state,('checkpoint',seq,state,codec_state)
        if version==4:
            expected,codec_state=codec6.encode(original,codec_state)
            assert expected==codes,('FPGA encoder differs from independent level-table codec',seq)
        else:
            expected,codec_state=audioop.lin2adpcm(original.tobytes(),2,codec_state)
            assert expected==packed,('FPGA encoder differs from independent codec',seq)
        assert codec_state==end_state
    for sample in source.astype(int):
        if previous is None:previous=sample
        output.extend([previous+int((sample-previous)/2),sample]);previous=sample
    meta=struct.unpack_from('<H',b,14)[0];keymeta=struct.unpack_from('<H',b,16)[0]
    frames.append(dict(seq=seq,version=version,flags=b[5],gain=meta&511,locked=bool(meta&2048),calibrated=bool(meta&512),
        sustain=bool(meta&8192),keys=keymeta&4095,octave=(keymeta>>12)&3,timbre=b[18]&7,room=bool(b[18]&16),voices=b[19],depth=b[23]))
    sources.append(source);position=at+packet_size
assert frames and crc_errors==0 and not gaps and skips==0,(len(frames),crc_errors,gaps,skips)
assert all((f['flags']&3)==0 for f in frames),'FPGA overflow or synthesis deadline missed'
pcm=np.asarray(output,dtype='<i2');source=np.concatenate(sources)
report=dict(mode=mode,protocol_version=frames[0]['version'],packets=len(frames),crc_errors=crc_errors,sequence_gaps=gaps,skipped_bytes=skips,
    source_rate=23437.5,playback_rate=46875,duration_seconds=len(pcm)/46875,peak=int(abs(pcm.astype(int)).max()),
    imu_online_packets=sum(bool(f['flags']&64) for f in frames),gain_min=min(f['gain'] for f in frames),gain_max=max(f['gain'] for f in frames),
    locked_all=all(f['locked'] for f in frames),max_voices=max(f['voices'] for f in frames))
if mode=='simulation':
    cs=np.fromfile(root/'logs/decoded_sim_pcm.bin',dtype='<i2')
    assert np.array_equal(cs,pcm),'C# decoder/interpolation differs from independent CPython decode'
    report['reference_codec_and_desktop_match']=True
else:
    report['timbres']={}
    for t in range(8):
        ids=[i for i,f in enumerate(frames) if f['timbre']==t and f['keys']==0x200]
        assert len(ids)>100,('missing timbre capture',t)
        y=source[np.array(ids)[:,None]*128+np.arange(128)].ravel().astype(float)
        y=y[len(y)//4:3*len(y)//4];spec=abs(np.fft.rfft(y*np.hanning(len(y))));k=int(spec[1:].argmax()+1)
        a,b,c=np.log(np.maximum(spec[k-1:k+2],1e-20));freq=(k+.5*(a-c)/(a-2*b+c))*23437.5/len(y)
        rms=float(np.sqrt(np.mean(y*y)));ac_rms=float(np.std(y));dc=float(np.mean(y))
        report['timbres'][str(t+1)]=dict(fundamental_hz=float(freq),rms=rms,ac_rms=ac_rms,dc_mean=dc)
        assert ac_rms>80,('No alternating audio waveform',t,ac_rms)
        assert abs(dc)<max(20,rms*.05),('Excess DC can pass a naive nonzero-PCM test',t,dc,rms)
        assert abs(freq-440)<1.0,(t,freq)
        if t==2:
            time=np.arange(len(y))/23437.5;frequency=40315426/2**32*46875
            basis=np.array([np.sin(2*np.pi*frequency*time),np.cos(2*np.pi*frequency*time),np.ones(len(y))]).T
            fit=basis@np.linalg.lstsq(basis,y,rcond=None)[0]
            report['pure_A4_signal_residual_db']=float(10*np.log10(np.var(fit)/np.var(y-fit)))
            report['pure_A4_residual_rms']=float(np.std(y-fit))
    ids=[i for i,f in enumerate(frames) if f['keys']==0x091 and f['timbre']==2 and f['voices']==3]
    assert len(ids)>100,'three-voice chord not acknowledged'
    y=source[np.array(ids)[:,None]*128+np.arange(128)].ravel().astype(float);y=y[len(y)//4:3*len(y)//4]
    spectrum=abs(np.fft.rfft(y*np.hanning(len(y))));freqs=np.fft.rfftfreq(len(y),1/23437.5);peaks={}
    for name,freq in [('C4',261.625565),('E4',329.627557),('G4',391.995436)]:
        region=np.where(abs(freqs-freq)<2)[0];bin_id=region[np.argmax(spectrum[region])]
        peaks[name]=float(freqs[bin_id]);assert spectrum[bin_id]>spectrum.max()*.12,('missing chord fundamental',name)
    report['chord_fundamentals_hz']=peaks
    assert any(f['keys']==0xfff and f['voices']==12 for f in frames),'12 voices missing'
    assert sum(f['keys']==0 and f['sustain'] and f['voices']>=3 for f in frames)>100,'pedal release did not sustain'
    assert report['locked_all'] and report['gain_min']==report['gain_max']==256
    with wave.open(str(root/'新版钢琴与和弦_实板录音.wav'),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(46875);wav.writeframes(pcm.tobytes())
    cs_path=root/'logs/decoded_hardware_pcm.bin'
    if cs_path.exists():
        assert np.array_equal(np.fromfile(cs_path,dtype='<i2'),pcm),'real C# playback PCM differs from independent decode'
        report['reference_codec_and_desktop_match']=True
(root/'logs'/('audio_'+mode+'_report.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))
print('PASS independent audio audit')
