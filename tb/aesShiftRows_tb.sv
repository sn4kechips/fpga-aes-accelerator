/* ShiftRows against the FIPS 197 Appendix B round-1 values, plus a
   permutation check that every input byte appears exactly once. */
`timescale 1ns/1ps
module aesShiftRows_tb;

    logic [127:0] stateIn, stateOut;
    int errors = 0;
    int seen [0:15];
    int v;

    aesShiftRows dut (.stateIn(stateIn), .stateOut(stateOut));

    initial begin
        // FIPS 197 B, round 1, state after SubBytes.
        stateIn = 128'hd42711ae_e0bf98f1_b8b45de5_1e415230;
        #1;
        if (stateOut !== 128'hd4bf5d30_e0b452ae_b84111f1_1e2798e5) begin
            $display("FAIL fips: got %032h", stateOut);
            errors++;
        end

        // Walking byte: put a unique value in each position and confirm
        // the output is a permutation of the input - catches a duplicated
        // or dropped source index, which is the classic ShiftRows bug.
        for (int i = 0; i < 16; i++)
            stateIn[127 - 8*i -: 8] = i[7:0];
        #1;
        for (int i = 0; i < 16; i++) seen[i] = 0;
        for (int i = 0; i < 16; i++) begin
            v = stateOut[127 - 8*i -: 8];
            if (v > 15) begin
                $display("FAIL perm: output byte %0d is %0d", i, v);
                errors++;
            end else begin
                seen[v]++;
            end
        end
        for (int i = 0; i < 16; i++)
            if (seen[i] != 1) begin
                $display("FAIL perm: input byte %0d appears %0d times",
                         i, seen[i]);
                errors++;
            end

        // Row 0 must be untouched: bytes 0, 4, 8, 12 stay put.
        if (stateOut[127 -: 8] !== 8'd0 || stateOut[95 -: 8] !== 8'd4 ||
            stateOut[ 63 -: 8] !== 8'd8 || stateOut[31 -: 8] !== 8'd12) begin
            $display("FAIL row 0 moved");
            errors++;
        end

        if (errors == 0) $display("aesShiftRows_tb PASS");
        else             $display("aesShiftRows_tb FAIL  (%0d errors)", errors);
        $finish;
    end

endmodule
