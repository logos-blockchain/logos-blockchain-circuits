//test
pragma circom 2.1.9;

include "../circomlib/circuits/bitify.circom";
include "../circomlib/circuits/comparators.circom";

// inverse of 2
template INV_2(){
    signal output out;
    out <== 10944121435919637611123202872628637544274182200208017171849102093287904247809;
}

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

// int.from_bytes(b"NOTE_CM_V1", byteorder="little") = 232989244870034910891854
template NOTE_CM_V1(){
    signal output out;
    out <== 232989244870034910891854;
}

// int.from_bytes(b"NOTE_NF_V1", byteorder="little") = 232989242911804701822798
template NOTE_NF_V1(){
    signal output out;
    out <== 232989242911804701822798;
}

// int.from_bytes(b"PROGRAM_SPEND_NOTES_V1", byteorder="little") = 18459309890613820463764940807982002484216397908890192
template PROGRAM_SPEND_NOTES_V1(){
    signal output out;
    out <== 18459309890613820463764940807982002484216397908890192;
}

// int.from_bytes(b"ELIGIBLE_SET_LEAF_V1", byteorder="little") = 281666711431130609191864295137803020528161213509
template ELIGIBLE_SET_LEAF_V1(){
    signal output out;
    out <== 281666711431130609191864295137803020528161213509;
}

// int.from_bytes(b"NULLIFIER_IMT_LEAF_V1", byteorder="little") = 72106678126369435953119723346337253106302222882126
template NULLIFIER_IMT_LEAF_V1(){
    signal output out;
    out <== 72106678126369435953119723346337253106302222882126;
}