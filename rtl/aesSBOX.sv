/* The SBOX takes 1 input byte and replaces it with a substituion byte
according to a fixed AES lookup table */
module SBOX (
    input  logic [7:0] inputByte,
    output logic [7:0] outputByte
);

    // The AES table: entry i is what input i becomes
    // Unpacked so synthesis infers LUT ROM, not flops
      logic [7:0] rom [0:255];

    // Fill the table once, before time zero.
    initial $readmemh("sbox.mem", rom);

    // Input is the address, table contents are the output.
    // Continuous, not clocked; a round needs 16 of these
    //to resolve within one cycle.
    assign outputByte = rom[inputByte];

endmodule