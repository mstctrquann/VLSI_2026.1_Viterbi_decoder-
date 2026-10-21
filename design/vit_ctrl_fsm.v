// =============================================================================
// Module      : vit_ctrl_fsm
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Stage       : Module 1 - Control Unit (FSM & Trellis Step Counter)
// Description : Coordinates the 5-stage pipeline schedule:
//               - S_IDLE      : Waits for in_valid & in_ready handshake; asserts
//                               load_en and init_pmu to latch frame and init PMU/SMU.
//               - S_PIPE_RUN  : Sweeps step_cnt = 0..7 (8 cycles). Stage 0/1 (BMU)
//                               fetches symbols and registers bm_reg; Stage 2/3
//                               (ACSU/PMU/SMU) runs 1 cycle behind Stage 1.
//               - S_PIPE_DRAIN: Completes Stage 2/3 (ACSU/PMU/SMU) for the 8th
//                               symbol (t = 7).
//               - S_SELECT_OUT: Enables Output PSU (out_en = 1) to select the
//                               Best State (Min-PM) survivor path into dec_out[7:0],
//                               asserts out_valid & done, and returns to S_IDLE.
// =============================================================================

`timescale 1ns / 1ps

module vit_ctrl_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       in_valid,       // Upstream input frame valid
    output reg        in_ready,       // Decoder ready to accept new 16-bit frame
    output reg  [2:0] step_cnt,       // Trellis step counter (t = 0..7)
    output wire       load_en,        // Latch 16-bit data_in into Input PSU buffer
    output wire       init_pmu,       // Initialize PMU (PM[0]=0, PM[1..3]=16) & SMU
    output wire       bmu_en,         // Enable Stage 1 BMU pipeline registers
    output wire       acs_en,         // Enable Stage 2 ACSU/PMU & Stage 3 SMU update
    output wire       out_en,         // Enable Stage 4 Output PSU latch
    output reg        busy,           // Decoder pipeline busy status
    output reg        done            // Frame decoding completion pulse (1 cycle)
);

    // FSM State Encoding
    localparam [1:0] S_IDLE       = 2'd0;
    localparam [1:0] S_PIPE_RUN   = 2'd1;
    localparam [1:0] S_PIPE_DRAIN = 2'd2;
    localparam [1:0] S_SELECT_OUT = 2'd3;

    reg [1:0] state, next_state;

    // Handshake detection in S_IDLE
    wire handshake = (state == S_IDLE) && in_valid && in_ready;

    // Pipeline stage control signals
    assign load_en  = handshake;
    assign init_pmu = handshake;
    assign bmu_en   = (state == S_PIPE_RUN);
    assign out_en   = (state == S_SELECT_OUT);

    // Stage 2 (ACSU/PMU) & Stage 3 (SMU) operate 1 clock cycle after Stage 1 (BMU)
    // i.e., during S_PIPE_RUN (for step_cnt >= 1, processing symbols 0..6) and S_PIPE_DRAIN (processing symbol 7)
    reg bmu_valid_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bmu_valid_d1 <= 1'b0;
        end else begin
            bmu_valid_d1 <= bmu_en;
        end
    end
    assign acs_en = bmu_valid_d1;

    // Next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (in_valid && in_ready)
                    next_state = S_PIPE_RUN;
            end

            S_PIPE_RUN: begin
                if (step_cnt == 3'd7)
                    next_state = S_PIPE_DRAIN;
            end

            S_PIPE_DRAIN: begin
                next_state = S_SELECT_OUT;
            end

            S_SELECT_OUT: begin
                next_state = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end

    // Sequential state, counter, and status outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            step_cnt <= 3'd0;
            in_ready <= 1'b1;
            busy     <= 1'b0;
            done     <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (in_valid && in_ready) begin
                        step_cnt <= 3'd0;
                        in_ready <= 1'b0;
                        busy     <= 1'b1;
                    end else begin
                        in_ready <= 1'b1;
                        busy     <= 1'b0;
                    end
                end

                S_PIPE_RUN: begin
                    done <= 1'b0;
                    busy <= 1'b1;
                    if (step_cnt < 3'd7)
                        step_cnt <= step_cnt + 3'd1;
                end

                S_PIPE_DRAIN: begin
                    done <= 1'b0;
                    busy <= 1'b1;
                end

                S_SELECT_OUT: begin
                    done     <= 1'b1;
                    busy     <= 1'b0;
                    in_ready <= 1'b1;
                end
            endcase
        end
    end

endmodule
