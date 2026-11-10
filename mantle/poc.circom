//test
pragma circom 2.1.9;

include "../hash_bn/poseidon2_hash.circom";
include "../hash_bn/merkle.circom";
include "../misc/constants.circom";

template derive_voucher_nullifier(){
    signal input secret_voucher;
    signal output out;

    component hash = Compression();
    component dst = VOUCHER_NF();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== secret_voucher;

    out <== hash.out;
}

template derive_reward_voucher(){
    signal input secret_voucher;
    signal output out;

    component hash = Compression(   );
    component dst = REWARD_VOUCHER();
    hash.inp[0] <== dst.out;
    hash.inp[1] <== secret_voucher;

    out <== hash.out;
}

template proof_of_claim(){
    signal input secret_voucher;
    signal input voucher_merkle_path[32];
    signal input voucher_merkle_path_selectors[32];
    signal input mantle_tx_hash;
    signal input voucher_root;

    signal output voucher_nullifier;

    //derive the reward voucher
    component reward_voucher = derive_reward_voucher();
    reward_voucher.secret_voucher <== secret_voucher;

    //Check reward voucher membership
            //First check selectors are indeed bits
    for(var i = 0; i < 32; i++){
        voucher_merkle_path_selectors[i] * (1 - voucher_merkle_path_selectors[i]) === 0;
    }
            //Then check the proof of membership
    component reward_membership = proof_of_membership(32);
    for(var i = 0; i < 32; i++){
        reward_membership.nodes[i] <== voucher_merkle_path[i];
        reward_membership.selector[i] <== voucher_merkle_path_selectors[i];
    }
    reward_membership.root <== voucher_root;
    reward_membership.leaf <== reward_voucher.out;

    reward_membership.out === 1;


    //derive the reward nullifier
    component reward_nullifier = derive_voucher_nullifier();
    reward_nullifier.secret_voucher <== secret_voucher;
    voucher_nullifier <== reward_nullifier.out;

    

    // dummy constraint to avoid unused public input to be erased after compilation optimisation
    signal dummy;
    dummy <== mantle_tx_hash * mantle_tx_hash;
}

component main {public [voucher_root,mantle_tx_hash]}= proof_of_claim();