# TASK 7 — Report & Final Cleanup
**Agent:** Create the final documentation and update the project description.
**Prereq:** All previous tasks must be complete.
**Workspace:** `c:\Users\brata\Downloads\FPGA_NeuralNetwork\`

---

## Step 1: Create the Report Document
1. Create a 2-3 page document in **Markdown** and name it `c:\Users\brata\Downloads\FPGA_NeuralNetwork\docs\report.md`.
2. Include the following sections:
   - **Introduction:** Short summary of the project goals.
   - **Block Diagram:** Describe the architecture (Neuron -> Layer -> Top-Level). 
   - **Results:** Fill in the table with 5 test inputs (calculated by hand/Python vs FPGA results).
   - **Vivado Metrics:** LUT Utilisation and Worst Negative Slack (from Task 6).
   - **Conclusion:** Reflection on the project and what was learned.

---

## Step 2: Final README Update
1. Update `c:\Users\brata\Downloads\FPGA_NeuralNetwork\README.md`.
2. Fill in the placeholder values for:
   - **LUT Utilisation**
   - **Timing Slack (WNS)**
   - **Verification Table**
3. Ensure all file paths in the README correctly reflect the final project structure.

---

## Step 3: Final Submission Check
1. Ensure the directory structure exactly matches the submission requirements:
   ```
   ends_term/project/bratadeepsarkar_240285/
       src/          <- Verilog design files
       sim/          <- Testbench files
       weights/      <- .mem files
       python/       <- Python training script
       vivado/       <- Vivado constraints and project files
       docs/         <- Final report (PDF)
       README.md     <- Project overview
   ```
2. Commit and Push to GitHub.

---

## DONE ✓
**Project Completed Successfully!**
```
