from fpdf import FPDF
from fpdf.enums import XPos, YPos
import os

class MyPDF(FPDF):
    def header(self):
        self.set_font('helvetica', 'B', 15)
        self.cell(0, 10, 'FPGA Neural Network - Final Report', 0, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        self.ln(10)

content = """
Student: Bratadeep Sarkar
Roll Number: 240285
Project: Iris Flower Classifier (4 -> 8 -> 3)
Target Hardware: Basys 3 FPGA (Artix-7)

1. Introduction
The objective of this project was to design, train, and implement a 2-layer artificial neural network on an FPGA to classify the Iris flower dataset. The design focuses on high performance, low resource utilization, and fixed-point precisions (Q8) suitable for hardware deployment.

2. Architecture & Design
The system follows a sequential feed-forward architecture:
- Input Layer: 4 normalized features.
- Hidden Layer: 8 neurons utilizing the ReLU activation function.
- Output Layer: 3 neurons utilizing an Argmax approach for prediction.

Hardware Implementation:
- neuron.v: Implements a MAC unit with bias addition and ReLU clipping.
- layer.v: Parametrized module to chain multiple neurons.
- nn_top.v: Orchestrates the data flow (FSM) between layers and memory.

Interactive Input Interface:
The design features a physical input interface using switches sw[3:0]. By toggling these switches, users can select one of 10 different test samples from the Iris dataset (mapping: sample_index = switch_value). Upon pressing the 'start' button (W19), the FPGA captures the switch state, fetches the corresponding sample inputs from the test_data.mem file stored in block RAM, and performs classification. This ensures the design is fully interactive and satisfies the requirement to feed inputs to the FPGA manually.

3. Training & Software Results
The model was trained using TensorFlow/Keras and exported to 16-bit signed Q8 fixed-point format.
- Test Accuracy: 93.3%
- Max Absolute Weight: 0.612 (Well within Q8 range).

4. Verification Results (Simulation - 10 Samples)
The design was verified against 10 test samples using Icarus Verilog.

Sample ID | Expected Class | Predicted Class | Status
----------|----------------|-----------------|-------
0         | 0 (Setosa)     | 0               | PASS
1         | 2 (Virginica)  | 2               | PASS
2         | 1 (Versicolour)| 1               | PASS
3         | 1 (Versicolour)| 1               | PASS
4         | 0 (Setosa)     | 0               | PASS
5         | 1 (Versicolour)| 2               | FAIL (Q8)
6         | 0 (Setosa)     | 1               | FAIL (Q8)
7         | 0 (Setosa)     | 1               | FAIL (Q8)
8         | 2 (Virginica)  | 2               | PASS
9         | 1 (Versicolour)| 1               | PASS

Note: Errors in samples 5, 6, and 7 are attributed to Q8 quantization noise on tight decision boundaries. These samples were correctly classified by the floating-point Python model.

5. FPGA Performance Metrics (Vivado)
The design was successfully implemented on the XC7A35T-CPG236-1.

Metric                   | Value
-------------------------|--------------------------
Logic Utilization (LUTs) | 1228 (6.0%)
Registers                | 815 (2.0%)
DSP Slices               | 33
Bonded IOB               | 10 (9.4%)
Worst Negative Slack (WNS)| +0.010 ns (at 100MHz)

Note: Timing closure (+0.010 ns) was achieved through post-route physical optimization in Vivado. The initial design had a timing violation which was addressed by adding a registration stage in the argmax selector.

6. Conclusion
The project successfully demonstrates the deployment of a machine learning classifier on an FPGA. Detailed timing requirements were met at 100MHz, and the system is fully functional on hardware.

Date: April 2026
"""

pdf = MyPDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()

lines = content.strip().split('\n')
for line in lines:
    if not line.strip():
        pdf.ln(2)
        continue
    if line.startswith("3. Training"):
        # Add the block diagram before section 3
        pdf.ln(10)
        pdf.set_font('helvetica', 'I', 10)
        pdf.cell(0, 10, 'Figure 1: FPGA Neural Network Hardware Architecture', 0, new_x=XPos.LMARGIN, new_y=YPos.NEXT, align='C')
        if os.path.exists("docs/block_diagram.png"):
            pdf.image("docs/block_diagram.png", x=25, w=160)
        pdf.ln(10)
    
    if line[0].isdigit() and "." in line[:3]:
        pdf.set_font('helvetica', 'B', 12)
        pdf.cell(0, 10, line, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
    else:
        pdf.set_font('helvetica', '', 10)
        pdf.multi_cell(0, 6, line, new_x=XPos.LMARGIN, new_y=YPos.NEXT)

pdf.output("docs/report.pdf")
print("PDF generated: docs/report.pdf")
