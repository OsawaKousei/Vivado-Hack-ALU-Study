`timescale 1ns / 1ps

module alu_fpga_top (
    input  logic        clk,      // Clock 100MHz
    input  logic        btnC,     // Reset (Active High on board)
    input  logic        btnU,     // Load X
    input  logic        btnD,     // Load Y
    input  logic        btnL,     // Load Control
    input  logic [15:0] sw,       // Data Input
    output logic [15:0] led       // ALU Output
);

    // リセット信号の生成 (内部はActive Low: reset_n で統一)
    logic reset_n;
    assign reset_n = ~btnC; // ボタンは押すとHighなので反転

    // 内部レジスタ
    logic [15:0] reg_x;
    logic [15:0] reg_y;
    logic [5:0]  reg_ctrl;

    // デバウンス後のボタン信号
    logic pulse_load_x;
    logic pulse_load_y;
    logic pulse_load_ctrl;

    // -----------------------------------------------------
    // 1. ボタン入力のデバウンス & パルス化
    // -----------------------------------------------------
    button_debouncer db_u (.clk(clk), .reset_n(reset_n), .btn_in(btnU), .btn_out(pulse_load_x));
    button_debouncer db_d (.clk(clk), .reset_n(reset_n), .btn_in(btnD), .btn_out(pulse_load_y));
    button_debouncer db_l (.clk(clk), .reset_n(reset_n), .btn_in(btnL), .btn_out(pulse_load_ctrl));

    // -----------------------------------------------------
    // 2. 入力レジスタ制御 (順序回路)
    // -----------------------------------------------------
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            reg_x    <= '0;
            reg_y    <= '0;
            reg_ctrl <= 6'b101010; // デフォルト: 0出力 (Zero X&Y, Add)
        end else begin
            if (pulse_load_x)    reg_x    <= sw;
            if (pulse_load_y)    reg_y    <= sw;
            if (pulse_load_ctrl) reg_ctrl <= sw[5:0]; // 下位6bitのみ使用
        end
    end

    // -----------------------------------------------------
    // 3. Hack ALU インスタンス化
    // -----------------------------------------------------
    logic [15:0] alu_out;
    logic        zr_flag;
    logic        ng_flag;

    hack_alu u_alu (
        .x   (reg_x),
        .y   (reg_y),
        .zx  (reg_ctrl[5]),
        .nx  (reg_ctrl[4]),
        .zy  (reg_ctrl[3]),
        .ny  (reg_ctrl[2]),
        .f   (reg_ctrl[1]),
        .no  (reg_ctrl[0]),
        .out (alu_out),
        .zr  (zr_flag),
        .ng  (ng_flag)
    );

    // -----------------------------------------------------
    // 4. 出力 (LED駆動)
    // -----------------------------------------------------
    assign led = alu_out;

endmodule