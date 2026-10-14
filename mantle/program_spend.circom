//test
pragma circom 2.1.9;

include "../ledger/notes.circom";
include "../circomlib/circuits/comparators.circom";
include "../misc/arithmetic.circom";
include "../misc/comparator.circom";
include "../hash_bn/merkle.circom";
include "../hash_bn/poseidon2_hash.circom";

template zkProgramSpend(maxInput, maxOutput){
    // notes inputs
    signal input inputs_sk[maxInput];
    signal input inputs_nonce[maxInput];
    signal input inputs_value[maxInput];
    signal input inputs_data[maxInput];
    signal input inputs_selectors[maxInput][32];
    signal input inputs_path[maxInput][32];

    // notes outputs
    signal input outputs_pk[maxOutput];
    signal input outputs_nonce[maxOutput];
    signal input outputs_value[maxOutput];
    signal input outputs_program[maxOutput];
    signal input outputs_data[maxOutput];

    // outputs
    signal output inputs[maxInput];
    signal output outputs[maxOutput];
    signal output spend_notes_hash;

    //public inputs
    signal input inputs_active[maxInput];
    signal input outputs_active[maxOutput];
    signal input tx_cm_root;
    signal input program_id;
    signal input paid_value;
    signal input msg;

    // dummy constraint to avoid unused public input to be erased after compilation optimisation
    // The proof is bound to `msg`, the `op_id` of the Channel Inscribe Operation reduced modulo $`p`$.
    signal dummy;
    dummy <== msg * msg;

    // Each public key is derived from the corresponding secret key, as in the ZkTransfer.
    component inputs_pk[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_pk[i] = derive_public_key();
        inputs_pk[i].secret_key <== inputs_sk[i];
    }

    // Each input flag is boolean, and each input commitment is derived with `program` set to `program_id`, so the inputs are notes of the program.
    component inputs_cm[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_active[i] * (1 - inputs_active[i]) === 0;
        inputs_cm[i] = derive_note_commitment();
        inputs_cm[i].public_key <== inputs_pk[i].out;
        inputs_cm[i].nonce <== inputs_nonce[i];
        inputs_cm[i].value <== inputs_value[i];
        inputs_cm[i].program <== program_id;
        inputs_cm[i].data <== inputs_data[i];
    }

    // Each active input nullifier is derived from the secret key and the input commitment, and each inactive input has value 0, as in the ZkTransfer.
    component inputs_nf[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_nf[i] = derive_note_nullifier();
        inputs_nf[i].commitment <== inputs_cm[i].out;
        inputs_nf[i].secret_key <== inputs_sk[i];

        (1 - inputs_active[i]) * inputs_value[i] === 0;

        inputs[i] <== inputs_nf[i].out * inputs_active[i];
    }

    // each active input commitment is in `tx_cm_root`, 
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

    // Each output flag is boolean, each active output is a note of the program or a user note, 
    // whose commitment is derived from its fields, and each inactive output has value 0.
    component outputs_cm[maxOutput];
    signal other_program[maxOutput];
    for(var i = 0; i < maxOutput; i++){
        outputs_active[i] * (1 - outputs_active[i]) === 0;

        // if active: outputs_program[i] == program_id or (outputs_program[i] == 0 and outputs_data[i] == 0)
        other_program[i] <== outputs_active[i] * (outputs_program[i] - program_id);
        other_program[i] * outputs_program[i] === 0;
        other_program[i] * outputs_data[i] === 0;

        outputs_cm[i] = derive_note_commitment();
        outputs_cm[i].public_key <== outputs_pk[i];
        outputs_cm[i].nonce <== outputs_nonce[i];
        outputs_cm[i].value <== outputs_value[i];
        outputs_cm[i].program <== outputs_program[i];
        outputs_cm[i].data <== outputs_data[i];

        (1 - outputs_active[i]) * outputs_value[i] === 0;
        outputs[i] <== outputs_active[i] * outputs_cm[i].out;
    }

    // `spend_notes_hash` commits to the flag and the note of every input and output, nonce included,
    // which the program proof opens to check its rule. Their fields are hashed one after the other, input by input, then output by output.
    component spend_notes_hasher = Poseidon2_hash(1 + maxInput * 5 + maxOutput * 6);
    component dst = PROGRAM_SPEND_NOTES_V1();
    spend_notes_hasher.inp[0] <== dst.out;
    for(var i = 0; i < maxInput; i++){
        spend_notes_hasher.inp[1 + i * 5] <== inputs_active[i];
        spend_notes_hasher.inp[2 + i * 5] <== inputs_value[i];
        spend_notes_hasher.inp[3 + i * 5] <== inputs_nonce[i];
        spend_notes_hasher.inp[4 + i * 5] <== inputs_pk[i].out;
        spend_notes_hasher.inp[5 + i * 5] <== inputs_data[i];
    }
    for(var i = 0; i < maxOutput; i++){
        spend_notes_hasher.inp[1 + maxInput * 5 + i * 6] <== outputs_active[i];
        spend_notes_hasher.inp[2 + maxInput * 5 + i * 6] <== outputs_value[i];
        spend_notes_hasher.inp[3 + maxInput * 5 + i * 6] <== outputs_nonce[i];
        spend_notes_hasher.inp[4 + maxInput * 5 + i * 6] <== outputs_pk[i];
        spend_notes_hasher.inp[5 + maxInput * 5 + i * 6] <== outputs_program[i];
        spend_notes_hasher.inp[6 + maxInput * 5 + i * 6] <== outputs_data[i];
    }
    spend_notes_hash <== spend_notes_hasher.out;

    // The outputs are well-formed, and the inputs and the paid value balance the outputs exactly.
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
        // the inputs and the paid value balance the outputs exactly
    value_inputs.out + paid_value === value_outputs.out;
}

component main {public [inputs_active, outputs_active, tx_cm_root, program_id, paid_value, msg]}= zkProgramSpend(4, 8);