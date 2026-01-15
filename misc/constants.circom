//test
pragma circom 2.1.9;

include "../circomlib/circuits/bitify.circom";
include "../circomlib/circuits/comparators.circom";

// int.from_bytes(b"LEAD_V1", byteorder="little") = 13887241025832268
template LEAD_V1(){
    signal output out;
    out <== 13887241025832268;
}


// int.from_bytes(b"NONCE_CONTRIB_V1", byteorder="little") = 65580641403957881555985426713123114830
template NONCE_CONTRIB_V1(){
    signal output out;
    out <== 65580641403957881555985426713123114830;
}


// int.from_bytes(b"KDF", byteorder="little") = 4605003
template KDF(){
    signal output out;
    out <== 4605003;
}


// int.from_bytes(b"NOTE_ID_V1", byteorder="little") = 232989242343357190262606
template NOTE_ID_V1(){
    signal output out;
    out <== 232989242343357190262606;
}


// int.from_bytes(b"SELECTION_RANDOMNESS_V1", byteorder="little") = 4725583332308041445519605499429790922252397838206780755
template SELECTION_RANDOMNESS_V1(){
    signal output out;
    out <== 4725583332308041445519605499429790922252397838206780755;
}


// int.from_bytes(b"KEY_NULLIFIER_V1", byteorder="little") = 65580642670359595206974785265459610955
template KEY_NULLIFIER_V1(){
    signal output out;
    out <== 65580642670359595206974785265459610955;
}


// int.from_bytes(b"REWARD_VOUCHER", byteorder="little") = 1668646695034522932676805048878418
template REWARD_VOUCHER(){
    signal output out;
    out <== 1668646695034522932676805048878418;
}


// int.from_bytes(b"VOUCHER_NF", byteorder="little") = 332011368467182873038678
template VOUCHER_NF(){
    signal output out;
    out <== 332011368467182873038678;
}