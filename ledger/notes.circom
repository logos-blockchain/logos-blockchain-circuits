//test
pragma circom 2.1.9;

include "../hash_bn/poseidon2_hash.circom";
include "../hash_bn/poseidon2_perm.circom";
include "../misc/constants.circom";

template derive_nullifier_key(){
    signal input spending_secret_key;
    signal output out;

    component hash = Compression();
    component dst = NF_KDF();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== spending_secret_key;
    out <== hash.out;
}

template derive_public_key(){
    signal input secret_key;
    signal output out;

    component hash = Compression();
    component dst = KDF();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== secret_key;
    out <== hash.out;
}

template derive_note_commitment(){
    signal input public_key;
    signal input stake_public_key;
    signal input nonce;
    signal input value;
    signal input program;
    signal input data;
    signal output out;

    component hash = Poseidon2_hash(7);
    component dst = NOTE_CM_V1();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== value;
    hash.inp[2] <== nonce;
    hash.inp[3] <== public_key;
    hash.inp[4] <== stake_public_key;
    hash.inp[5] <== program;
    hash.inp[6] <== data;
    out <== hash.out;
}

template derive_note_nullifier(){
    signal input commitment;
    signal input nullifier_key;
    signal output out;

    component hash = Poseidon2_hash(3);
    component dst = NOTE_NF_V1();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== commitment;
    hash.inp[2] <== nullifier_key;
    out <== hash.out;
}