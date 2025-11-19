`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: hack_alu_tb
// Project: Hack Computer ALU Verification
// Description: 
//   hack_aluモジュールの機能検証用テストベンチ。
//   18種類の演算機能について、制御ビットを与えて期待通りの出力が得られるか自動チェックする。
//   また、ランダムパターンによるストレステストも実施する。
//////////////////////////////////////////////////////////////////////////////////

module hack_alu_tb;

    // 信号定義
    logic [15:0] x;
    logic [15:0] y;
    logic        zx, nx, zy, ny, f, no;
    logic [15:0] out;
    logic        zr, ng;

    // 制御ビットをまとめたバス (可読性のため)
    logic [5:0]  ctrl;
    assign {zx, nx, zy, ny, f, no} = ctrl;

    // DUT (Device Under Test) のインスタンス化
    hack_alu dut (
        .x(x),
        .y(y),
        .zx(zx), .nx(nx), .zy(zy), .ny(ny), .f(f), .no(no),
        .out(out),
        .zr(zr),
        .ng(ng)
    );

    // ---------------------------------------------------------
    // 検証用タスク: 期待値との比較を自動化
    // ---------------------------------------------------------
    task check_calc(
        input [5:0]  c_bits,       // 制御ビット
        input [15:0] expected_val, // 期待される演算結果
        input string test_name     // テスト名
    );
        begin
            ctrl = c_bits;
            #10; // 回路の遅延を待つ

            // 結果の検証 (SystemVerilogのアサーション)
            assert (out === expected_val) 
                else $error("[FAILED] %s: Ctrl=%b, Expected=%h, Got=%h", test_name, c_bits, expected_val, out);
            
            // フラグの検証
            if (expected_val == 0)
                assert (zr === 1) else $error("[FAILED] %s: zr flag should be 1", test_name);
            else
                assert (zr === 0) else $error("[FAILED] %s: zr flag should be 0", test_name);

            if (expected_val[15] === 1)
                assert (ng === 1) else $error("[FAILED] %s: ng flag should be 1", test_name);
            else
                assert (ng === 0) else $error("[FAILED] %s: ng flag should be 0", test_name);
        end
    endtask

    // ---------------------------------------------------------
    // メインテストプロセス
    // ---------------------------------------------------------
    initial begin
        $display("=== Hack ALU Simulation Start ===");

        // 固定パターンでの機能検証
        x = 16'h00AB; // テスト用入力 X
        y = 16'h1234; // テスト用入力 Y
        
        $display("Test Inputs: x = %h, y = %h", x, y);

        // --- 18種類の基本機能テスト (Section 4のロジックに基づく制御コード) ---
        
        // 1. 0 (Zero) -> zx=1, nx=0, zy=1, ny=0, f=1, no=0
        check_calc(6'b101010, 16'h0000, "CONST_ZERO");

        // 2. 1 (One) -> zx=1, nx=1, zy=1, ny=1, f=1, no=1
        // 0 -> !0(-1) -> 0 -> !0(-1) -> -1 + -1 = -2 -> !(-2) = 1
        check_calc(6'b111111, 16'h0001, "CONST_ONE");

        // 3. -1 (Minus One) -> zx=1, nx=1, zy=1, ny=0, f=1, no=0
        // 0 -> !0(-1) -> 0 -> -1 + 0 = -1
        check_calc(6'b111010, 16'hFFFF, "CONST_MINUS_ONE");

        // 4. x (Pass X) -> zx=0, nx=0, zy=1, ny=1, f=0, no=0
        // x & !0(-1) = x
        check_calc(6'b001100, x, "PASS_X");

        // 5. y (Pass Y) -> zx=1, nx=1, zy=0, ny=0, f=0, no=0
        // !0(-1) & y = y
        check_calc(6'b110000, y, "PASS_Y");

        // 6. !x (Not X) -> zx=0, nx=0, zy=1, ny=1, f=0, no=1
        // !(x & -1) = !x
        check_calc(6'b001101, ~x, "NOT_X");

        // 7. !y (Not Y) -> zx=1, nx=1, zy=0, ny=0, f=0, no=1
        // !(-1 & y) = !y
        check_calc(6'b110001, ~y, "NOT_Y");

        // 8. -x (Neg X) -> zx=0, nx=0, zy=1, ny=1, f=1, no=1
        // ! (x + -1) = ! (x-1) = -(x-1)-1 = -x + 1 - 1 = -x
        check_calc(6'b001111, -x, "NEG_X");

        // 9. -y (Neg Y) -> zx=1, nx=1, zy=0, ny=0, f=1, no=1
        // ! (-1 + y) = ! (y-1) = -y
        check_calc(6'b110011, -y, "NEG_Y");

        // 10. x + 1 (Inc X) -> zx=0, nx=1, zy=1, ny=1, f=1, no=1
        // ! (!x + -1) = ! (-x-1 -1) = !(-x-2) = -(-x-2)-1 = x+2-1 = x+1
        check_calc(6'b011111, x + 1, "INC_X");

        // 11. y + 1 (Inc Y) -> zx=1, nx=1, zy=0, ny=1, f=1, no=1
        // ! (-1 + !y) = ! (-1 -y -1) = !(-y-2) = y+1
        check_calc(6'b110111, y + 1, "INC_Y");

        // 12. x - 1 (Dec X) -> zx=0, nx=0, zy=1, ny=1, f=1, no=0
        // x + (-1)
        check_calc(6'b001110, x - 1, "DEC_X");

        // 13. y - 1 (Dec Y) -> zx=1, nx=1, zy=0, ny=0, f=1, no=0
        // -1 + y
        check_calc(6'b110010, y - 1, "DEC_Y");

        // 14. x + y (Add) -> zx=0, nx=0, zy=0, ny=0, f=1, no=0
        check_calc(6'b000010, x + y, "ADD_XY");

        // 15. x - y (Sub) -> zx=0, nx=1, zy=0, ny=0, f=1, no=1
        // ! (!x + y) = ! (-x -1 + y) = -(-x + y -1) -1 = x - y + 1 - 1 = x - y
        check_calc(6'b010011, x - y, "SUB_XY");

        // 16. y - x (Sub) -> zx=0, nx=0, zy=0, ny=1, f=1, no=1
        // ! (x + !y) = ! (x -y -1) = -(x -y -1) -1 = -x + y + 1 -1 = y - x
        check_calc(6'b000111, y - x, "SUB_YX");

        // 17. x & y (And) -> zx=0, nx=0, zy=0, ny=0, f=0, no=0
        check_calc(6'b000000, x & y, "AND_XY");

        // 18. x | y (Or) -> zx=0, nx=1, zy=0, ny=1, f=0, no=1
        // ! (!x & !y) = x | y (De Morgan)
        check_calc(6'b010101, x | y, "OR_XY");


        // --- ランダムテスト ---
        $display("--- Starting Random Tests ---");
        repeat (100) begin
            x = $random;
            y = $random;
            // 加算 (ADD) のランダムチェック
            check_calc(6'b000010, x + y, "RANDOM_ADD");
            // AND のランダムチェック
            check_calc(6'b000000, x & y, "RANDOM_AND");
        end

        $display("=== Hack ALU Simulation Completed ===");
        $finish;
    end

endmodule
