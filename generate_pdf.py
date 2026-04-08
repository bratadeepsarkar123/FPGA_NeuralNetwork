from fpdf import FPDF
from fpdf.enums import XPos, YPos

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

3. Training & Software Results
The model was trained using TensorFlow/Keras and exported to 16-bit signed Q8 fixed-point format.
- Test Accuracy: 93.3%
- Max Absolute Weight: 1.1219 (Well within Q8 range - no overflow).

4. Verification Results
Both simulation and hardware synthesis confirmed the logic.

Sample ID | Expected Class | Predicted Class | Status
----------|----------------|-----------------|-------
0         | 0 (Setosa)     | 0               | PASS
1         | 2 (Virginica)  | 2               | PASS
2         | 1 (Versicolour)| 1               | PASS
3         | 1 (Versicolour)| 1               | PASS
4         | 0 (Setosa)     | 0               | PASS

Note: Simulation was verified against 10 test samples from test_data.mem.

5. FPGA Performance Metrics (Vivado)
Metric                   | Value
-------------------------|--------------------------
Logic Utilization (LUTs) | 14 (<1%)
Registers                | 15 (<1%)
Worst Negative Slack (WNS)| 6.866 ns
Operating Frequency      | 100 MHz (Target)

6. Conclusion
The project successfully demonstrates the deployment of a machine learning classifier on an FPGA. The resource footprint is extremely small, making it suitable for larger-scale integration or edge-device applications.

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
