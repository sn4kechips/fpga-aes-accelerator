/* All eleven round keys for the FIPS 197 key, against the reference
   expansion in roundkeys.mem. */
`timescale 1ns/1ps
module aesKeyExpand_tb;

    logic [127:0]      key;
    logic [11*128-1:0] roundKeys;
    logic [127:0]      expected [0:10];
    logic [127:0]      rk;
    int errors = 0;

    aesKeyExpand dut (.key(key), .roundKeys(roundKeys));

    initial begin
        $readmemh("roundkeys.mem", expected);

        key = 128'h2b7e1516_28aed2a6_abf71588_09cf4f3c;
        #1;

        // Round key 0 is the key itself; if this fails the word
        // packing is wrong, not the expansion.
        if (roundKeys[0 +: 128] !== key) begin
            $display("FAIL rk0 is not the key: %032h", roundKeys[0 +: 128]);
            errors++;
        end

        for (int r = 0; r <= 10; r++) begin
            rk = roundKeys[128*r +: 128];
            if (rk !== expected[r]) begin
                $display("FAIL rk%0d got=%032h want=%032h",
                         r, rk, expected[r]);
                errors++;
            end
        end

        // Appendix C.1 key, last round key only - a different Rcon
        // path through the same logic.
        key = 128'h00010203_04050607_08090a0b_0c0d0e0f;
        #1;
        rk = roundKeys[128*10 +: 128];
        if (rk !== 128'h13111d7f_e3944a17_f307a78b_4d2b30c5) begin
            $display("FAIL appC rk10: got %032h", rk);
            errors++;
        end

        if (errors == 0) $display("aesKeyExpand_tb PASS  (11/11 round keys)");
        else             $display("aesKeyExpand_tb FAIL  (%0d errors)", errors);
        $finish;
    end

endmodule
