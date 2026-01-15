//test
pragma circom 2.1.9;

include "../hash_bn/poseidon2_hash.circom";
include "../ledger/notes.circom";
include "../hash_bn/merkle.circom";
include "../misc/comparator.circom";
include "../circomlib/circuits/bitify.circom";
include "../misc/constants.circom";


template ticket_calculator(){
    signal input epoch_nonce;
    signal input slot;
    signal input note_id;
    signal input secret_key;
    signal output out;

    component hash = Poseidon2_hash(5);
    component dst = LEAD_V1();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== epoch_nonce;
    hash.inp[2] <== slot;
    hash.inp[3] <== note_id;
    hash.inp[4] <== secret_key;

    out <== hash.out;
}

template derive_entropy(){
    signal input slot;
    signal input note_id;
    signal input secret_key;
    signal output out;

    component hash = Poseidon2_hash(4);
    component dst = NONCE_CONTRIB_V1();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== slot;
    hash.inp[2] <== note_id;
    hash.inp[3] <== secret_key;

    out <== hash.out;
}

template would_win_leadership(secret_depth){
    signal input slot;
    signal input epoch_nonce;
    signal input t0;
    signal input t1;

    //Part of the note id proof of membership to prove aged
    signal input aged_nodes[32];
    signal input aged_selectors[32];         // must be bits
    signal input aged_root;

    //Used to derive the note identifier
    signal input transaction_hash;
    signal input output_number;
    signal input secret_key;

    // The winning note value
    signal input value;

    signal output out;
    signal output note_identifier;


    // Derive the public key from the secret key
    component pk = derive_public_key();
    pk.secret_key <== secret_key;


    // Derive the note id
    component note_id = Poseidon2_hash(5);
    component dst_note_id = NOTE_ID_V1();
    note_id.inp[0] <== dst_note_id.out;
    note_id.inp[1] <== transaction_hash;
    note_id.inp[2] <== output_number;
    note_id.inp[3] <== value;
    note_id.inp[4] <== pk.out;


    // Check the note ID is aged enough
            //First check selectors are indeed bits
    for(var i = 0; i < 32; i++){
        aged_selectors[i] * (1 - aged_selectors[i]) === 0;
    }
            //Then check the proof of membership
    component aged_membership = proof_of_membership(32);
    for(var i = 0; i < 32; i++){
        aged_membership.nodes[i] <== aged_nodes[i];
        aged_membership.selector[i] <== aged_selectors[i];
    }
    aged_membership.root <== aged_root;
    aged_membership.leaf <== note_id.out;


    // Compute the lottery ticket
    component ticket = ticket_calculator();
    ticket.epoch_nonce <== epoch_nonce;
    ticket.slot <== slot;
    ticket.note_id <== note_id.out;
    ticket.secret_key <== secret_key;


    // Compute the lottery threshold
    signal intermediate;
    signal threshold;
    intermediate <== t1 * value;
    threshold <== value * (t0 + intermediate);


    // Check that the ticket is winning
    component winning = SafeFullLessThan();
    winning.a <== ticket.out;
    winning.b <== threshold;

    // Check that every constraint holds
    out <== aged_membership.out * winning.out;

    note_identifier <== note_id.out;
} 


template proof_of_leadership(secret_depth){
    signal input sl;
    signal input epoch_nonce;  // the epoch nonce eta
    signal input t0;
    signal input t1;

    //Part of the note id proof of membership to prove aged
    signal input noteid_aged_path[32];
    signal input noteid_aged_selectors[32];         // must be bits
    signal input ledger_aged;

    //Used to derive the note identifier
    signal input secret_key;
    signal input note_tx_hash;
    signal input note_output_number;
    
    //Part of the note id proof of membership to prove it's unspent
    signal input noteid_latest_path[32];
    signal input noteid_latest_selectors[32];         // must be bits
    signal input ledger_latest;

    // The winning note.
    signal input v;  // value of the note


    // Verify the note is winning the lottery
    component lottery_checker = would_win_leadership(secret_depth);
    lottery_checker.slot <== sl;
    lottery_checker.epoch_nonce <== epoch_nonce;
    lottery_checker.t0 <== t0;
    lottery_checker.t1 <== t1;
    for(var i = 0; i < 32; i++){
        lottery_checker.aged_nodes[i] <== noteid_aged_path[i];
        lottery_checker.aged_selectors[i] <== noteid_aged_selectors[i];
    }
    lottery_checker.aged_root <== ledger_aged;
    lottery_checker.transaction_hash <== note_tx_hash;
    lottery_checker.output_number <== note_output_number;
    lottery_checker.secret_key <== secret_key;
    lottery_checker.value <== v;


    // One time signing key used to sign the block proposal and the block
    signal input P_lead_part_one;
    signal input P_lead_part_two;


    //Avoid the circom optimisation that removes unused public input
    signal dummy_one;
    signal dummy_two;
    dummy_one <== P_lead_part_one * P_lead_part_one;
    dummy_two <== P_lead_part_two * P_lead_part_two;

    signal output entropy_contribution; // This is rho_lead


    // Check that the note is unspent
            //First check selectors are indeed bits
    for(var i = 0; i < 32; i++){
        noteid_latest_selectors[i] * (1 - noteid_latest_selectors[i]) === 0;
    }
            //Then check the note id is in the latest ledger state
    component unspent_membership = proof_of_membership(32);
    for(var i = 0; i < 32; i++){
        unspent_membership.nodes[i] <== noteid_latest_path[i];
        unspent_membership.selector[i] <== noteid_latest_selectors[i];
    }
    unspent_membership.root <== ledger_latest;
    unspent_membership.leaf <== lottery_checker.note_identifier;

    lottery_checker.out * unspent_membership.out === 1;


    // Compute the entropy contribution
    component entropy = derive_entropy();
    entropy.slot <== sl;
    entropy.note_id <== lottery_checker.note_identifier;
    entropy.secret_key <== secret_key;

    entropy_contribution <== entropy.out;
}

