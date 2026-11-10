//test
pragma circom 2.1.9;

include "../hash_bn/poseidon2_perm.circom";
include "../circomlib/circuits/comparators.circom";

// compute a merkle root of depth n
//                  /!\ To call this function, it's important to check that each selector is a bit before!!!
template compute_merkle_root(n) {
    signal input nodes[n];      // The Merkle path
    signal input selector[n];   // it's the leaf's indice in big endian bits indicating if complementary nodes are left or right
    signal input leaf;
    signal output root;
    

    component compression_hash[n];

    compression_hash[0] = Compression();
    compression_hash[0].inp[0] <== leaf - selector[n-1] * (leaf - nodes[0]);
    compression_hash[0].inp[1] <== nodes[0] - selector[n-1] * (nodes[0] - leaf);

    for(var i=1; i<n; i++){
        compression_hash[i] = Compression();
        compression_hash[i].inp[0] <== compression_hash[i-1].out - selector[n-1-i] * (compression_hash[i-1].out - nodes[i]);
        compression_hash[i].inp[1] <== nodes[i] - selector[n-1-i] * (nodes[i] - compression_hash[i-1].out);
    }

    root <== compression_hash[n-1].out;
}


// Verify a Merkle proof of depth n
//                  /!\ To call this function, it's important to check that each selector is a bit before!!!
template proof_of_membership(n) {
    signal input nodes[n];      // The Merkle path
    signal input selector[n];   // it's the leaf's indice in big endian bits indicating if complementary nodes are left or right
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