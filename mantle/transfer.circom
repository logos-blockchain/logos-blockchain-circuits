//test
pragma circom 2.1.9;

include "../ledger/notes.circom";
include "../circomlib/circuits/comparators.circom";
include "../misc/arithmetic.circom";
include "../misc/comparator.circom";
include "../hash_bn/merkle.circom";

template zkTransfer(maxInput, maxOutput){
    // notes inputs
    signal input inputs_sk[maxInput];
    signal input inputs_nonce[maxInput];
    signal input inputs_value[maxInput];
    signal input inputs_selectors[maxInput][32];
    signal input inputs_path[maxInput][32];

    // notes outputs
    signal input outputs_pk[maxOutput];
    signal input outputs_nonce[maxOutput];
    signal input outputs_value[maxOutput];

    // outputs
    signal output inputs[maxInput];
    signal output outputs[maxOutput];
    signal output excess_value;

    //public inputs
    signal input cm_merkle_root;
    signal input msg;

    // dummy constraint to avoid unused public input to be erased after compilation optimisation
    signal dummy;
    dummy <== msg * msg;

    // Each public key is derived from the corresponding secret key.
    component inputs_pk[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_pk[i] = derive_public_key();
        inputs_pk[i].secret_key <== inputs_sk[i];
    }

    // Each input commitment is derived from the public key, the nonce and the value.
    component inputs_cm[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_cm[i] = derive_note_commitment();
        inputs_cm[i].public_key <== inputs_pk[i].out;
        inputs_cm[i].nonce <== inputs_nonce[i];
        inputs_cm[i].value <== inputs_value[i];
    }

    // Each input nullifier is derived from the secret key and the input commitment if its value isn't 0.
    component inputs_nf[maxInput];
    component is_input_zero[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_nf[i] = derive_note_nullifier();
        inputs_nf[i].commitment <== inputs_cm[i].out;
        inputs_nf[i].secret_key <== inputs_sk[i];

        is_input_zero[i] = IsZero();
        is_input_zero[i].in <== inputs_value[i];
        inputs[i] <== inputs_nf[i].out + is_input_zero[i].out * ( 0 - inputs_nf[i].out);
    }

    // Each input commitment is in the merkle root announced if its value isn't 0.
    component merkle_root[maxInput];
    component cm_root_equal_check[maxInput];
    for(var i = 0; i < maxInput; i++){
        //First check selectors are indeed bits
        for(var j = 0; j < 32; j++){
            inputs_selectors[i][j] * (1 - inputs_selectors[i][j]) === 0;
        }
        // then compute the merkle root
        merkle_root[i] = compute_merkle_root(32);
        merkle_root[i].leaf <== inputs_cm[i].out;
        for(var j = 0; j < 32; j++){
            merkle_root[i].nodes[j] <== inputs_path[i][j];
            merkle_root[i].selector[j] <== inputs_selectors[i][j];
        }
        // then check equality if not of value 0
        (1 - is_input_zero[i].out) * (merkle_root[i].root - cm_merkle_root) === 0;
    }

    // Each output commitment is derived from the public key, the nonce and the value.
    component outputs_cm[maxOutput];
    for(var i = 0; i < maxOutput; i++){
        outputs_cm[i] = derive_note_commitment();
        outputs_cm[i].public_key <== outputs_pk[i];
        outputs_cm[i].nonce <== outputs_nonce[i];
        outputs_cm[i].value <== outputs_value[i];
    }

    // Each output is well-formed and the excess value is greater than zero and outputted.
        // First each output value is less than 64 bits
    component range_check[maxOutput];
    for(var i = 0; i < maxOutput; i++){
        range_check[i] = Num2Bits(64);
        range_check[i].in <== outputs_value[i];
    }
        // then sum the inputs and outputs
    component value_inputs = Sum64(maxInput);
    for(var i = 0; i < maxInput; i++){
        value_inputs.in[i] <== inputs_value[i];
    }
    component value_outputs = Sum64(maxOutput);
    for(var i = 0; i < maxOutput; i++){
        value_outputs.in[i] <== outputs_value[i];
    }
        // assert you consume more than you create 74 bits for up to 1024 inputs and 1024 outputs because if each is 64 bits 1024 fits in 74
    component is_balanced = SafeLessThan(74);
    is_balanced.in[0] <== value_outputs.out;
    is_balanced.in[1] <== value_inputs.out;
    is_balanced.out === 1;
    excess_value <== value_inputs.out - value_outputs.out;
}

component main {public [cm_merkle_root, msg]}= zkTransfer(4, 8);