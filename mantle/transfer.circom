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
    signal input inputs_active[maxInput];
    signal input outputs_active[maxOutput];
    signal input tx_cm_root;
    signal input msg;

    // dummy constraint to avoid unused public input to be erased after compilation optimisation
    // The proof is bound to `msg` (it’s the `mantle_tx_hash` reduced modulo $`p`$ in case of transactions).
    signal dummy;
    dummy <== msg * msg;

    // Each public key is derived from the corresponding secret key.
    component inputs_pk[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_pk[i] = derive_public_key();
        inputs_pk[i].secret_key <== inputs_sk[i];
    }

    // Each input flag is boolean, and each input commitment is derived from the public key, the nonce and the value, with `program` and `data` set to `0`, so a ZkTransfer only consumes user notes.
    component inputs_cm[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_active[i] * (1 - inputs_active[i]) === 0;
        inputs_cm[i] = derive_note_commitment();
        inputs_cm[i].public_key <== inputs_pk[i].out;
        inputs_cm[i].nonce <== inputs_nonce[i];
        inputs_cm[i].value <== inputs_value[i];
        inputs_cm[i].program <== 0;
        inputs_cm[i].data <== 0;
    }

    // Each active input nullifier is derived from the secret key and the input commitment, and each inactive input has value 0.
    component inputs_nf[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_nf[i] = derive_note_nullifier();
        inputs_nf[i].commitment <== inputs_cm[i].out;
        inputs_nf[i].secret_key <== inputs_sk[i];

        (1 - inputs_active[i]) * inputs_value[i] === 0;

        inputs[i] <== inputs_nf[i].out * inputs_active[i];
    }

    // Each active input commitment is in `tx_cm_root`.
    component merkle_root[maxInput];
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
        // then check equality if active
        inputs_active[i] * (merkle_root[i].root - tx_cm_root) === 0;
    }

    // Each output flag is boolean, each active output commitment is derived from the public key, the nonce and the value,
    // with `program` and `data` set to `0`, so a ZkTransfer only creates user notes, and each inactive output has value 0.
    component outputs_cm[maxOutput];
    for(var i = 0; i < maxOutput; i++){
        outputs_active[i] * (1 - outputs_active[i]) === 0;
        outputs_cm[i] = derive_note_commitment();
        outputs_cm[i].public_key <== outputs_pk[i];
        outputs_cm[i].nonce <== outputs_nonce[i];
        outputs_cm[i].value <== outputs_value[i];
        outputs_cm[i].program <== 0;
        outputs_cm[i].data <== 0;

        (1 - outputs_active[i]) * outputs_value[i] === 0;
        outputs[i] <== outputs_active[i] * outputs_cm[i].out;
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
        // assert you consume more or Equal than you create 74 bits for up to 1024 inputs and 1024 outputs because if each is 64 bits 1024 fits in 74
    component is_balanced = SafeLessThan(74);
    is_balanced.in[0] <== value_outputs.out; 
    is_balanced.in[1] <== value_inputs.out + 1; // here we added 1 to change the equality: out <= in <=> out < in + 1
    is_balanced.out === 1;
    excess_value <== value_inputs.out - value_outputs.out;
}

component main {public [inputs_active, outputs_active, tx_cm_root, msg]}= zkTransfer(4, 8);