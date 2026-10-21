// =============================================================================
// Module      : vit_bmu
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Stage 1 - BMU (Branch Metric Unit)
// Description : Computes 4 parallel 2-bit Hamming distances between the current
//               2-bit received symbol (curr_sym[1:0]) and the 4 expected branch
//               outputs (00, 01, 10, 11), and latches them into Pipeline Stage 1
//               registers (bm_00_reg, bm_01_reg, bm_10_reg, bm_11_reg).
// =============================================================================

`timescale 1ns / 1ps

module vit_bmu (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       bmu_en,         // Enable latching Stage 1 pipeline registers
    input  wire [1:0] curr_sym,       // Current received symbol {r1, r0}
    output reg  [1:0] bm_00_reg,      // Registered Hamming distance to 2'b00
    output reg  [1:0] bm_01_reg,      // Registered Hamming distance to 2'b01
    output reg  [1:0] bm_10_reg,      // Registered Hamming distance to 2'b10
    output reg  [1:0] bm_11_reg       // Registered Hamming distance to 2'b11
);

    wire r1 = curr_sym[1];
    wire r0 = curr_sym[0];

    // Combinational Hamming distance calculation (range: 0, 1, 2)
    wire [1:0] bm_00_comb = {1'b0, r1}  + {1'b0, r0};
    wire [1:0] bm_01_comb = {1'b0, r1}  + {1'b0, ~r0};
    wire [1:0] bm_10_comb = {1'b0, ~r1} + {1'b0, r0};
    wire [1:0] bm_11_comb = {1'b0, ~r1} + {1'b0, ~r0};

    // Pipeline Stage 1 Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bm_00_reg <= 2'd0;
            bm_01_reg <= 2'd0;
            bm_10_reg <= 2'd0;
            bm_11_reg <= 2'd0;
        end else if (bmu_en) begin
            bm_00_reg <= bm_00_comb;
            bm_01_reg <= bm_01_comb;
            bm_10_reg <= bm_10_comb;
            bm_11_reg <= bm_11_comb;
        end
    end

endmodule
