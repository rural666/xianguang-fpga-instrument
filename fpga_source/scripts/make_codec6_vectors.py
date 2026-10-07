from pathlib import Path
import random,math
from adpcm6_reference import encode
root=Path(__file__).resolve().parents[1]
random.seed(260926)
samples=[0]*32+[32767]*48+[-32768]*48+[0]*64
samples += [int(30000*math.sin(i*.137)) for i in range(5000)]
samples += [random.randrange(-32768,32768) for _ in range(5000)]
samples += [0]*512
lines=[];state=(0,0)
for sample in samples:
    code,state=encode([sample],state);lines.append(f'{sample} {code[0]} {state[0]} {state[1]}')
(root/'sim/fixtures').mkdir(exist_ok=True)
(root/'sim/fixtures/adpcm6_reference.txt').write_text('\n'.join(lines)+'\n',encoding='ascii')
print('Generated',len(lines),'independent codec vectors')
