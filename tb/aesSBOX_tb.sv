/* Exhaustive: all 256 inputs against the generated table. */
`timescale 1ns/1ps
module aesSBOX_tb;

    logic [7:0] inByte, outByte;
    logic [7:0] expected [0:255];
    int errors = 0;

    SBOX dut (.inputByte(inByte), .outputByte(outByte));

    initial begin
        $readmemh("sbox.mem", expected);

        for (int i = 0; i < 256; i++) begin
            inByte = i[7:0];
            #1;
            // !== so an unloaded ROM (all X) fails loudly instead of
            // silently comparing as unknown.
            if (outByte !== expected[i]) begin
                $display("FAIL in=%02h got=%02h want=%02h",
                         i, outByte, expected[i]);
                errors++;
            end
        end

        // Properties worth asserting on top of the table compare.
        if (expected[8'h00] !== 8'h63) begin
            $display("FAIL S(00) should be 63"); errors++;
        end
        if (expected[8'h53] !== 8'hED) begin
            $display("FAIL S(53) should be ED"); errors++;
        end

        if (errors == 0) $display("aesSBOX_tb PASS  (256/256)");
        else             $display("aesSBOX_tb FAIL  (%0d errors)", errors);
        $finish;
    end

endmodule
