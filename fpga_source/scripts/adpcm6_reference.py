"""Independent level-table reference for the project's six-bit differential codec."""
from bisect import bisect_right
from pathlib import Path

STEPS=[int(s,16) for s in (Path(__file__).resolve().parents[1]/'rtl/ima_steps.hex').read_text().split()]
INDEX=[-1,-1,-1,-1,2,4,6,8]
LEVELS=[[sum((step>>b) for b in range(5) if q&(16>>b)) for q in range(32)] for step in STEPS]

def encode(samples,state=(0,0)):
    predictor,index=state;codes=[]
    for sample in samples:
        error=int(sample)-predictor
        magnitude=bisect_right(LEVELS[index],abs(error))-1
        code=magnitude+(32 if error<0 else 0)
        delta=LEVELS[index][magnitude]+STEPS[index]//32
        predictor=max(-32768,min(32767,predictor+(-delta if error<0 else delta)))
        index=max(0,min(88,index+INDEX[magnitude//4]));codes.append(code)
    return codes,(predictor,index)

def decode(codes,state=(0,0)):
    predictor,index=state;samples=[]
    for code in codes:
        magnitude=code%32;delta=LEVELS[index][magnitude]+STEPS[index]//32
        predictor=max(-32768,min(32767,predictor+(-delta if code>=32 else delta)))
        index=max(0,min(88,index+INDEX[magnitude//4]));samples.append(predictor)
    return samples,(predictor,index)

def unpack(payload):
    bits=int.from_bytes(payload,'little')
    return [(bits>>(i*6))&63 for i in range(len(payload)*8//6)]
