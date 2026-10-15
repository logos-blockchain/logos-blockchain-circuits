//test
pragma circom 2.1.9;

include "../hash_bn/poseidon2_perm.circom";
include "../circomlib/circuits/comparators.circom";

// compute a merkle root of depth n
//                  /!\ To call this function, it's important to check that each selector is a bit before!!!
template compute_merkle_root(n) {
    signal input nodes[n];      // The Merkle path, from the leaf level up to the root
    signal input selector[n];   // it's the leaf's indice in little endian bits, from the leaf level up: 1 when the complementary node is on the left
    signal input leaf;
    signal output root;


    component compression_hash[n];

    compression_hash[0] = Compression();
    compression_hash[0].inp[0] <== leaf - selector[0] * (leaf - nodes[0]);
    compression_hash[0].inp[1] <== nodes[0] - selector[0] * (nodes[0] - leaf);

    for(var i=1; i<n; i++){
        compression_hash[i] = Compression();
        compression_hash[i].inp[0] <== compression_hash[i-1].out - selector[i] * (compression_hash[i-1].out - nodes[i]);
        compression_hash[i].inp[1] <== nodes[i] - selector[i] * (nodes[i] - compression_hash[i-1].out);
    }

    root <== compression_hash[n-1].out;
}


// Verify a Merkle proof of depth n
//                  /!\ To call this function, it's important to check that each selector is a bit before!!!
template proof_of_membership(n) {
    signal input nodes[n];      // The Merkle path, from the leaf level up to the root
    signal input selector[n];   // it's the leaf's indice in little endian bits, from the leaf level up: 1 when the complementary node is on the left
    signal input root;
    signal input leaf;
    signal output out;
    

    component root_calculator = compute_merkle_root(n);
    for(var i=0; i<n; i++){
        root_calculator.nodes[i] <== nodes[i];
        root_calculator.selector[i] <== selector[i];
    }
    root_calculator.leaf <== leaf;


    component eq = IsEqual();
    eq.in[0] <== root_calculator.root;
    eq.in[1] <== root;

    out <== eq.out;
}