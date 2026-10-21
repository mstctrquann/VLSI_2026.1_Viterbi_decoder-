// =============================================================================
// Module      : vit_acs_node
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Stage 2 - Single ACS (Add-Compare-Select) Node (5-bit PM)
// Description : Standard generalized Add-Compare-Select processing element:
//               1. ADD     : cand_0 = pm_p0 + bm_0; cand_1 = pm_p1 + bm_1
//               2. COMPARE : decision = (cand_1 < cand_0) ? 1'b1 : 1'b0
//               3. SELECT  : pm_next  = decision ? cand_1 : cand_0
// =============================================================================

`timescale 1ns / 1ps

module vit_acs_node (
    input  wire [4:0] pm_p0,          // 5-bit Path Metric from predecessor P0
    input  wire [1:0] bm_0,           // 2-bit Branch Metric for branch P0 -> Sj
    input  wire [4:0] pm_p1,          // 5-bit Path Metric from predecessor P1
    input  wire [1:0] bm_1,           // 2-bit Branch Metric for branch P1 -> Sj
    output wire [4:0] pm_next,        // Selected minimum 5-bit Path Metric
    output wire       decision        // Survivor branch decision (0: P0, 1: P1)
);

    // 1. ADD: Compute 5-bit candidate path metrics for both converging branches
    wire [4:0] cand_0 = pm_p0 + {3'b000, bm_0};
    wire [4:0] cand_1 = pm_p1 + {3'b000, bm_1};

    // 2. COMPARE: Choose branch P1 if cand_1 is strictly smaller than cand_0
    assign decision = (cand_1 < cand_0) ? 1'b1 : 1'b0;

    // 3. SELECT: 2:1 Multiplexer for updated Path Metric
    assign pm_next  = decision ? cand_1 : cand_0;

endmodule
