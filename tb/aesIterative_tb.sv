/* Full encryption: every vector in vectors.mem, one block at a time.
   Each line is plaintext(32 hex) || key(32 hex) || ciphertext(32 hex).
   The two FIPS vectors are first, so a basic breakage shows up on
   vector 0 rather than buried in the random bulk. */
`timescale 1ns/1ps
module aesIterative_tb;

    localparam int NVEC = 256;

    logic         clk = 0, rst_n = 0, start = 0;
    logic [127:0] plaintext, key, ciphertext;
    logic         busy, done;

    logic [383:0] vec [0:NVEC-1];
    int errors = 0;
    int cycles;
    bit timeout;

    always #5 clk = ~clk;

    aesIterative dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start),
        .plaintext  (plaintext),
        .key        (key),
        .ciphertext (ciphertext),
        .busy       (busy),
        .done       (done)
    );

    task automatic run_one (input logic [127:0] pt,
                            input logic [127:0] k,
                            input logic [127:0] expect_ct,
                            input int idx);
        begin
            @(negedge clk);
            plaintext = pt;
            key       = k;
            start     = 1'b1;
            @(negedge clk);
            start = 1'b0;

            cycles  = 0;
            timeout = 0;
            while (!done && !timeout) begin
                @(negedge clk);
                cycles++;
                if (cycles > 50) begin
                    $display("FAIL vec %0d: done never asserted", idx);
                    errors++;
                    timeout = 1;
                end
            end

            if (!timeout && ciphertext !== expect_ct) begin
                $display("FAIL vec %0d", idx);
                $display("   pt   %032h", pt);
                $display("   key  %032h", k);
                $display("   got  %032h", ciphertext);
                $display("   want %032h", expect_ct);
                errors++;
            end
        end
    endtask

    initial begin
        $readmemh("vectors.mem", vec);

        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // Vector 0 is the FIPS 197 Appendix B pair; report its latency
        // so a cycle-count regression is visible.
        run_one(vec[0][383:256], vec[0][255:128], vec[0][127:0], 0);
        $display("  first block took %0d cycles from start to done", cycles);

        for (int i = 1; i < NVEC; i++)
            run_one(vec[i][383:256], vec[i][255:128], vec[i][127:0], i);

        // Back-to-back blocks: start the next one the cycle after done.
        // The iterative core has no pipelining, but this catches a
        // busy/done handshake that latches late.
        for (int i = 0; i < 8; i++)
            run_one(vec[i][383:256], vec[i][255:128], vec[i][127:0], i);

        if (errors == 0)
            $display("aesIterative_tb PASS  (%0d vectors + 8 back-to-back)",
                     NVEC);
        else
            $display("aesIterative_tb FAIL  (%0d errors)", errors);
        $finish;
    end

endmodule
