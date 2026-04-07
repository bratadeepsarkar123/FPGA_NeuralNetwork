# TASK 6 — Vivado: Synthesis & Bitstream Generation
**Agent:** Follow these steps manually in the Vivado GUI. Do not automated.
**Prereq:** All `.v` files in `src/` and `.xdc` file in `vivado/` must exist.
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`

---

## Step 1: Create a New Project
1. Open **Vivado 20xx.x**.
2. Click **Create Project**.
3. Name it `fpga_nn` and set the location to `c:\Users\brata\Downloads\FPGA_NeuralNetwork\vivado\`.
4. Choose **RTL Project**.
5. Add Sources: Select all `.v` files from `c:\Users\brata\Downloads\FPGA_NeuralNetwork\src\`.
6. Add Constraints: Select `c:\Users\brata\Downloads\FPGA_NeuralNetwork\vivado\nn_top.xdc`.
7. Select Part: **Basys 3** (or part number `xc7a35tcpg236-1`).

---

## Step 2: Run Synthesis
1. Click **Run Synthesis** in the Flow Navigator.
2. Select defaults and click OK.
3. Wait for it to complete. 
4. Check the **Messages** tab for Errors (Red). Yellow warnings are expected.

---

## Step 3: Run Implementation
1. Click **Run Implementation**.
2. Wait for completion.
3. Click **Open Implemented Design**.

---

## Step 4: Generate Bitstream
1. Click **Generate Bitstream**.
2. Once done, the file `fpga_nn.runs/impl_1/nn_top.bit` will be created.

---

## Step 5: Extract Metrics (For Task 7)
1. **LUT Utilisation:** Go to `Report Utilization` in the Implemented Design. Look for `Slice LUTs` percentage.
2. **Timing Slack:** Go to `Report Timing Summary`. Look for `Worst Negative Slack (WNS)`. It should be positive.

---

## Done ✓ → Proceed to TASK7_REPORT.md
