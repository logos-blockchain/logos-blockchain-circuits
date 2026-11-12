//test
pragma circom 2.1.9;

include "../circomlib/circuits/bitify.circom";
include "../circomlib/circuits/comparators.circom";

// If a or b isn't guaranteed to be less than p use SafeFullComparator
// See https://www.notion.so/nomos-tech/Comparisons-1fd261aa09df81feae1ff3e6612b92a0

template SafeFullLessThan() {
    signal input a;
    signal input b;
    signal output out;

    component bitifier_a = Num2Bits_strict();
    component bitifier_b = Num2Bits_strict();

    bitifier_a.in <== a;
    bitifier_b.in <== b;

    component numifier_a = Bits2Num(252);
    component numifier_b = Bits2Num(252);

    for(var i =0; i<252; i++){
        numifier_a.in[i] <== bitifier_a.out[i+2];
        numifier_b.in[i] <== bitifier_b.out[i+2];
    }

    component A = LessThan(252);
    A.in[0] <== numifier_b.out;
    A.in[1] <== numifier_a.out;

    component B = IsEqual();
    B.in[0] <== numifier_a.out;
    B.in[1] <== numifier_b.out;

    component C = IsEqual();
    C.in[0] <== bitifier_a.out[1];
    C.in[1] <== bitifier_b.out[1];

    component D = IsEqual();
    D.in[0] <== bitifier_a.out[1];
    D.in[1] <== 1;

    component E = IsEqual();
    E.in[0] <== bitifier_a.out[0];
    E.in[1] <== bitifier_b.out[0];

    component F = IsEqual();
    F.in[0] <== bitifier_a.out[0];
    F.in[1] <== 1;

    signal intermediate_results[4];
    intermediate_results[0] <== (1 - C.out) * (1-D.out);
    intermediate_results[1] <== C.out * (1-E.out);
    intermediate_results[2] <== intermediate_results[1] * (1- F.out);
    intermediate_results[3] <== B.out * (intermediate_results[0] + intermediate_results[2]);

    out <== (1 - A.out) * ((1 - B.out) + intermediate_results[3]);
}

// Safely compare two n-bit numbers 
// Performs range checks on the inputs to avoid overflow. Range is n <= 252
template SafeLessThan(n) {
    assert(n <= 252);
    signal input in[2];
    signal output out;

    component aInRange = Num2Bits(n);
    aInRange.in <== in[0];
    component bInRange = Num2Bits(n);
    bInRange.in <== in[1];

    component lt = LessThan(n);

    lt.in[0] <== in[0];
    lt.in[1] <== in[1];

    out <== lt.out;
}

// Asserts that any two active entries of `in` differ, each flag of `active` being a bit.
template DistinctWhenActive(n) {
    signal input in[n];
    signal input active[n];

    // Only the pairs (i, j) with i < j are used.
    signal both_active[n][n];
    signal inverse[n][n];
    for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
            // First, both_active[i][j] is 1 if the entries i and j are both active, and 0 otherwise
            both_active[i][j] <== active[i] * active[j];

            // Then the prover gives the inverse of in[i] - in[j] when both are active and differ, and 0 otherwise
            inverse[i][j] <-- (both_active[i][j] == 1 && in[i] != in[j]) ? 1 / (in[i] - in[j]) : 0;

            // Finally (in[i] - in[j]) * inverse[i][j] must equal both_active[i][j]:
            //   - both active: (in[i] - in[j]) * inverse[i][j] == 1, so in[i] - in[j] has an inverse and in[i] != in[j]
            //   - otherwise: (in[i] - in[j]) * inverse[i][j] == 0, which inverse[i][j] = 0 satisfies, so nothing is asserted
            (in[i] - in[j]) * inverse[i][j] === both_active[i][j];
        }
    }
}