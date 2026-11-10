//test
pragma circom 2.1.9;

include "../ledger/notes.circom";
include "../circomlib/circuits/comparators.circom";
include "../misc/arithmetic.circom";
include "../misc/comparator.circom";
include "../hash_bn/merkle.circom";
include "../hash_bn/poseidon2_hash.circom";

template zkProgramSpend(maxInput, maxOutput, depth_merkle_tree){
    // notes inputs
    signal input inputs_stake_pk[maxInput];
    signal input inputs_nonce[maxInput];
    signal input inputs_value[maxInput];
    signal input inputs_data[maxInput];
    signal input inputs_selectors[maxInput][depth_merkle_tree];
    signal input inputs_path[maxInput][depth_merkle_tree];

    // notes outputs
    signal input outputs_pk[maxOutput];
    signal input outputs_stake_pk[maxOutput];
    signal input outputs_nonce[maxOutput];
    signal input outputs_value[maxOutput];
    signal input outputs_program[maxOutput];
    signal input outputs_data[maxOutput];

    // outputs
    signal output inputs[maxInput];
    signal output outputs[maxOutput];
    signal output program_step_id;

    //public inputs
    signal input inputs_active[maxInput];
    signal input outputs_active[maxOutput];
    signal input outputs_of_program[maxOutput];
    signal input tx_cm_root;
    signal input program_id;
    signal input paid_value;
    signal input msg;

    // dummy constraint to avoid unused public input to be erased after compilation optimisation
    // The proof is bound to `msg`, the `op_id` of the Channel Inscribe Operation reduced modulo $`p`$.
    signal dummy;
    dummy <== msg * msg;

    // Every note of the program is held by `PK0`, the public key of the spending secret key 0, whose nullifier key `NF_SK0` everyone knows.
    // The circuit takes no spending secret key: `PK0` and `NF_SK0` are constants.
    component pk0 = PK0();
    component nf_sk0 = NF_SK0();

    // Each input flag is boolean, the active inputs come first, and each input commitment is derived with the public key `PK0` and `program` set to `program_id`, so the inputs are notes of the program.
    component inputs_cm[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_active[i] * (1 - inputs_active[i]) === 0;
        if(i > 0){
            inputs_active[i] * (1 - inputs_active[i - 1]) === 0;
        }
        inputs_cm[i] = derive_note_commitment();
        inputs_cm[i].public_key <== pk0.out;
        inputs_cm[i].stake_public_key <== inputs_stake_pk[i];
        inputs_cm[i].nonce <== inputs_nonce[i];
        inputs_cm[i].value <== inputs_value[i];
        inputs_cm[i].program <== program_id;
        inputs_cm[i].data <== inputs_data[i];
    }

    // Each active input nullifier is derived from `NF_SK0` and the input commitment, and each inactive input has value 0, as in the ZkTransfer.
    component inputs_nf[maxInput];
    for(var i = 0; i < maxInput; i++){
        inputs_nf[i] = derive_note_nullifier();
        inputs_nf[i].commitment <== inputs_cm[i].out;
        inputs_nf[i].nullifier_key <== nf_sk0.out;

        (1 - inputs_active[i]) * inputs_value[i] === 0;

        inputs[i] <== inputs_nf[i].out * inputs_active[i];
    }

    // each active input commitment is in `tx_cm_root`, 
    component merkle_root[maxInput];
    for(var i = 0; i < maxInput; i++){
        //First check selectors are indeed bits
        for(var j = 0; j < depth_merkle_tree; j++){
            inputs_selectors[i][j] * (1 - inputs_selectors[i][j]) === 0;
        }
        // then compute the merkle root
        merkle_root[i] = compute_merkle_root(depth_merkle_tree);
        merkle_root[i].leaf <== inputs_cm[i].out;
        for(var j = 0; j < depth_merkle_tree; j++){
            merkle_root[i].nodes[j] <== inputs_path[i][j];
            merkle_root[i].selector[j] <== inputs_selectors[i][j];
        }
        // then check equality if active
        inputs_active[i] * (merkle_root[i].root - tx_cm_root) === 0;
    }

    // Each output flag is boolean, each active output is a note of the program held by `PK0` if `outputs_of_program` says so and a user note otherwise,
    // whose commitment is derived from its fields, and each inactive output has value 0 and is not a note of the program.
    component outputs_cm[maxOutput];
    for(var i = 0; i < maxOutput; i++){
        outputs_active[i] * (1 - outputs_active[i]) === 0;
        outputs_of_program[i] * (1 - outputs_of_program[i]) === 0;
        outputs_of_program[i] * (1 - outputs_active[i]) === 0;

        // if a note of the program: outputs_program[i] == program_id and outputs_pk[i] == PK0
        outputs_of_program[i] * (outputs_program[i] - program_id) === 0;
        outputs_of_program[i] * (outputs_pk[i] - pk0.out) === 0;
        // if an active user note: outputs_program[i] == 0 and outputs_data[i] == 0
        (outputs_active[i] - outputs_of_program[i]) * outputs_program[i] === 0;
        (outputs_active[i] - outputs_of_program[i]) * outputs_data[i] === 0;

        outputs_cm[i] = derive_note_commitment();
        outputs_cm[i].public_key <== outputs_pk[i];
        outputs_cm[i].stake_public_key <== outputs_stake_pk[i];
        outputs_cm[i].nonce <== outputs_nonce[i];
        outputs_cm[i].value <== outputs_value[i];
        outputs_cm[i].program <== outputs_program[i];
        outputs_cm[i].data <== outputs_data[i];

        (1 - outputs_active[i]) * outputs_value[i] === 0;
        outputs[i] <== outputs_active[i] * outputs_cm[i].out;
    }

    // When the step consumes a note of the program, the nonce of each active output is derived from the nullifier of the first input
    // and the index of the output, like the nonce of a note the ledger creates from its `op_id` and its output number.
    // The active inputs come first, so `inputs_active[0]` holds exactly when the step consumes a note of the program.
    // A step consuming none picks the nonces of its outputs: the `op_id` covers the output commitments, so it cannot derive them.
    component outputs_nonce_derived[maxOutput];
    component nonce_dst = NOTE_NONCE_V1();
    signal nonce_derived[maxOutput];
    for(var i = 0; i < maxOutput; i++){
        outputs_nonce_derived[i] = Poseidon2_hash(5);
        outputs_nonce_derived[i].inp[0] <== nonce_dst.out;
        outputs_nonce_derived[i].inp[1] <== inputs[0];
        outputs_nonce_derived[i].inp[2] <== i;
        outputs_nonce_derived[i].inp[3] <== outputs_value[i];
        outputs_nonce_derived[i].inp[4] <== outputs_pk[i];

        nonce_derived[i] <== inputs_active[0] * outputs_active[i];
        nonce_derived[i] * (outputs_nonce[i] - outputs_nonce_derived[i].out) === 0;
    }

    // `program_step_id` commits to the flag and the note of every input and output, nonce and staking key included,
    // which the program proof opens to check its rule. Their fields are hashed one after the other, input by input, then output by output,
    // each multiplied by the flag of its input or output, so that an inactive one reads as 0 and a spend has a single hash.
    // The value of an inactive input or output is already 0.
    signal active_inputs_nonce[maxInput];
    signal active_inputs_pk[maxInput];
    signal active_inputs_stake_pk[maxInput];
    signal active_inputs_data[maxInput];
    signal active_outputs_nonce[maxOutput];
    signal active_outputs_pk[maxOutput];
    signal active_outputs_stake_pk[maxOutput];
    signal active_outputs_program[maxOutput];
    signal active_outputs_data[maxOutput];
    component program_step_id_hasher = Poseidon2_hash(1 + maxInput * 6 + maxOutput * 7);
    component dst = PROGRAM_STEP_ID_V1();
    program_step_id_hasher.inp[0] <== dst.out;
    for(var i = 0; i < maxInput; i++){
        active_inputs_nonce[i] <== inputs_active[i] * inputs_nonce[i];
        active_inputs_pk[i] <== inputs_active[i] * pk0.out;
        active_inputs_stake_pk[i] <== inputs_active[i] * inputs_stake_pk[i];
        active_inputs_data[i] <== inputs_active[i] * inputs_data[i];

        program_step_id_hasher.inp[1 + i * 6] <== inputs_active[i];
        program_step_id_hasher.inp[2 + i * 6] <== inputs_value[i];
        program_step_id_hasher.inp[3 + i * 6] <== active_inputs_nonce[i];
        program_step_id_hasher.inp[4 + i * 6] <== active_inputs_pk[i];
        program_step_id_hasher.inp[5 + i * 6] <== active_inputs_stake_pk[i];
        program_step_id_hasher.inp[6 + i * 6] <== active_inputs_data[i];
    }
    for(var i = 0; i < maxOutput; i++){
        active_outputs_nonce[i] <== outputs_active[i] * outputs_nonce[i];
        active_outputs_pk[i] <== outputs_active[i] * outputs_pk[i];
        active_outputs_stake_pk[i] <== outputs_active[i] * outputs_stake_pk[i];
        active_outputs_program[i] <== outputs_active[i] * outputs_program[i];
        active_outputs_data[i] <== outputs_active[i] * outputs_data[i];

        program_step_id_hasher.inp[1 + maxInput * 6 + i * 7] <== outputs_active[i];
        program_step_id_hasher.inp[2 + maxInput * 6 + i * 7] <== outputs_value[i];
        program_step_id_hasher.inp[3 + maxInput * 6 + i * 7] <== active_outputs_nonce[i];
        program_step_id_hasher.inp[4 + maxInput * 6 + i * 7] <== active_outputs_pk[i];
        program_step_id_hasher.inp[5 + maxInput * 6 + i * 7] <== active_outputs_stake_pk[i];
        program_step_id_hasher.inp[6 + maxInput * 6 + i * 7] <== active_outputs_program[i];
        program_step_id_hasher.inp[7 + maxInput * 6 + i * 7] <== active_outputs_data[i];
    }
    program_step_id <== program_step_id_hasher.out;

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

component main {public [inputs_active, outputs_active, outputs_of_program, tx_cm_root, program_id, paid_value, msg]}= zkProgramSpend(4, 8, 40);