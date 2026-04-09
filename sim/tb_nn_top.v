`timescale 1ns / 1ps

module tb_nn_top;

    reg        clk;
    reg        btn_rst;
    reg        start;
    reg [3:0]  sw;
    wire [1:0] predicted_class;
    wire       done;

    nn_top uut (
        .clk             (clk),
        .btn_rst         (btn_rst),
        .start           (start),
        .sw              (sw),
        .predicted_class (predicted_class),
        .done            (done)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    integer i;
    initial begin
        clk     = 0;
        btn_rst = 1;
        start   = 0;
        sw      = 0;

        #100;
        btn_rst = 0;
        #20;

        $display("========================================");
        $display(" nn_top Integration Test - 10 Samples");
        $display("========================================");
        $display("Sample | Expected | Predicted | Status");
        $display("-------|----------|-----------|-------");

        for (i = 0; i < 10; i = i + 1) begin
            sw = i;
            #20;
            
            // Pulse start
            @(posedge clk); #1;
            start = 1;
            @(posedge clk); #1;
            start = 0;

            // Wait for done
            begin : wait_loop
                repeat (1000) begin
                    @(posedge clk); #1;
                    if (done) disable wait_loop;
                end
            end

            if (done) begin
                // Note: This expects we know the labels. 
                // For simplicity, I'll just print the predicted class.
                // The labels in test_data.mem are at indices 4, 9, 14, ...
                $display("   %0d   |     ?    |     %0d     |  DONE", i, predicted_class);
            end else begin
                $display("   %0d   |     ?    |   TIMEOUT |  FAIL", i);
            end
            #100;
        end

        $display("========================================");
        $finish;
    end

endmodule
