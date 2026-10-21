// =============================================================================
// Module      : vit_acsu
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Stage 2 - ACSU (4x Parallel Add-Compare-Select Unit)
// Description : Instantiates 4 parallel ACS nodes for the 4 Trellis states:
//               - State S00 (0): P0=S00 (bm_00), P1=S01 (bm_11), u_t = 0
//               - State S01 (1): P0=S10 (bm_10), P1=S11 (bm_01), u_t = 0
//               - State S10 (2): P0=S00 (bm_11), P1=S01 (bm_00), u_t = 1
//               - State S11 (3): P0=S10 (bm_01), P1=S11 (bm_10), u_t = 1
// =============================================================================

`timescale 1ns / 1ps

module vit_acsu (
    input  wire [1:0] bm_00,          // Branch Metric for expected code 00
    input  wire [1:0] bm_01,          // Branch Metric for expected code 01
    input  wire [1:0] bm_10,          // Branch Metric for expected code 10
    input  wire [1:0] bm_11,          // Branch Metric for expected code 11
    input  wire [4:0] pm_curr_0,      // Current PM of state S00
    input  wire [4:0] pm_curr_1,      // Current PM of state S01
    input  wire [4:0] pm_curr_2,      // Current PM of state S10
    input  wire [4:0] pm_curr_3,      // Current PM of state S11
    output wire [4:0] pm_next_0,      // Next PM of state S00
    output wire [4:0] pm_next_1,      // Next PM of state S01
    output wire [4:0] pm_next_2,      // Next PM of state S10
    output wire [4:0] pm_next_3,      // Next PM of state S11
    output wire [3:0] decisions       // 4-bit survivor decision vector {d3, d2, d1, d0}
);

    // ACS Node 0 -> Target State S00 (u_t = 0): P0 = S00 (00), P1 = S01 (11)
    vit_acs_node u_acs_s00 (
        .pm_p0    (pm_curr_0),
        .bm_0     (bm_00),
        .pm_p1    (pm_curr_1),
        .bm_1     (bm_11),
        .pm_next  (pm_next_0),
        .decision (decisions[0])
    );

    // ACS Node 1 -> Target State S01 (u_t = 0): P0 = S10 (10), P1 = S11 (01)
    vit_acs_node u_acs_s01 (
        .pm_p0    (pm_curr_2),
        .bm_0     (bm_10),
        .pm_p1    (pm_curr_3),
        .bm_1     (bm_01),
        .pm_next  (pm_next_1),
        .decision (decisions[1])
    );

    // ACS Node 2 -> Target State S10 (u_t = 1): P0 = S00 (11), P1 = S01 (00)
    vit_acs_node u_acs_s10 (
        .pm_p0    (pm_curr_0),
        .bm_0     (bm_11),
        .pm_p1    (pm_curr_1),
        .bm_1     (bm_00),
        .pm_next  (pm_next_2),
        .decision (decisions[2])
    );

    // ACS Node 3 -> Target State S11 (u_t = 1): P0 = S10 (01), P1 = S11 (10)
    vit_acs_node u_acs_s11 (
        .pm_p0    (pm_curr_2),
        .bm_0     (bm_01),
        .pm_p1    (pm_curr_3),
        .bm_1     (bm_10),
        .pm_next  (pm_next_3),
        .decision (decisions[3])
    );

endmodule
