# Powers of Tau

`powersOfTau28_hez_final_17.ptau` — the phase-1 trusted setup used by
`snarkjs groth16 setup` in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml).

It was previously downloaded from
`https://storage.googleapis.com/zkevm/ptau/powersOfTau28_hez_final_17.ptau`,
which now returns `403 AccessDenied` for anonymous callers. The known mirrors
(`hermez.s3-eu-west-1.amazonaws.com`, `pse-trusted-setup-ppot.s3.eu-central-1.amazonaws.com`)
are also gone, so the file is vendored here instead.

## Layout

GitHub rejects any single file over 100 MB, and the ptau is ~151 MB, so it is
stored as two chunks:

    powersOfTau28_hez_final_17.ptau.part00   76,000,000 bytes
    powersOfTau28_hez_final_17.ptau.part01   75,078,040 bytes

Reassemble with:

    cat ptau/powersOfTau28_hez_final_17.ptau.part* > powersOfTau28_hez_final_17.ptau

Expected sha256 of the reassembled file (pinned as `PTAU_SHA256` in the CI workflow):

    6b662a324867139fb1a20a324d90b6ff61856dfb23f59326909f14b0e2483ae0

## Properties

Curve BN254 (`0x30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47`),
power 17 (2^17 = 131072 constraints), phase-2 ready — it carries the Lagrange
evaluation sections 12-15 that `groth16 setup` requires. The largest circuit in
this repo (PoL) uses 20460 constraints.
