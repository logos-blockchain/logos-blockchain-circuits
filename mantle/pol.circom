//
pragma circom 2.1.9;

include "pol_lib.circom";

component main {public [sl, epoch_nonce, t0, t1, eligible_aged, eligible_latest, leader_pk]}= proof_of_leadership();