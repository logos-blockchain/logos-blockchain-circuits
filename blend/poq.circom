// PoQ.circom
pragma circom 2.1.9;

include "../hash_bn/poseidon2_hash.circom";
include "../misc/constants.circom";         // defines KDF, SELECTION_RANDOMNESS, PROOF_NULLIFIER
include "../misc/comparator.circom";        
include "../circomlib/circuits/bitify.circom";
include "../mantle/pol_lib.circom";      // defines proof_of_leadership
include "../ledger/notes.circom";

/**
 * ProofOfQuota(nLevelsPK, bitsQuota)
 *
 * - nLevelsPK   : depth of the core-node public-key registry Merkle tree
 * - bitsQuota   : bit-width for the index comparator
 */
template ProofOfQuota(nLevelsPK, bitsQuota, depth_merkle_tree) {
    // Public Inputs
    signal input core_quota;
    signal input leader_quota;
    signal input core_root;
    signal input pow_quota;
    signal input pol_eligible_aged;     // PoL eligible root when the stake distribution was frozen
    signal input K_part_one;            // Blend: one-time signature public key
    signal input K_part_two;            // Blend: one-time signature public key
    signal input pow_blend_difficulty;
    signal input pol_epoch_nonce;
    signal input pol_t0;
    signal input pol_t1;


    // dummy constraints to avoid unused public input to be erased after compilation optimisation
    signal dummy_one;
    dummy_one <== K_part_one * K_part_one;
    signal dummy_two;
    dummy_two <== K_part_two * K_part_two;

    signal output key_nullifier;    //key_nullifier

    // Private Inputs
    signal input selector;      // 0 = core, 1 = leader, 2 = pow
    signal input index;         // nullifier index

    // Core-nodes inputs
    signal input core_sk;                       // nullifier key of the Non-ephemeral Quota Key, from which the zk_id derives
    signal input core_path[nLevelsPK];          // Merkle path for core PK
    signal input core_path_selectors[nLevelsPK];     // path selectors (bits)

    // PoL branch inputs (all the PoL private data)
    signal input pol_sl;
    signal input pol_nullifier_key;
    signal input pol_staking_secret_key;
    signal input pol_note_value;
    signal input pol_note_nonce;
    signal input pol_note_program;          // 0 for a user note
    signal input pol_note_data;             // 0 for a user note
    signal input pol_cm_aged_path[depth_merkle_tree];
    signal input pol_cm_aged_selectors[depth_merkle_tree];
    signal input pol_low_leaf_nf;           // greatest nullifier of the set at the freeze lower than the note nullifier
    signal input pol_low_leaf_next_nf;      // next greater nullifier of the set at the freeze, 0 if none
    signal input pol_low_leaf_next_index;   // index of the IMT leaf holding pol_low_leaf_next_nf, 0 if none
    signal input pol_low_leaf_path[depth_merkle_tree];
    signal input pol_low_leaf_selectors[depth_merkle_tree];
    signal input pol_set_aged_path[depth_merkle_tree];
    signal input pol_set_selectors[depth_merkle_tree];


    // PoW branch input
    signal input pow_nonce;


    // Constraint the selector to be a 0, 1 or 2
    signal selector_squared;
    selector_squared <== selector * selector;
    (selector_squared - selector) * (selector - 2) === 0;

    // compute lagrange polynomial for selectors
    signal L1;
    signal L2;
    component inv_2 = INV_2();
    L1 <== - selector_squared + 2 * selector;
    L2 <== (selector_squared - selector) * inv_2.out;


    // Quota check: index < core_quota if core, index < leader_quota if leader, index < pow_quota if pow
    signal lh_quota_cmp;
    lh_quota_cmp <== (leader_quota - core_quota) * L1;
    component cmp = SafeLessThan(bitsQuota);
    cmp.in[0] <== index;
    cmp.in[1] <== core_quota + lh_quota_cmp + (pow_quota - core_quota) * L2;
    cmp.out === 1;


    // derive zk_id
    component zk_id = derive_public_key();
    zk_id.secret_key <== core_sk;


    // Merkle‐verify zk_id in core_root
    component is_registered = proof_of_membership(nLevelsPK);
    for (var i = 0; i < nLevelsPK; i++) {
        //check that the selectors are indeed bits
        core_path_selectors[i] * (1 - core_path_selectors[i]) === 0;
        //call the merkle proof checker
        is_registered.nodes[i]    <== core_path[i];
        is_registered.selector[i] <== core_path_selectors[i];
    }
    is_registered.root <== core_root;
    is_registered.leaf <== zk_id.out;


    // Compute the nullifier IMT root of the set when the stake distribution was frozen
    for (var i = 0; i < depth_merkle_tree; i++) {
        pol_low_leaf_selectors[i] * (1 - pol_low_leaf_selectors[i]) === 0;
    }
    component low_leaf = Poseidon2_hash(4);
    component dst_low_leaf = NULLIFIER_IMT_LEAF_V1();
    low_leaf.inp[0] <== dst_low_leaf.out;
    low_leaf.inp[1] <== pol_low_leaf_nf;
    low_leaf.inp[2] <== pol_low_leaf_next_nf;
    low_leaf.inp[3] <== pol_low_leaf_next_index;
    component nf_root_aged = compute_merkle_root(depth_merkle_tree);
    for (var i = 0; i < depth_merkle_tree; i++) {
        nf_root_aged.nodes[i] <== pol_low_leaf_path[i];
        nf_root_aged.selector[i] <== pol_low_leaf_selectors[i];
    }
    nf_root_aged.leaf <== low_leaf.out;


    // enforce potential PoL (the note is proven unspent at the freeze, not in the latest IMT)
    // (All constraints inside pol ensure LeadershipVerify)
    component would_win = would_win_leadership(depth_merkle_tree);
    would_win.sl <== pol_sl;
    would_win.epoch_nonce <== pol_epoch_nonce;
    would_win.t0 <== pol_t0;
    would_win.t1 <== pol_t1;
    would_win.eligible_aged <== pol_eligible_aged;
    would_win.nf_sk <== pol_nullifier_key;
    would_win.staking_sk <== pol_staking_secret_key;
    would_win.value <== pol_note_value;
    would_win.nonce <== pol_note_nonce;
    would_win.program <== pol_note_program;
    would_win.data <== pol_note_data;
    would_win.nf_root_aged <== nf_root_aged.root;
    for (var i = 0; i < depth_merkle_tree; i++) {
        would_win.set_selectors[i] <== pol_set_selectors[i];
        would_win.cm_aged_path[i] <== pol_cm_aged_path[i];
        would_win.cm_aged_selectors[i] <== pol_cm_aged_selectors[i];
        would_win.set_aged_path[i] <== pol_set_aged_path[i];
    }


    // Check the note nullifier isn't in the IMT of the set at the freeze
    component note_nf = derive_note_nullifier();
    note_nf.commitment <== would_win.cm;
    note_nf.nullifier_key <== pol_nullifier_key;
    component bigger = SafeFullLessThan();
    bigger.a <== pol_low_leaf_nf;
    bigger.b <== note_nf.out;
    component smaller = SafeFullLessThan();
    smaller.a <== note_nf.out;
    smaller.b <== pol_low_leaf_next_nf;
    component is_next_nf_zero = IsZero();
    is_next_nf_zero.in <== pol_low_leaf_next_nf;
    signal below_next;
    below_next <== is_next_nf_zero.out + smaller.out - is_next_nf_zero.out * smaller.out;
    signal unspent_at_freeze;
    unspent_at_freeze <== bigger.out * below_next;
    signal is_leader;
    is_leader <== would_win.out * unspent_at_freeze;


    // Get the blend PoW result
    component pow_ticket = Poseidon2_hash(2);
    pow_ticket.inp[0] <== pow_nonce;
    pow_ticket.inp[1] <== pol_epoch_nonce;
    component is_winning_pow = SafeFullLessThan();
    is_winning_pow.a <== pow_ticket.out;
    is_winning_pow.b <== pow_blend_difficulty;


    // Enforce the selected role is correct
    signal lh_correctness_selector;
    lh_correctness_selector <== (is_leader - is_registered.out) * L1;
    is_registered.out + lh_correctness_selector + (is_winning_pow.out - is_registered.out) * L2 === 1;


    // Derive selection_randomness
    component selection_randomness = Poseidon2_hash(4);
    component dstSel = SELECTION_RANDOMNESS_V1();
    selection_randomness.inp[0] <== dstSel.out;
    // choose core_sk, pol_staking_secret_key or pow_nonce:
    signal lh_key_selector;
    lh_key_selector <== (pol_staking_secret_key - core_sk) * L1;
    selection_randomness.inp[1] <== core_sk + lh_key_selector + (pow_nonce - core_sk) * L2;
    selection_randomness.inp[2] <== index;
    selection_randomness.inp[3] <== pol_epoch_nonce + (pol_sl - pol_epoch_nonce) * L1; // because the last term is (pol_epoch_nonce - pol_epoch_nonce) * L2 = 0


    // Derive key_nullifier
    component nf = Compression();
    component dstNF = KEY_NULLIFIER_V1();
    nf.inp[0] <== dstNF.out;
    nf.inp[1] <== selection_randomness.out;
    key_nullifier <== nf.out;
}

// Instantiate with chosen depths: 20 for core PK tree
component main { public [ core_quota, leader_quota, pow_quota, core_root, K_part_one, K_part_two, pol_epoch_nonce, pol_t0, pol_t1, pol_eligible_aged, pow_blend_difficulty] }
    = ProofOfQuota(20, 20, 40);
