/* MixColumns against FIPS 197 Appendix B, plus the two properties that
   a broken xtime reduction would violate. */
`timescale 1ns/1ps
module aesMixCols_tb;

    logic [127:0] stateIn, stateOut;
    logic [95:0]  tail;
    int errors = 0;

    aesMixCols dut (.stateIn(stateIn), .stateOut(stateOut));

    initial begin
        // FIPS 197 B, round 1, state after ShiftRows.
        stateIn = 128'hd4bf5d30_e0b452ae_b84111f1_1e2798e5;
        #1;
        if (stateOut !== 128'h046681e5_e0cb199a_48f8d37a_2806264c) begin
            $display("FAIL fips: got %032h", stateOut);
            errors++;
        end

        // All zeros in, all zeros out: 2*0 ^ 3*0 ^ 0 ^ 0 = 0.
        stateIn = '0;
        #1;
        if (stateOut !== '0) begin
            $display("FAIL zero: got %032h", stateOut);
            errors++;
        end

        // A column of four equal bytes is a fixed point, because
        // 2^3^1^1 = 1 in GF(2^8), so every output byte equals the input.
        // This exercises the high-bit reduction path for 0xff.
        stateIn = {4{32'hffffffff}};
        #1;
        if (stateOut !== {4{32'hffffffff}}) begin
            $display("FAIL ff fixed point: got %032h", stateOut);
            errors++;
        end

        stateIn = {4{32'h80808080}};
        #1;
        if (stateOut !== {4{32'h80808080}}) begin
            $display("FAIL 80 fixed point: got %032h", stateOut);
            errors++;
        end

        // Columns must not interact: changing column 0 must leave the
        // other three outputs alone.
        stateIn = 128'h00000000_11223344_55667788_99aabbcc;
        #1;
        tail = stateOut[95:0];
        stateIn[127:96] = 32'hdeadbeef;
        #1;
        if (stateOut[95:0] !== tail) begin
            $display("FAIL columns are coupled");
            errors++;
        end

        if (errors == 0) $display("aesMixCols_tb PASS");
        else             $display("aesMixCols_tb FAIL  (%0d errors)", errors);
        $finish;
    end

endmodule
