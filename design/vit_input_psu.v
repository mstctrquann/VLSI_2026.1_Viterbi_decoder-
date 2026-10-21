// =============================================================================
// Module      : vit_input_psu
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Stage 0 - Input PSU (Parallel-to-Serial Unit & Input Buffer)
// Description : Latches a 16-bit encoded frame (data_in[15:0]) upon valid/ready
//               handshake and serializes it into 8 pairs of 2-bit symbols
//               (curr_sym[1:0]) using an 8:1 MUX indexed by step_cnt[2:0].
// =============================================================================

`timescale 1ns / 1ps

module vit_input_psu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load_en,       // Latch enable on handshake (in_valid & in_ready)
    input  wire [2:0]  step_cnt,      // Trellis step counter (t = 0..7)
    input  wire [15:0] data_in,       // 16-bit encoded input frame
    output reg  [1:0]  curr_sym       // Current 2-bit symbol {O1, O2}
);

    // 16-bit Input Frame Buffer Register
    reg [15:0] in_buf_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_buf_reg <= 16'd0;
        end else if (load_en) begin
            in_buf_reg <= data_in;
        end
    end

    // 8:1 Symbol Multiplexer (Parallel-to-Serial conversion)
    // Symbol 0 (t=0) is at MSB [15:14], Symbol 7 (t=7) is at LSB [1:0]
    always @(*) begin
        case (step_cnt)
            3'd0:    curr_sym = in_buf_reg[15:14];
            3'd1:    curr_sym = in_buf_reg[13:12];
            3'd2:    curr_sym = in_buf_reg[11:10];
            3'd3:    curr_sym = in_buf_reg[9:8];
            3'd4:    curr_sym = in_buf_reg[7:6];
            3'd5:    curr_sym = in_buf_reg[5:4];
            3'd6:    curr_sym = in_buf_reg[3:2];
            3'd7:    curr_sym = in_buf_reg[1:0];
            default: curr_sym = 2'b00;
        endcase
    end

endmodule
