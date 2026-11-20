//
pragma circom 2.2.3;

include "pol_lib.circom";

component main {public [sl, epoch_nonce, t0, t1, eligible_aged, eligible_latest, msg, reward_value]}= proof_of_leadership(40);