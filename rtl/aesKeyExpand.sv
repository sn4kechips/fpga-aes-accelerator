/* Key expansion: 128-bit key -> eleven 128-bit round keys.

   Works on 32-bit words.  w[0..3] are the key itself; after that
       w[i] = w[i-4] ^ temp
   where temp is w[i-1], except every 4th word where it first gets
   RotWord, SubWord and an Rcon XOR.

   Round keys come out on one flat bus rather than an unpacked array,
   because unpacked array ports are poorly supported by some tools.
   Round key r is roundKeys[128*r +: 128].

   Combinational: all 44 words resolve in one pass.  That is a long
   path (10 chained S-box lookups), so the caller should latch the
   output once and read the registers thereafter - see aesIterative.sv.

   Byte 0 is bit [127:120], matching the rest of the design. */
module aesKeyExpand (
    input  logic [127:0] key,
    output logic [11*128-1:0] roundKeys
);

    logic [31:0] w [0:43];

    // Rcon for words 4, 8, ... 40.  Only the top byte is nonzero.
    function automatic logic [7:0] rcon (input int unsigned r);
        case (r)
            1:  rcon = 8'h01;
            2:  rcon = 8'h02;
            3:  rcon = 8'h04;
            4: rcon = 8'h08;
            5:  rcon = 8'h10;
            6:  rcon = 8'h20;
            7:  rcon = 8'h40;
            8:  rcon = 8'h80;
            9:  rcon = 8'h1b;
            10: rcon = 8'h36;
            default: rcon = 8'h00;
        endcase
    endfunction

    // w[0..3] = the key, word 0 in the high bits.
    assign w[0] = key[127:96];
    assign w[1] = key[ 95:64];
    assign w[2] = key[ 63:32];
    assign w[3] = key[ 31: 0];

    // Every 4th word needs RotWord then SubWord: 4 S-boxes per step,
    // 10 steps, so 40 instances.
    logic [31:0] rotted [4:43];
    logic [31:0] subbed [4:43];

    genvar i, b;
    generate
        for (i = 4; i < 44; i++) begin : expand
            if (i % 4 == 0) begin : g_special
                // RotWord: [a0 a1 a2 a3] -> [a1 a2 a3 a0]
                assign rotted[i] = {w[i-1][23:0], w[i-1][31:24]};

                // SubWord: all four bytes through the same table.
                for (b = 0; b < 4; b++) begin : g_subword
                    SBOX u_sbox (
                        .inputByte  (rotted[i][31 - 8*b -: 8]),
                        .outputByte (subbed[i][31 - 8*b -: 8])
                    );
                end

                // Rcon hits the top byte only.
                assign w[i] = w[i-4]
                            ^ (subbed[i] ^ {rcon(i/4), 24'h000000});
            end else begin : g_plain
                assign w[i] = w[i-4] ^ w[i-1];
            end
        end
    endgenerate

    // Four words make one round key.  Round key r lands at 128*r.
    generate
        for (i = 0; i < 11; i++) begin : pack
            assign roundKeys[128*i +: 128] =
                 {w[4*i], w[4*i+1], w[4*i+2], w[4*i+3]};
        end
    endgenerate

endmodule