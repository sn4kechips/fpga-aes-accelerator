/* ShiftRows: row r rotates left by r positions.
   Pure rewiring - no logic, no gates.
   Byte index = r + 4*c, byte i sits at [127 - 8*i -: 8]. */
module aesShiftRows (
    input  logic [127:0] stateIn,
    output logic [127:0] stateOut
);

    // new col 0 <- old bytes 0, 5, 10, 15
    assign stateOut[127 -: 8] = stateIn[127 -: 8];
    assign stateOut[119 -: 8] = stateIn[ 87 -: 8];
    assign stateOut[111 -: 8] = stateIn[ 47 -: 8];
    assign stateOut[103 -: 8] = stateIn[  7 -: 8];

    // new col 1 <- old bytes 4, 9, 14, 3
    assign stateOut[ 95 -: 8] = stateIn[ 95 -: 8];
    assign stateOut[ 87 -: 8] = stateIn[ 55 -: 8];
    assign stateOut[ 79 -: 8] = stateIn[ 15 -: 8];
    assign stateOut[ 71 -: 8] = stateIn[103 -: 8];

    // new col 2 <- old bytes 8, 13, 2, 7
    assign stateOut[ 63 -: 8] = stateIn[ 63 -: 8];
    assign stateOut[ 55 -: 8] = stateIn[ 23 -: 8];
    assign stateOut[ 47 -: 8] = stateIn[111 -: 8];
    assign stateOut[ 39 -: 8] = stateIn[ 71 -: 8];

    // new col 3 <- old bytes 12, 1, 6, 11
    assign stateOut[ 31 -: 8] = stateIn[ 31 -: 8];
    assign stateOut[ 23 -: 8] = stateIn[119 -: 8];
    assign stateOut[ 15 -: 8] = stateIn[ 79 -: 8];
    assign stateOut[  7 -: 8] = stateIn[ 39 -: 8];

endmodule