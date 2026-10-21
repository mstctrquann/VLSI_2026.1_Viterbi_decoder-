// =============================================================================
// Module      : vit_pmu
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Module 4 - PMU (Path Metric Unit - Single Bank 4 x 5-bit)
// Description : Maintains the 4 5-bit Path Metric registers (20 Flip-Flops).
//               - On init_pmu: Initializes PM[S00] = 5'd0 and assigns penalty
//                 PM[S01..S11] = 5'd16 to enforce starting at state S00.
//               - On acs_en  : Synchronously updates pm_curr <= pm_next in a
//                 single register bank without bank-swapping overhead.
// =============================================================================

`timescale 1ns / 1ps

module vit_pmu (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       init_pmu,       // Initialize PM bank at start of frame
    input  wire       acs_en,         // Update PM bank at each Trellis step
    input  wire [4:0] pm_next_0,      // Next PM for S00 from ACSU
    input  wire [4:0] pm_next_1,      // Next PM for S01 from ACSU
    input  wire [4:0] pm_next_2,      // Next PM for S10 from ACSU
    input  wire [4:0] pm_next_3,      // Next PM for S11 from ACSU
    output reg  [4:0] pm_curr_0,      // Current PM for S00
    output reg  [4:0] pm_curr_1,      // Current PM for S01
    output reg  [4:0] pm_curr_2,      // Current PM for S10
    output reg  [4:0] pm_curr_3       // Current PM for S11
);

    localparam [4:0] PM_INIT_ZERO    = 5'd0;
    localparam [4:0] PM_INIT_PENALTY = 5'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pm_curr_0 <= PM_INIT_ZERO;
            pm_curr_1 <= PM_INIT_PENALTY;
            pm_curr_2 <= PM_INIT_PENALTY;
            pm_curr_3 <= PM_INIT_PENALTY;
        end else if (init_pmu) begin
            pm_curr_0 <= PM_INIT_ZERO;
            pm_curr_1 <= PM_INIT_PENALTY;
            pm_curr_2 <= PM_INIT_PENALTY;
            pm_curr_3 <= PM_INIT_PENALTY;
        end else if (acs_en) begin
            pm_curr_0 <= pm_next_0;
            pm_curr_1 <= pm_next_1;
            pm_curr_2 <= pm_next_2;
            pm_curr_3 <= pm_next_3;
        end
    end

endmodule
