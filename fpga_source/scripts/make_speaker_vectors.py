from pathlib import Path
import math
root=Path(__file__).resolve().parents[1]
samples=[0]*2048
for i in range(10000): samples.append(round(3000*math.sin(2*math.pi*440*i/46875)))
for i in range(5000): samples.append(round(30000*math.sin(2*math.pi*880*i/46875)))
for i in range(5000): samples.append(round(sum(8000*math.sin(2*math.pi*f*i/46875) for f in [261.625565,329.627557,391.995436])))
samples += [0]*6000
assert len(samples)==28048 and min(samples)>=-32768 and max(samples)<=32767
p=root/'sim/fixtures/speaker_conditioner.hex'
p.write_text(''.join(f'{v&65535:04x}\n' for v in samples),encoding='ascii')
print(p)
