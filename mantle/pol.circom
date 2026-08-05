//
pragma circom 2.1.9;

include "pol_lib.circom";

component main {public [sl,epoch_nonce,t0,t1,ledger_aged,ledger_latest,P_lead_part_one,P_lead_part_two]}= proof_of_leadership();