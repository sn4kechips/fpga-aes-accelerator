/* Iterative AES-128: one round of logic, looped 10 times.
   11 cycles per block.  Same round logic as the pipelined version,
   so getting this right validates the whole datapath first.

   Handshake:
       pulse start with plaintext/key valid -> busy goes high
       11 cycles later done pulses for one cycle, ciphertext valid

   The round keys are latched once at start so the (long) key
   expansion path is not inside the round loop. */
module aesIterative (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] plaintext,
    input  logic [127:0] key,
    output logic [127:0] ciphertext,
    output logic         busy,
    output logic         done
);

    logic [11*128-1:0] rkComb;       // combinational, straight from the key
    logic [11*128-1:0] rkReg;        // latched copy used during the rounds
    logic [127:0]      stateReg, roundOut, curKey;
    logic [3:0]        roundCnt;     // 1..10 while running
    logic              lastRound;

    aesKeyExpand u_keyExpand (
        .key        (key),
        .roundKeys  (rkComb)
    );

    assign lastRound = (roundCnt == 4'd10);

    // Variable base, constant width - legal and synthesizable as a mux.
    assign curKey = rkReg[128*roundCnt +: 128];

    aesRound u_round (
        .stateIn    (stateReg),
        .roundKey   (curKey),
        .skipMix    (lastRound),
        .stateOut   (roundOut)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            stateReg <= '0;
            roundCnt <= '0;
            busy     <= 1'b0;
            done     <= 1'b0;
        end else begin
            done <= 1'b0;                      // one-cycle pulse by default

            if (!busy) begin
                if (start) begin
                    // Initial AddRoundKey, outside the round loop.
                    stateReg <= plaintext ^ rkComb[0 +: 128];
                    rkReg    <= rkComb;
                    roundCnt <= 4'd1;
                    busy     <= 1'b1;
                end
            end else begin
                stateReg <= roundOut;
                if (lastRound) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    roundCnt <= roundCnt + 4'd1;
                end
            end
        end
    end

    assign ciphertext = stateReg;

endmodule