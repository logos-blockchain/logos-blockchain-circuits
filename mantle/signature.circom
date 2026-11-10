//test
pragma circom 2.1.9;

include "../ledger/notes.circom";
include "../misc/constants.circom";

template zkSignature(maxInput){
    signal input secret_keys[maxInput];
    signal input msg;
    signal output public_keys[maxInput];

    component pk[maxInput];
    for(var i =0; i<maxInput; i++){
        pk[i] = derive_public_key();
        pk[i].secret_key <== secret_keys[i];
        public_keys[i] <== pk[i].out;
    }

    // dummy constraint to avoid unused public input to be erased after compilation optimisation
    signal dummy;
    dummy <== msg * msg;
}

component main {public [msg]}= zkSignature(32);