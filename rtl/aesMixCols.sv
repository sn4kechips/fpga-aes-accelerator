/* MixColumns: each 4-byte column is multiplied by a fixed matrix
   over GF(2^8).  Four independent columns, no interaction.
   Combinational only.

       b0 = 2*a0 ^ 3*a1 ^   a2 ^   a3
       b1 =   a0 ^ 2*a1 ^ 3*a2 ^   a3
       b2 =   a0 ^   a1 ^ 2*a2 ^ 3*a3
       b3 = 3*a0 ^   a1 ^   a2 ^ 2*a3 */

module aesMixCols (
    input  logic [127:0] stateIn,
    output logic [127:0] stateOut
);

    // Multiply by 2: shift left, and fold in 0x1b if the high bit fell off.
    function automatic logic [7:0] xtime (input logic [7:0] a);
        return {a[6:0], 1'b0} ^ (a[7] ? 8'h1b : 8'h00);
    endfunction

    // Multiply by 3 = multiply by 2, then add (add is XOR here).
    function automatic logic [7:0] mul3 (input logic [7:0] a);
        return xtime(a) ^ a;
    endfunction

    // One column in, one column out.
    function automatic logic [31:0] mixOne (input logic [31:0] col);
        logic [7:0] a0, a1, a2, a3;
        {a0, a1, a2, a3} = col;
        return { xtime(a0) ^ mul3(a1) ^   a2  ^  a3,
                       a0  ^ xtime(a1) ^ mul3(a2) ^       a3,
                       a0  ^  a1  ^ xtime(a2) ^ mul3(a3),
                 mul3(a0) ^ a1  ^ a2  ^ xtime(a3) };
    endfunction

    assign stateOut[127 -: 32] = mixOne(stateIn[127 -: 32]); // col 0
    assign stateOut[ 95 -: 32] = mixOne(stateIn[ 95 -: 32]);  // col 1
    assign stateOut[ 63 -: 32] = mixOne(stateIn[ 63 -: 32]);// col 2
    assign stateOut[ 31 -: 32] = mixOne(stateIn[ 31 -: 32]);       // col 3

endmodule