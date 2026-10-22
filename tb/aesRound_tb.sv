/* One round, both flavours, against the FIPS 197 Appendix B trace.
   Round 1 exercises the full path; round 10 exercises skipMix. */
`timescale 1ns/1ps
module aesRound_tb;

    logic [127:0] stateIn, roundKey, stateOut, base;
    logic         skipMix;
    int errors = 0;

    aesRound dut (
        .stateIn  (stateIn),
        .roundKey (roundKey),
        .skipMix  (skipMix),
        .stateOut (stateOut)
    );

    initial begin
        // Round 1: input is the round-0 output (plaintext ^ rk0).
        stateIn  = 128'h193de3be_a0f4e22b_9ac68d2a_e9f84808;
        roundKey = 128'ha0fafe17_88542cb1_23a33939_2a6c7605;
        skipMix  = 1'b0;
        #1;
        if (stateOut !== 128'ha49c7ff2_689f352b_6b5bea43_026a5049) begin
            $display("FAIL round 1: got %032h", stateOut);
            errors++;
        end

        // Round 10: MixColumns skipped, output is the ciphertext.
        stateIn  = 128'heb40f21e_592e3884_8ba113e7_1bc342d2;
        roundKey = 128'hd014f9a8_c9ee2589_e13f0cc8_b6630ca6;
        skipMix  = 1'b1;
        #1;
        if (stateOut !== 128'h3925841d_02dc09fb_dc118597_196a0b32) begin
            $display("FAIL round 10: got %032h", stateOut);
            errors++;
        end

        // Same input with skipMix low must differ - proves the mux is
        // actually wired and not stuck.
        skipMix = 1'b0;
        #1;
        if (stateOut === 128'h3925841d_02dc09fb_dc118597_196a0b32) begin
            $display("FAIL skipMix has no effect");
            errors++;
        end

        // AddRoundKey is the last thing that happens: flipping the key
        // must flip exactly those bits of the output.
        stateIn  = 128'h193de3be_a0f4e22b_9ac68d2a_e9f84808;
        roundKey = '0;
        skipMix  = 1'b0;
        #1;
        base = stateOut;
        roundKey = 128'hffffffff_00000000_ffffffff_00000000;
        #1;
        if (stateOut !== (base ^ 128'hffffffff_00000000_ffffffff_00000000))
        begin
            $display("FAIL AddRoundKey is not the final step");
            errors++;
        end

        if (errors == 0) $display("aesRound_tb PASS");
        else             $display("aesRound_tb FAIL  (%0d errors)", errors);
        $finish;
    end

endmodule
