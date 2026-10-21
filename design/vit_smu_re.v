// =============================================================================
// Module      : vit_smu_re
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Stage 3 - SMU (Survivor Memory Unit - Register-Exchange 4x8 FF)
// Description : Implements a 4 x 8-bit Register-Exchange matrix (32 Flip-Flops)
//               for dynamic on-the-fly survivor path tracking across 8 Trellis
//               steps (t = 0..7), completely eliminating Survivor RAM and
//               reverse Traceback latency.
//               - State S00 (0): copies from P1=S01 (d0=1) or P0=S00 (d0=0), shifts u_t=0
//               - State S01 (1): copies from P1=S11 (d1=1) or P0=S10 (d1=0), shifts u_t=0
//               - State S10 (2): copies from P1=S01 (d2=1) or P0=S00 (d2=0), shifts u_t=1
//               - State S11 (3): copies from P1=S11 (d3=1) or P0=S10 (d3=0), shifts u_t=1
// =============================================================================

`timescale 1ns / 1ps

module vit_smu_re (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       init_smu,       // Clear history registers at start of frame
    input  wire       smu_en,         // Shift & exchange enable for each Trellis step
    input  wire [3:0] decisions,      // 4-bit survivor decisions from ACSU {d3,d2,d1,d0}
    output reg  [7:0] surv_hist_0,    // 8-bit survivor path history for State S00
    output reg  [7:0] surv_hist_1,    // 8-bit survivor path history for State S01
    output reg  [7:0] surv_hist_2,    // 8-bit survivor path history for State S10
    output reg  [7:0] surv_hist_3     // 8-bit survivor path history for State S11
);

    // Select winning predecessor history (upper 7 bits [6:0]) via 2:1 MUXes
    wire [6:0] pred_hist_s00 = decisions[0] ? surv_hist_1[6:0] : surv_hist_0[6:0];
    wire [6:0] pred_hist_s01 = decisions[1] ? surv_hist_3[6:0] : surv_hist_2[6:0];
    wire [6:0] pred_hist_s10 = decisions[2] ? surv_hist_1[6:0] : surv_hist_0[6:0];
    wire [6:0] pred_hist_s11 = decisions[3] ? surv_hist_3[6:0] : surv_hist_2[6:0];

    // Shift in the decoded information bit u_t (0 for S00/S01, 1 for S10/S11) into LSB
    wire [7:0] next_hist_0 = {pred_hist_s00, 1'b0};
    wire [7:0] next_hist_1 = {pred_hist_s01, 1'b0};
    wire [7:0] next_hist_2 = {pred_hist_s10, 1'b1};
    wire [7:0] next_hist_3 = {pred_hist_s11, 1'b1};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            surv_hist_0 <= 8'd0;
            surv_hist_1 <= 8'd0;
            surv_hist_2 <= 8'd0;
            surv_hist_3 <= 8'd0;
        end else if (init_smu) begin
            surv_hist_0 <= 8'd0;
            surv_hist_1 <= 8'd0;
            surv_hist_2 <= 8'd0;
            surv_hist_3 <= 8'd0;
        end else if (smu_en) begin
            surv_hist_0 <= next_hist_0;
            surv_hist_1 <= next_hist_1;
            surv_hist_2 <= next_hist_2;
            surv_hist_3 <= next_hist_3;
        end
    end

endmodule
