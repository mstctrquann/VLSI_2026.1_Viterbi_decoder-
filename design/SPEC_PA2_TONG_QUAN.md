# Đặc Tả Kỹ Thuật Phần Cứng (Hardware Specification) — Phương Án 2 (Phiên Bản Tổng Quát)

> **Dự án:** Thiết kế Bộ Giải Mã Viterbi ($K = 3, R = 1/2, G_1 = 111_2, G_2 = 101_2$)  
> **Thư mục thiết kế:** `design/`  
> **Kiến trúc:** Pipeline 5 tầng tổng quát (Input PSU $\to$ BMU $\to$ 4x ACSU & PMU 5-bit $\to$ SMU Register-Exchange $4 \times 8$ $\to$ Output PSU Best State Selector)

---

## 1. Danh Mục Các Khối Phần Cứng Trong `design/`

| STT | Tên Module | File Verilog | Tầng / Vai trò chức năng | Số Flip-Flop |
| :-: | :--- | :--- | :--- | :-: |
| 1 | `viterbi_top` | [`viterbi_top.v`](viterbi_top.v) | Module đỉnh (Top-level) kết nối toàn bộ 5 tầng Pipeline & FSM | — |
| 2 | `vit_ctrl_fsm` | [`vit_ctrl_fsm.v`](vit_ctrl_fsm.v) | **Module 1 (Control Unit):** FSM 4 trạng thái & Bộ đếm bước Trellis `step_cnt[2:0]` | 9 FF |
| 3 | `vit_input_psu` | [`vit_input_psu.v`](vit_input_psu.v) | **Stage 0 (Input PSU):** Thanh ghi đệm 16-bit & Bộ chuyển đổi Song song $\to$ Nối tiếp (MUX 8:1) | 16 FF |
| 4 | `vit_bmu` | [`vit_bmu.v`](vit_bmu.v) | **Stage 1 (BMU):** Tính song song 4 khoảng cách Hamming 2-bit & Thanh ghi tầng Stage 1 | 8 FF |
| 5 | `vit_acs_node` | [`vit_acs_node.v`](vit_acs_node.v) | **Hạt nhân 1 nút ACS:** Cộng 5-bit (`PM + BM`) $\to$ So sánh (`C1 < C0`) $\to$ Chọn MUX 2:1 | 0 FF (Tổ hợp) |
| 6 | `vit_acsu` | [`vit_acsu.v`](vit_acsu.v) | **Stage 2 (ACSU):** 4 bộ `vit_acs_node` song song cho 4 trạng thái $S_{00}, S_{01}, S_{10}, S_{11}$ | 0 FF (Tổ hợp) |
| 7 | `vit_pmu` | [`vit_pmu.v`](vit_pmu.v) | **Module 4 (PMU):** 1 Bank gồm $4 \times 5\text{-bit}$ Flip-Flop lưu Path Metric ($PM[0]=0, PM[1..3]=16$) | 20 FF |
| 8 | `vit_smu_re` | [`vit_smu_re.v`](vit_smu_re.v) | **Stage 3 (SMU):** Ma trận Register-Exchange $4 \times 8$ Flip-Flop lưu vết sống sót động | 32 FF |
| 9 | `vit_output_psu`| [`vit_output_psu.v`](vit_output_psu.v) | **Stage 4 (Output PSU):** Cây 3 bộ Comparator tìm $\min(PM)$, MUX 4:1 & Thanh ghi `dec_out[7:0]` | 9 FF |
| 10 | `tb_viterbi_top`| [`tb_viterbi_top.v`](tb_viterbi_top.v) | Testbench tự động kiểm tra 1025 vector từ `vectors/input.txt` đối chiếu `vectors/output.txt` | — |

> **Tổng số thanh ghi toàn mạch (Phiên bản Tổng quát):** **94 Flip-Flop** (hoàn toàn không dùng SRAM / Memory Compiler).

---

## 2. Giao Diện Cổng Module Đỉnh (`viterbi_top`)

| Tên tín hiệu | Hướng | Độ rộng | Mô tả chức năng |
| :--- | :---: | :---: | :--- |
| `clk` | Input | 1 | Xung nhịp hệ thống đồng bộ toàn mạch (kích hoạt sườn lên `posedge`). |
| `rst_n` | Input | 1 | Tín hiệu Reset bất đồng bộ tích cực mức thấp (`0`: Reset, `1`: Hoạt động). |
| `data_in[15:0]` | Input | 16 | Khung dữ liệu 16-bit mã hóa đầu vào (`[15:14]` là symbol $t=0$, `[1:0]` là symbol $t=7$). |
| `in_valid` | Input | 1 | Cờ báo dữ liệu `data_in[15:0]` hợp lệ từ phía phát. |
| `in_ready` | Output | 1 | Cờ báo bộ giải mã sẵn sàng nhận khung mới (bắt tay khi `in_valid && in_ready`). |
| `dec_out[7:0]` | Output | 8 | Khung dữ liệu 8-bit thông tin gốc đã giải mã (`dec_out[7]` là $u_0$, `dec_out[0]` là $u_7$). |
| `out_valid` | Output | 1 | Xung báo dữ liệu `dec_out[7:0]` hợp lệ (tích cực mức cao trong 1 chu kỳ clock). |
| `busy` | Output | 1 | Báo bộ giải mã đang bận xử lý khung dữ liệu trong đường ống pipeline. |
| `done` | Output | 1 | Xung báo hoàn tất giải mã một khung (tích cực 1 chu kỳ cùng thời điểm với `out_valid`). |

---

## 3. Thiết Kế Chi Tiết Từng Khối Chức Năng

### 3.1. Stage 0: Input PSU (`vit_input_psu.v`)
- **Chức năng:** Nhận khung 16-bit song song `data_in[15:0]` khi `load_en = 1` và tuần tự hóa thành 8 cặp bit `curr_sym[1:0]` theo `step_cnt[2:0]`.
- **Bảng ánh xạ MUX 8:1:**
  $$\text{curr\_sym}[1:0] = \text{in\_buf\_reg}[15 - 2 \cdot \text{step\_cnt} \text{ -: } 2]$$
  Trong đó `curr_sym[1]` tương ứng với bit mã hóa $O_1$ và `curr_sym[0]` tương ứng với bit mã hóa $O_2$.

### 3.2. Stage 1: Branch Metric Unit (`vit_bmu.v`)
- **Chức năng:** Tính song song 4 khoảng cách Hamming 2-bit giữa `curr_sym = {r1, r0}` với 4 cặp bit nhánh lý thuyết `00, 01, 10, 11`:
  - `bm_00 = r1 + r0`
  - `bm_01 = r1 + (~r0)`
  - `bm_10 = (~r1) + r0`
  - `bm_11 = (~r1) + (~r0)`
- Chốt kết quả vào 4 thanh ghi 2-bit (`bm_00_reg`, `bm_01_reg`, `bm_10_reg`, `bm_11_reg`) khi `bmu_en = 1`.

### 3.3. Stage 2: ACSU & Hạt Nhân ACS (`vit_acs_node.v`, `vit_acsu.v`)
- Mỗi nút `vit_acs_node` thực hiện:
  1. **Add:** `cand_0 = pm_p0 + {3'b000, bm_0}`, `cand_1 = pm_p1 + {3'b000, bm_1}`
  2. **Compare:** `decision = (cand_1 < cand_0) ? 1'b1 : 1'b0`
  3. **Select:** `pm_next = decision ? cand_1 : cand_0`
- **Bảng kết nối 4 nút ACS song song trên lưới Trellis ($K=3, G_1=111_2, G_2=101_2$):**

| Bộ ACS | Trạng thái đích $S_j$ | Bit tin $u_t$ | Tiền trạng thái $P_0$ ($d_j=0$) | Nhánh $P_0 \to S_j$ | Tiền trạng thái $P_1$ ($d_j=1$) | Nhánh $P_1 \to S_j$ |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `u_acs_s00` | $S_{00}$ (`0`) | `0` | $S_{00}$ (`pm_curr_0`) | `bm_00` (`00`) | $S_{01}$ (`pm_curr_1`) | `bm_11` (`11`) |
| `u_acs_s01` | $S_{01}$ (`1`) | `0` | $S_{10}$ (`pm_curr_2`) | `bm_10` (`10`) | $S_{11}$ (`pm_curr_3`) | `bm_01` (`01`) |
| `u_acs_s10` | $S_{10}$ (`2`) | `1` | $S_{00}$ (`pm_curr_0`) | `bm_11` (`11`) | $S_{01}$ (`pm_curr_1`) | `bm_00` (`00`) |
| `u_acs_s11` | $S_{11}$ (`3`) | `1` | $S_{10}$ (`pm_curr_2`) | `bm_01` (`01`) | $S_{11}$ (`pm_curr_3`) | `bm_10` (`10`) |

### 3.4. Module 4: Path Metric Unit (`vit_pmu.v`)
- Lưu trữ 4 giá trị Path Metric bằng **1 bank duy nhất** gồm $4 \times 5\text{-bit}$ Flip-Flop (`pm_curr_0..3[4:0]`).
- Khi `init_pmu = 1` (đầu khung): `pm_curr_0 <= 5'd0` (trạng thái khởi đầu $S_{00}$), `pm_curr_1..3 <= 5'd16` (giá trị phạt lớn loại trừ các nhánh xuất phát ngoài $S_{00}$).
- Khi `acs_en = 1`: cập nhật đồng bộ `pm_curr_0..3 <= pm_next_0..3`.

### 3.5. Stage 3: Survivor Memory Unit — Register-Exchange $4 \times 8$ (`vit_smu_re.v`)
- Gồm 4 thanh ghi 8-bit `surv_hist_0..3[7:0]` (tổng 32 Flip-Flop).
- Khi `smu_en = 1`, mỗi hàng chọn 7 bit thấp `[6:0]` của tiền trạng thái sống sót ($P_1$ nếu `decisions[j] == 1`, $P_0$ nếu `decisions[j] == 0`) và dịch bit thông tin $u_t$ (`0` cho $S_{00}, S_{01}$; `1` cho $S_{10}, S_{11}$) vào LSB:
  - `surv_hist_0 <= { (decisions[0] ? surv_hist_1[6:0] : surv_hist_0[6:0]), 1'b0 }`
  - `surv_hist_1 <= { (decisions[1] ? surv_hist_3[6:0] : surv_hist_2[6:0]), 1'b0 }`
  - `surv_hist_2 <= { (decisions[2] ? surv_hist_1[6:0] : surv_hist_0[6:0]), 1'b1 }`
  - `surv_hist_3 <= { (decisions[3] ? surv_hist_3[6:0] : surv_hist_2[6:0]), 1'b1 }`

### 3.6. Stage 4: Output PSU — Path Selection Unit (`vit_output_psu.v`)
- **Cây so sánh tìm Min-PM (2 tầng, 3 bộ Comparator 5-bit):**
  - Tầng 1: So sánh cặp $(S_{00}, S_{01}) \to (\text{min\_pm\_01}, \text{idx\_01})$ và cặp $(S_{10}, S_{11}) \to (\text{min\_pm\_23}, \text{idx\_23})$.
  - Tầng 2: So sánh $\text{min\_pm\_23} < \text{min\_pm\_01} \to \text{best\_state}[1:0]$.
- **Bộ chọn kênh MUX 4:1 (8-bit):** Chọn `surv_hist[best_state][7:0]` và chốt vào thanh ghi `dec_out[7:0]` kèm `out_valid = 1` khi `out_en = 1`.

### 3.7. Module 1: Control Unit FSM (`vit_ctrl_fsm.v`)
- **Lịch trình hoạt động (11 chu kỳ / khung):**
  - **Chu kỳ 0 (`S_IDLE` handshake):** Chốt `data_in[15:0]`, khởi tạo `PMU` & `SMU`, đặt `step_cnt = 0`.
  - **Chu kỳ 1..8 (`S_PIPE_RUN`, `step_cnt = 0..7`):** Stage 0 & Stage 1 (BMU) xử lý lần lượt 8 symbol; Stage 2 (ACSU/PMU) & Stage 3 (SMU) hoạt động lệch pha 1 chu kỳ (`acs_en = bmu_valid_d1`) cho các symbol $t = 0\dots 6$.
  - **Chu kỳ 9 (`S_PIPE_DRAIN`):** Stage 2 (ACSU/PMU) & Stage 3 (SMU) hoàn tất xử lý symbol cuối cùng ($t = 7$).
  - **Chu kỳ 10 (`S_SELECT_OUT`):** Stage 4 (Output PSU) chọn đường có $\min(PM)$, chốt `dec_out[7:0]`, bật `out_valid = 1`, `done = 1` và sẵn sàng nhận khung mới.
