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

template would_win_leadership(depth_merkle_tree, depth_set_tree){
    signal input sl;
    signal input epoch_nonce;
    signal input t0;                        // lottery constants
    signal input t1;
    signal input eligible_aged;             // eligible root when the stake distribution was frozen
    signal input sk;
    signal input value;
    signal input nonce;
    signal input set_selectors[depth_set_tree];          // position of the note set in the eligible tree
    signal input cm_aged_path[depth_merkle_tree];          // path of the note commitment in the commitment MMR of its set
    signal input cm_aged_selectors[depth_merkle_tree];
    signal input nf_root_aged;              // nullifier IMT root of the set when the stake distribution was frozen
    signal input set_aged_path[depth_set_tree];         // path of the leaf of the set to eligible_aged

    signal output out;
    signal output cm;
    signal output pk;

    // selectors are bits
    for(var i = 0; i < depth_set_tree; i++){
        set_selectors[i] * (1 - set_selectors[i]) === 0;
    }
    for(var i = 0; i < depth_merkle_tree; i++){
        cm_aged_selectors[i] * (1 - cm_aged_selectors[i]) === 0;
    }

    // Derive the public key from the secret key
    component note_pk = derive_public_key();
    note_pk.secret_key <== sk;
    pk <== note_pk.out;


    // Derive the note commitment
    component note_cm = derive_note_commitment();
    note_cm.public_key <== pk;
    note_cm.nonce <== nonce;
    note_cm.value <== value;
    note_cm.program <== 0;
    note_cm.data <== 0;
    cm <== note_cm.out;


    // Check the cm is aged enough
        // First compute the cm root
    component cm_root_aged = compute_merkle_root(depth_merkle_tree);
    for(var i = 0; i < depth_merkle_tree; i++){
        cm_root_aged.nodes[i] <== cm_aged_path[i];
        cm_root_aged.selector[i] <== cm_aged_selectors[i];
    }
    cm_root_aged.leaf <== cm;
        // get the note set leaf
    component eligible_leaf_aged = Poseidon2_hash(3);
    component dst = ELIGIBLE_SET_LEAF_V1();
    eligible_leaf_aged.inp[0] <== dst.out;
    eligible_leaf_aged.inp[1] <== cm_root_aged.root;
    eligible_leaf_aged.inp[2] <== nf_root_aged;
        // get the proof of membership of the set
    component aged_ok = proof_of_membership(depth_set_tree);
    for(var i = 0; i < depth_set_tree; i++){
        aged_ok.nodes[i] <== set_aged_path[i];
        aged_ok.selector[i] <== set_selectors[i];
    }
    aged_ok.leaf <== eligible_leaf_aged.out;
    aged_ok.root <== eligible_aged;


    // Compute the lottery ticket
    component ticket = ticket_calculator();
    ticket.epoch_nonce <== epoch_nonce;
    ticket.slot <== sl;
    ticket.note_id <== cm;
    ticket.secret_key <== sk;


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
    out <== aged_ok.out * winning.out;
} 


template proof_of_leadership(depth_merkle_tree, depth_set_tree){
    // public inputs
    signal input sl;
    signal input epoch_nonce;
    signal input t0;                        // lottery constants
    signal input t1;
    signal input eligible_aged;             // eligible root when the stake distribution was frozen
    signal input eligible_latest;           // latest eligible root
    signal input msg;                       // hash of the header of the proposed block

    // public output
    signal output entropy_contribution;

    // private witness
    signal input sk;
    signal input value;
    signal input nonce;
    signal input set_selectors[depth_set_tree];          // position of the note set in the eligible tree
    signal input cm_aged_path[depth_merkle_tree];          // path of the note commitment in the commitment MMR of its set
    signal input cm_aged_selectors[depth_merkle_tree];
    signal input nf_root_aged;              // nullifier IMT root of the set when the stake distribution was frozen
    signal input set_aged_path[depth_set_tree];         // path of the leaf of the set to eligible_aged
    signal input low_leaf_nf;               // greatest nullifier of the set lower than the note nullifier
    signal input low_leaf_next_nf;          // next greater nullifier of the set, 0 if none
    signal input low_leaf_next_index;       // index of the IMT leaf holding low_leaf_next_nf, 0 if none
    signal input low_leaf_path[depth_merkle_tree];
    signal input low_leaf_selectors[depth_merkle_tree];
    signal input cm_root_latest;            // latest commitment MMR root of the set
    signal input set_latest_path[depth_set_tree];       // path of the leaf of the set to eligible_latest


    // Verify the note is winning the lottery
    component lottery_checker = would_win_leadership(depth_merkle_tree, depth_set_tree);
    lottery_checker.sl <== sl;
    lottery_checker.epoch_nonce <== epoch_nonce;
    lottery_checker.t0 <== t0;
    lottery_checker.t1 <== t1;
    lottery_checker.eligible_aged <== eligible_aged;
    lottery_checker.sk <== sk;
    lottery_checker.value <== value;
    lottery_checker.nonce <== nonce;
    lottery_checker.nf_root_aged <== nf_root_aged;
    for(var i = 0; i < depth_set_tree; i++){
        lottery_checker.set_selectors[i] <== set_selectors[i];
        lottery_checker.set_aged_path[i] <== set_aged_path[i];
    }
    for(var i = 0; i < depth_merkle_tree; i++){
        lottery_checker.cm_aged_path[i] <== cm_aged_path[i];
        lottery_checker.cm_aged_selectors[i] <== cm_aged_selectors[i];
    }
    lottery_checker.out === 1;


    // Derive the nullifier
    component nf = derive_note_nullifier();
    nf.commitment <== lottery_checker.cm;
    nf.secret_key <== sk;


    // Check the remaining selectors are bits
    for(var i = 0; i < depth_merkle_tree; i++){
        low_leaf_selectors[i] * (1 - low_leaf_selectors[i]) === 0;
    }


    // Check the low_nf is in the latest IMT
        // First compute the nullifier leaf
    component low_leaf = Poseidon2_hash(4);
    component dst = NULLIFIER_IMT_LEAF_V1();
    low_leaf.inp[0] <== dst.out;
    low_leaf.inp[1] <== low_leaf_nf;
    low_leaf.inp[2] <== low_leaf_next_nf;
    low_leaf.inp[3] <== low_leaf_next_index;
        // compute the IMT root
    component nf_root_latest = compute_merkle_root(depth_merkle_tree);
    for(var i = 0; i < depth_merkle_tree; i++){
        nf_root_latest.nodes[i] <== low_leaf_path[i];
        nf_root_latest.selector[i] <== low_leaf_selectors[i];
    }
    nf_root_latest.leaf <== low_leaf.out;
        // get the note set leaf
    component eligible_leaf_latest = Poseidon2_hash(3);
    component dst_2 = ELIGIBLE_SET_LEAF_V1();
    eligible_leaf_latest.inp[0] <== dst_2.out;
    eligible_leaf_latest.inp[1] <== cm_root_latest;
    eligible_leaf_latest.inp[2] <== nf_root_latest.root;
        // get the proof of membership of the set
    component latest_ok = proof_of_membership(depth_set_tree);
    for(var i = 0; i < depth_set_tree; i++){
        latest_ok.nodes[i] <== set_latest_path[i];
        latest_ok.selector[i] <== set_selectors[i];
    }
    latest_ok.leaf <== eligible_leaf_latest.out;
    latest_ok.root <== eligible_latest;
    latest_ok.out === 1;


    // Check the nf isn't in the IMT
        // Check the low_nf is lower than the note nf
    component bigger = SafeFullLessThan();
    bigger.a <== low_leaf_nf;
    bigger.b <== nf.out;
    bigger.out === 1;
        // Check the low_next_nf is higher than the note nf or 0
    component smaller = SafeFullLessThan();
    smaller.a <== nf.out;
    smaller.b <== low_leaf_next_nf;
    component is_next_nf_zero = IsZero();
    is_next_nf_zero.in <== low_leaf_next_nf;
    is_next_nf_zero.out + smaller.out - is_next_nf_zero.out * smaller.out === 1;


    // Derive the entropy contribution
    component derive_entropy = Poseidon2_hash(4);
    component dst_3 = NONCE_CONTRIB_V1();
    derive_entropy.inp[0] <== dst_3.out;
    derive_entropy.inp[1] <== sl;
    derive_entropy.inp[2] <== lottery_checker.cm;
    derive_entropy.inp[3] <== sk;
    entropy_contribution <== derive_entropy.out;


    // The proof is bound to `msg`, the hash of the header of the proposed block.
    // Avoid the circom optimisation that removes unused public input
    signal dummy;
    dummy <== msg * msg;
}

