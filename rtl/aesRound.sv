/* One AES round: SubBytes -> ShiftRows -> MixColumns -> AddRoundKey.
   Combinational only; the register lives in whoever instantiates this.
   Byte 0 is state[127:120], byte 15 is state[7:0]. */
module aesRound (
    input  logic [127:0] stateIn,
    input  logic [127:0] roundKey,
    input  logic         skipMix,    // high on round 10
    output logic [127:0] stateOut
);

    logic [127:0] afterSub, afterShift, afterMix, mixSel;

    // SubBytes: 16 independent byte lookups, no interaction.
    genvar i;
    generate
        for (i = 0; i < 16; i++) begin : subBytes
            SBOX u_sbox (
                .inputByte  (stateIn [127 - 8*i -: 8]),
                .outputByte (afterSub[127 - 8*i -: 8])
            );
        end
    endgenerate

    // ShiftRows: pure rewiring, no logic.
    aesShiftRows u_shiftRows (
        .stateIn  (afterSub),
        .stateOut (afterShift)
    );

    // MixColumns: four columns, each mixed independently.
    aesMixCols u_mixCols (
        .stateIn  (afterShift),
        .stateOut (afterMix)
    );

    // Round 10 drops MixColumns.
    assign mixSel = skipMix ? afterShift : afterMix;

    // AddRoundKey: the only place the key touches the data.
    assign stateOut = mixSel ^ roundKey;

endmodule