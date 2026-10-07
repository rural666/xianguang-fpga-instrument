"""Compare equal-level stationary A4 captures; residual includes noise and distortion."""
from pathlib import Path
import audioop,binascii,json,struct
import numpy as np
from adpcm6_reference import decode,unpack
root=Path(__file__).resolve().parents[1]

def measure(path):
    data=path.read_bytes();position=0;output=[]
    while True:
        at=data.find(b'T20A',position)
        if at<0 or at+24>len(data):break
        version=data[at+4];size=122 if version==4 else 90
        if at+size>len(data):break
        b=data[at:at+size];position=at+size
        if version not in (3,4):continue
        assert binascii.crc_hqx(b[4:-2],0xffff)==struct.unpack_from('<H',b,size-2)[0]
        if b[18]&7!=2 or struct.unpack_from('<H',b,16)[0]&4095!=0x200:continue
        state=(struct.unpack_from('<h',b,20)[0],b[22])
        if version==4:samples,_=decode(unpack(b[24:-2]),state)
        else:
            payload=bytes((v>>4)|((v&15)<<4) for v in b[24:-2])
            raw,_=audioop.adpcm2lin(payload,2,state);samples=np.frombuffer(raw,dtype='<i2')
        output.extend(samples)
    y=np.asarray(output,dtype=float);assert len(y)>20000
    y=y[len(y)//4:3*len(y)//4];t=np.arange(len(y))/23437.5
    frequency=40315426/2**32*46875
    basis=np.array([np.sin(2*np.pi*frequency*t),np.cos(2*np.pi*frequency*t),np.ones(len(y))]).T
    fitted=basis@np.linalg.lstsq(basis,y,rcond=None)[0]
    return {'signal_rms':float(np.std(fitted)),'residual_rms':float(np.std(y-fitted)),
            'signal_residual_db':float(10*np.log10(np.var(fitted)/np.var(y-fitted)))}

before=measure(root/'testdata/baseline_v07_capture.bin')
after=measure(root/'logs/hardware_music_capture.bin')
report={'method':'stationary A4 least-squares sine/cosine/DC fit; digital residual, not acoustic or listening score',
        'before_v07':before,'after_v08':after,'improvement_db':after['signal_residual_db']-before['signal_residual_db'],
        'residual_amplitude_ratio':after['residual_rms']/before['residual_rms']}
assert abs(after['signal_rms']/before['signal_rms']-1)<.01,'signal levels must match'
assert report['improvement_db']>9,'precision upgrade failed to reduce the measured error'
(root/'logs/quality_comparison.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
