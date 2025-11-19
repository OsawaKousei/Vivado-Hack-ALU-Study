`timescale 1ns / 1ps

module button_debouncer (
    input  logic clk,
    input  logic reset_n,
    input  logic btn_in,
    output logic btn_out // ワンショットパルス（押した瞬間に1クロックだけHigh）
);

    // 1. メタスタビリティ対策: 2段シンクロナイザ [cite: 1507]
    logic sync_0, sync_1;
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            sync_0 <= 1'b0;
            sync_1 <= 1'b0;
        end else begin
            sync_0 <= btn_in;
            sync_1 <= sync_0;
        end
    end

    // 2. デバウンス処理 (約10ms待機)
    // 100MHz clock -> 10ms = 1,000,000 cycles
    // 20bit counter covers ~1,048,576
    logic [19:0] counter;
    logic        debounced_state;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            counter <= '0;
            debounced_state <= 1'b0;
        end else begin
            if (sync_1 != debounced_state) begin
                counter <= counter + 1;
                if (counter == 20'hFFFFF) begin
                    debounced_state <= sync_1;
                    counter <= '0;
                end
            end else begin
                counter <= '0;
            end
        end
    end

    // 3. エッジ検出 (立ち上がり検出)
    logic prev_state;
    always_ff @(posedge clk) begin
        if (!reset_n) begin
            prev_state <= 1'b0;
            btn_out    <= 1'b0;
        end else begin
            prev_state <= debounced_state;
            btn_out    <= debounced_state & ~prev_state; // 立ち上がりエッジでパルス生成
        end
    end

endmodule