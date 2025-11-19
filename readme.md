# Hack ALU Implementation on Artix-7 FPGA

## 概要
本プロジェクトは、Nand2Tetris (The Elements of Computing Systems) で定義される「Hack Computer」の中核モジュールである ALU (Arithmetic Logic Unit) を、SystemVerilogを用いてFPGA上に実装したものです。以前のプロジェクトではNANDゲートのみを用いたボトムアップ構築を行いましたが、本プロジェクトでは SystemVerilog (IEEE 1800-2017) の強力な演算子を活用し、Xilinx Vivado 開発フローに基づいた、合成可能で効率的なRTL設計を行っています。

## 開発環境
- **IDE:** Xilinx Vivado 2025.1
- **Hardware:** Digilent Basys 3 (Xilinx Artix-7 XC7A35T-1CPG236C)
- **Language:** SystemVerilog
- **Simulation:** Vivado Simulator (xsim)

## 仕様 (Hack ALU Specification)
Hack ALUは、2つの16ビット入力（x, y）と6つの制御ビットを受け取り、算術演算または論理演算を行った結果（out）と2つの状態フラグ（zr, ng）を出力します。

### 入出力ポート

| ポート名 | ビット幅 | 方向 | 説明 |
|---------|---------|------|------|
| x | 16 | Input | データ入力 X (2の補数表現) |
| y | 16 | Input | データ入力 Y (2の補数表現) |
| zx | 1 | Input | Zero the x input |
| nx | 1 | Input | Negate the x input |
| zy | 1 | Input | Zero the y input |
| ny | 1 | Input | Negate the y input |
| f | 1 | Input | Function code (1: Add, 0: And) |
| no | 1 | Input | Negate the out output |
| out | 16 | Output | 演算結果 |
| zr | 1 | Output | Zero flag (out == 0 なら 1) |
| ng | 1 | Output | Negative flag (out < 0 なら 1) |

### 内部ロジック
制御ビットに基づき、以下の4段階のパイプライン的な処理（組み合わせ回路）を経て結果が生成されます。

1. **前処理:** zx/zy によるゼロ化、nx/ny によるビット反転。
2. **演算:** f ビットにより、加算 (+) または 論理積 (&) を選択。
3. **後処理:** no ビットにより、結果をビット反転。
4. **フラグ生成:** 結果に基づき zr, ng を生成。

## 実装詳細 (Implementation)

### RTL設計 (hack_alu.sv)

**コーディング規約準拠:**
- `wire`/`reg` の代わりに `logic` 型を使用し、意図しない振る舞いを防止。
- `always_comb` ブロックを使用し、ラッチ生成を回避した完全な組み合わせ回路として記述。

**可読性:** 三項演算子 (cond ? a : b) を多用し、仕様書のデータフローを直感的に表現。

### 実機統合 (alu_fpga_top.sv)
Basys 3 の物理スイッチは16個しかなく、ALUの全入力（38ビット）を同時に制御できません。そのため、内部レジスタとロードボタンを用いた入力方式を実装しました。

**デバウンス処理:** 機械式ボタンのチャタリング（ノイズ）を除去するため、2段シンクロナイザとカウンタを用いたデバウンサ (`button_debouncer.sv`) を実装し、堅牢性を確保しています。

## 実機操作マニュアル (Basys 3)

### ピン割り当て概要
- **SW [15:0]:** データバス（値の設定用）
- **BTN:** レジスタへのロード操作
- **LED [15:0]:** ALU演算結果の表示

### 操作フロー
1. **リセット:** BTN C (Center) を押し、全レジスタをクリアします。
2. **X入力の設定:** SW で値を設定し、BTN U (Up) を押してロードします。
3. **Y入力の設定:** SW で値を設定し、BTN D (Down) を押してロードします。
4. **演算実行:** SW [5:0] で制御コードを設定し、BTN L (Left) を押してロードします。
5. **結果確認:** LED に演算結果が表示されます。

### 主な制御コード表 (SW5 -> SW0)

| 演算 | 制御コード (Binary) | SW設定 (1=ON) |
|------|---------------------|---------------|
| Add (X + Y) | 000010 | SW1 |
| Sub (X - Y) | 010011 | SW4, SW1, SW0 |
| And (X & Y) | 000000 | 全てOFF |
| Or (X\|Y) | 010101 | SW4, SW2, SW0 |
| Pass X | 001100 | SW3, SW2 |
| Constant 0 | 101010 | SW5, SW3, SW1 |
| Constant -1 | 111010 | SW5, SW4, SW3, SW1 |

## 検証 (Verification)

### シミュレーション (hack_alu_tb.sv)
- **手法:** セルフチェック方式のテストベンチ。
- **範囲:** 仕様書で定義された18種類の全演算機能に加え、ランダムパターンによるストレステストを実施。
- **結果:** 全テストケースにおいてアサーションエラーなしで通過。

### 実機テスト
- **デバイス:** Basys 3 (Artix-7)
- **確認項目:** データのロード機能、基本的な算術演算、論理演算、およびリセット動作が正常であることを確認済み。

## ディレクトリ構成

```
.
├── rtl/
│   ├── hack_alu.sv          # ALUコアモジュール
│   ├── alu_fpga_top.sv      # FPGAトップレベルモジュール
│   └── button_debouncer.sv  # チャタリング除去モジュール
├── tb/
│   └── hack_alu_tb.sv       # テストベンチ
└── xdc/
    └── Basys3_ALU.xdc       # 物理制約ファイル
```