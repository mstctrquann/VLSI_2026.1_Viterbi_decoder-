// =============================================================================
// Module      : viterbi_top
// Project     : Viterbi Decoder (K=3, R=1/2, G1=111, G2=101) - Generalized PA2
// Description : Top-level 5-Stage Pipelined Viterbi Decoder integrating:
//               - Stage 0 : vit_input_psu  (16-bit Input Buffer & 8:1 Symbol MUX)
//               - Module 1: vit_ctrl_fsm   (Pipeline Control FSM & Step Counter)
//               - Stage 1 : vit_bmu        (4x Parallel Hamming Distance + Regs)
//               - Stage 2 : vit_acsu       (4x Parallel Add-Compare-Select)
//               - Module 4: vit_pmu        (Single-Bank 4 x 5-bit Path Metric Unit)
//               - Stage 3 : vit_smu_re     (4 x 8-bit Register-Exchange SMU)
//               - Stage 4 : vit_output_psu (Min-PM Best State Selector & Output Reg)
// =============================================================================

`timescale 1ns / 1ps

module viterbi_top (
    input  wire        clk,           // System clock
    input  wire        rst_n,         // Asynchronous active-low reset
    input  wire [15:0] data_in,       // 16-bit encoded input frame (8 symbols)
    input  wire        in_valid,      // Input frame valid handshake signal
    output wire        in_ready,      // Decoder ready handshake signal
    output wire [7:0]  dec_out,       // 8-bit decoded information output
    output wire        out_valid,     // Decoded output valid pulse (1 cycle)
    output wire        busy,          // Decoder busy status
    output wire        done           // Frame decoding done pulse (1 cycle)
);

    // -------------------------------------------------------------------------
    // Internal Interconnect Signals
    // -------------------------------------------------------------------------
    // Control FSM signals
    wire [2:0] step_cnt;
    wire       load_en;
    wire       init_pmu;
    wire       bmu_en;
    wire       acs_en;
    wire       out_en;

    // Stage 0 -> Stage 1
    wire [1:0] curr_sym;

    // Stage 1 -> Stage 2
    wire [1:0] bm_00_reg;
    wire [1:0] bm_01_reg;
    wire [1:0] bm_10_reg;
    wire [1:0] bm_11_reg;

    // Stage 2 <-> PMU (5-bit Path Metrics)
    wire [4:0] pm_curr_0, pm_curr_1, pm_curr_2, pm_curr_3;
    wire [4:0] pm_next_0, pm_next_1, pm_next_2, pm_next_3;

    // Stage 2 -> Stage 3 (Survivor Decisions)
    wire [3:0] decisions;

    // Stage 3 -> Stage 4 (4 x 8-bit Survivor Histories)
    wire [7:0] surv_hist_0, surv_hist_1, surv_hist_2, surv_hist_3;
    wire [1:0] best_state;

    // -------------------------------------------------------------------------
    // Module 1: Control Unit (FSM & Trellis Step Counter)
    // -------------------------------------------------------------------------
    vit_ctrl_fsm u_ctrl_fsm (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .step_cnt  (step_cnt),
        .load_en   (load_en),
        .init_pmu  (init_pmu),
        .bmu_en    (bmu_en),
        .acs_en    (acs_en),
        .out_en    (out_en),
        .busy      (busy),
        .done      (done)
    );

    // -------------------------------------------------------------------------
    // Stage 0: Input PSU (Parallel-to-Serial Unit & Input Buffer)
    // -------------------------------------------------------------------------
    vit_input_psu u_input_psu (
        .clk       (clk),
        .rst_n     (rst_n),
        .load_en   (load_en),
        .step_cnt  (step_cnt),
        .data_in   (data_in),
        .curr_sym  (curr_sym)
    );

    // -------------------------------------------------------------------------
    // Stage 1: BMU (Branch Metric Unit + Pipeline Stage 1 Registers)
    // -------------------------------------------------------------------------
    vit_bmu u_bmu (
        .clk       (clk),
        .rst_n     (rst_n),
        .bmu_en    (bmu_en),
        .curr_sym  (curr_sym),
        .bm_00_reg (bm_00_reg),
        .bm_01_reg (bm_01_reg),
        .bm_10_reg (bm_10_reg),
        .bm_11_reg (bm_11_reg)
    );

    // -------------------------------------------------------------------------
    // Stage 2: ACSU (4x Parallel Add-Compare-Select Unit)
    // -------------------------------------------------------------------------
    vit_acsu u_acsu (
        .bm_00     (bm_00_reg),
        .bm_01     (bm_01_reg),
        .bm_10     (bm_10_reg),
        .bm_11     (bm_11_reg),
        .pm_curr_0 (pm_curr_0),
        .pm_curr_1 (pm_curr_1),
        .pm_curr_2 (pm_curr_2),
        .pm_curr_3 (pm_curr_3),
        .pm_next_0 (pm_next_0),
        .pm_next_1 (pm_next_1),
        .pm_next_2 (pm_next_2),
        .pm_next_3 (pm_next_3),
        .decisions (decisions)
    );

    // -------------------------------------------------------------------------
    // Module 4: PMU (Single-Bank 4 x 5-bit Path Metric Unit)
    // -------------------------------------------------------------------------
    vit_pmu u_pmu (
        .clk       (clk),
        .rst_n     (rst_n),
        .init_pmu  (init_pmu),
        .acs_en    (acs_en),
        .pm_next_0 (pm_next_0),
        .pm_next_1 (pm_next_1),
        .pm_next_2 (pm_next_2),
        .pm_next_3 (pm_next_3),
        .pm_curr_0 (pm_curr_0),
        .pm_curr_1 (pm_curr_1),
        .pm_curr_2 (pm_curr_2),
        .pm_curr_3 (pm_curr_3)
    );

    // -------------------------------------------------------------------------
    // Stage 3: SMU (Register-Exchange 4 x 8 Flip-Flop Matrix)
    // -------------------------------------------------------------------------
    vit_smu_re u_smu_re (
        .clk         (clk),
        .rst_n       (rst_n),
        .init_smu    (init_pmu),
        .smu_en      (acs_en),
        .decisions   (decisions),
        .surv_hist_0 (surv_hist_0),
        .surv_hist_1 (surv_hist_1),
        .surv_hist_2 (surv_hist_2),
        .surv_hist_3 (surv_hist_3)
    );

    // -------------------------------------------------------------------------
    // Stage 4: Output PSU (Path Selection Unit / Best State Selector & Reg)
    // -------------------------------------------------------------------------
    vit_output_psu u_output_psu (
        .clk         (clk),
        .rst_n       (rst_n),
        .out_en      (out_en),
        .pm_curr_0   (pm_curr_0),
        .pm_curr_1   (pm_curr_1),
        .pm_curr_2   (pm_curr_2),
        .pm_curr_3   (pm_curr_3),
        .surv_hist_0 (surv_hist_0),
        .surv_hist_1 (surv_hist_1),
        .surv_hist_2 (surv_hist_2),
        .surv_hist_3 (surv_hist_3),
        .best_state  (best_state),
        .dec_out     (dec_out),
        .out_valid   (out_valid)
    );

endmodule
