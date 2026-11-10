#!/usr/bin/sage
# -*- mode: python ; -*-


from sage.all import *

p = 21888242871839275222246405745257275088548364400416034343698204186575808495617
F = FiniteField(p)

if len(sys.argv) != Integer(2):
    print("Usage: <script> <number of input>")
    exit()

nInput = int(sys.argv[Integer(1)])
sk = [F(randrange(0,p,1))  for i in range(nInput)]

data_msg = F(randrange(0,p,1))

if nInput == 1:
    inp = {
        "secret_keys": str(sk[0]),
        "msg": str(data_msg)
    }
else:
    inp = {
        "secret_keys": [str(x) for x in sk],
        "msg": str(data_msg)
    }

import json

with open("input.json","w") as f:
    json.dump(inp, f, indent=2)

print("Wrote input of ZkSignature")