// =============================================================================
// Module      : vit_output_psu
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Stage 4 - Output PSU (Path Selection Unit / Best State Selector)
// Description : Generalized output selection block capable of decoding any
//               arbitrary 8-bit information sequence (with or without tail bits):
//               1. 2-Level Min-PM Comparator Tree (3 x 5-bit comparators):
//                  Finds best_state[1:0] = argmin_{j in 0..3} (pm_curr[j])
//               2. 4:1 Multiplexer (8-bit):
//                  Selects surv_hist[best_state][7:0]
//               3. Output Register:
//                  Latches dec_out[7:0] and asserts out_valid for 1 clock cycle.
// =============================================================================

`timescale 1ns / 1ps

module vit_output_psu (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       out_en,         // Latch selected 8-bit survivor path to output
    input  wire [4:0] pm_curr_0,      // Final Path Metric of State S00
    input  wire [4:0] pm_curr_1,      // Final Path Metric of State S01
    input  wire [4:0] pm_curr_2,      // Final Path Metric of State S10
    input  wire [4:0] pm_curr_3,      // Final Path Metric of State S11
    input  wire [7:0] surv_hist_0,    // 8-bit survivor path of State S00
    input  wire [7:0] surv_hist_1,    // 8-bit survivor path of State S01
    input  wire [7:0] surv_hist_2,    // 8-bit survivor path of State S10
    input  wire [7:0] surv_hist_3,    // 8-bit survivor path of State S11
    output wire [1:0] best_state,     // Winning state index with minimum Path Metric
    output reg  [7:0] dec_out,        // 8-bit decoded output frame
    output reg        out_valid       // Output valid pulse (1 clock cycle)
);

    // -------------------------------------------------------------------------
    // Level 1 Comparators: Compare (S00 vs S01) and (S10 vs S11)
    // -------------------------------------------------------------------------
    wire       cmp_01    = (pm_curr_1 < pm_curr_0);
    wire [4:0] min_pm_01 = cmp_01 ? pm_curr_1 : pm_curr_0;
    wire [1:0] idx_01    = {1'b0, cmp_01};

    wire       cmp_23    = (pm_curr_3 < pm_curr_2);
    wire [4:0] min_pm_23 = cmp_23 ? pm_curr_3 : pm_curr_2;
    wire [1:0] idx_23    = {1'b1, cmp_23};

    // -------------------------------------------------------------------------
    // Level 2 Comparator: Compare winner of (0,1) vs winner of (2,3)
    // -------------------------------------------------------------------------
    wire       cmp_final  = (min_pm_23 < min_pm_01);
    assign     best_state = cmp_final ? idx_23 : idx_01;

    // -------------------------------------------------------------------------
    // 4:1 Multiplexer: Select 8-bit decoded bit sequence of best_state
    // -------------------------------------------------------------------------
    reg [7:0] selected_hist;
    always @(*) begin
        case (best_state)
            2'd0:    selected_hist = surv_hist_0;
            2'd1:    selected_hist = surv_hist_1;
            2'd2:    selected_hist = surv_hist_2;
            2'd3:    selected_hist = surv_hist_3;
            default: selected_hist = surv_hist_0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Stage 4 Output Register
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dec_out   <= 8'd0;
            out_valid <= 1'b0;
        end else if (out_en) begin
            dec_out   <= selected_hist;
            out_valid <= 1'b1;
        end else begin
            out_valid <= 1'b0;
        end
    end

endmodule
