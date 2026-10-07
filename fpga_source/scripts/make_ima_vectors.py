"""Independent codec fixture from CPython audioop (Python 3.12 or earlier).

The generated fixture is checked in, so ordinary HDL tests do not need Python.
"""
from pathlib import Path
import warnings,random,math,struct
warnings.filterwarnings('ignore',category=DeprecationWarning)
try:
    import audioop
except ImportError as exc:
    raise SystemExit('Use a Python runtime providing audioop, or keep the checked-in fixture.') from exc
root=Path(__file__).resolve().parents[1]
rng=random.Random(260926)
samples=[0]*64+[32767,-32768]*64
samples += [round(30000*math.sin(i*.137)) for i in range(4096)]
samples += [rng.randrange(-32768,32768) for _ in range(4096)]
if len(samples)%2:samples.append(0)
state=None;lines=[]
for i in range(0,len(samples),2):
    a,b=samples[i:i+2]
    encoded,state=audioop.lin2adpcm(struct.pack('<hh',a,b),2,state)
    lines.append(f'{a} {b} {encoded[0]} {state[0]} {state[1]}')
out=root/'sim/fixtures/ima_reference.txt';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text('\n'.join(lines)+'\n',encoding='ascii')
print(f'Generated {len(lines)} independent CPython IMA pairs')
