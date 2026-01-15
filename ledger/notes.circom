//test
pragma circom 2.1.9;

include "../hash_bn/poseidon2_hash.circom";
include "../hash_bn/poseidon2_perm.circom";
include "../misc/constants.circom";

template derive_public_key(){
    signal input secret_key;
    signal output out;

    component hash = Compression();
    component dst = KDF();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== secret_key;
    out <== hash.out;
}