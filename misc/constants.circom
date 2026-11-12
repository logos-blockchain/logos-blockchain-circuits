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


// int.from_bytes(b"NF_KDF_V1", byteorder="little") = 910114230080953599566
template NF_KDF_V1(){
    signal output out;
    out <== 910114230080953599566;
}


// nullifier key of the spending secret key 0, which holds every note of a program
// NF_SK0 = Compression(NF_KDF_V1, 0) = 19745231567900497560154548245026581537856204580560566680980497366069099903172
template NF_SK0(){
    signal output out;
    out <== 19745231567900497560154548245026581537856204580560566680980497366069099903172;
}


// public key of the spending secret key 0, which holds every note of a program
// PK0 = Compression(KDF, NF_SK0) = 972202553888197888567329063379813321440011391652189983173398887118271398762
template PK0(){
    signal output out;
    out <== 972202553888197888567329063379813321440011391652189983173398887118271398762;
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

// int.from_bytes(b"NOTE_NONCE_V1", byteorder="little") = 3908910849081313593738852061006
template NOTE_NONCE_V1(){
    signal output out;
    out <== 3908910849081313593738852061006;
}

// int.from_bytes(b"PROGRAM_STEP_ID_V1", byteorder="little") = 4297892925435406160038936939178153126875728
template PROGRAM_STEP_ID_V1(){
    signal output out;
    out <== 4297892925435406160038936939178153126875728;
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