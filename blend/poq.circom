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
template ProofOfQuota(nLevelsPK, bitsQuota) {
    // Public Inputs
    signal input core_quota;
    signal input leader_quota;
    signal input core_root;
    signal input pow_quota;
    signal input pol_ledger_aged;     // PoL: aged notes root
    signal input K_part_one;  // Blend: one-time signature public key
    signal input K_part_two;  // Blend: one-time signature public key
    signal input pow_blend_difficulty;


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
    signal input core_sk;                       // core node secret key
    signal input core_path[nLevelsPK];          // Merkle path for core PK
    signal input core_path_selectors[nLevelsPK];     // path selectors (bits)

    // PoL branch inputs (all the PoL private data)
    signal input pol_sl;
    signal input pol_epoch_nonce;
    signal input pol_t0;
    signal input pol_t1;

    signal input pol_noteid_path[32];
    signal input pol_noteid_path_selectors[32];
    signal input pol_secret_key;
    signal input pol_note_tx_hash;
    signal input pol_note_output_number;

    signal input pol_note_value;

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


    // enforce potential PoL (without verification that the note is unspent)
    // (All constraints inside pol ensure LeadershipVerify)
    component would_win = would_win_leadership();
    would_win.slot                <== pol_sl;
    would_win.epoch_nonce         <== pol_epoch_nonce;
    would_win.t0                  <== pol_t0;
    would_win.t1                  <== pol_t1;
    for (var i = 0; i < 32; i++) {
        would_win.aged_nodes[i]      <== pol_noteid_path[i];
        would_win.aged_selectors[i]  <== pol_noteid_path_selectors[i];
    }
    would_win.aged_root      <== pol_ledger_aged;
    would_win.transaction_hash <== pol_note_tx_hash;
    would_win.output_number    <== pol_note_output_number;
    would_win.secret_key     <== pol_secret_key;
    would_win.value          <== pol_note_value;


    // Get the blend PoW result
    component pow_ticket = Poseidon2_hash(2);
    pow_ticket.inp[0] <== pow_nonce;
    pow_ticket.inp[1] <== pol_epoch_nonce;
    component is_winning_pow = SafeFullLessThan();
    is_winning_pow.a <== pow_ticket.out;
    is_winning_pow.b <== pow_blend_difficulty;


    // Enforce the selected role is correct
    signal lh_correctness_selector;
    lh_correctness_selector <== (would_win.out - is_registered.out) * L1;
    is_registered.out + lh_correctness_selector + (is_winning_pow.out - is_registered.out) * L2 === 1;


    // Derive selection_randomness
    component selection_randomness = Poseidon2_hash(4);
    component dstSel = SELECTION_RANDOMNESS_V1();
    selection_randomness.inp[0] <== dstSel.out;
    // choose core_sk, pol.secret_key or pow_nonce:
    signal lh_key_selector;
    lh_key_selector <== (would_win.secret_key - core_sk) * L1;
    selection_randomness.inp[1] <== core_sk + lh_key_selector + (pow_nonce - core_sk) * L2;
    selection_randomness.inp[2] <== index;
    selection_randomness.inp[3] <== pol_epoch_nonce + (would_win.slot - pol_epoch_nonce) * L1; // because the last term is (pol_epoch_nonce - pol_epoch_nonce) * L2 = 0


    // Derive key_nullifier
    component nf = Compression();
    component dstNF = KEY_NULLIFIER_V1();
    nf.inp[0] <== dstNF.out;
    nf.inp[1] <== selection_randomness.out;
    key_nullifier <== nf.out;
}

// Instantiate with chosen depths: 20 for core PK tree
component main { public [ core_quota, leader_quota, pow_quota, core_root, K_part_one, K_part_two, pol_epoch_nonce, pol_t0, pol_t1, pol_ledger_aged, pow_blend_difficulty] }
    = ProofOfQuota(20, 20);
