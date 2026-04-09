`timescale 1ns / 1ps

module tb_nn_top;

    reg        clk;
    reg        btn_rst;
    reg        start;
    reg  [3:0] sw;
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

    // Expected labels for all 10 samples
    reg [1:0] expected [0:9];
    integer i;
    integer pass, fail;

    initial begin
        expected[0] = 2'd0;
        expected[1] = 2'd2;
        expected[2] = 2'd1;
        expected[3] = 2'd1;
        expected[4] = 2'd0;
        expected[5] = 2'd1;
        expected[6] = 2'd0;
        expected[7] = 2'd0;
        expected[8] = 2'd2;
        expected[9] = 2'd1;

        clk     = 0;
        btn_rst = 1;
        start   = 0;
        sw      = 4'd0;
        pass    = 0;
        fail    = 0;

        #100;
        btn_rst = 0;
        #20;

        $display("========================================");
        $display(" nn_top Integration Test — All 10 Samples");
        $display("========================================");
        $display("");

        for (i = 0; i < 10; i = i + 1) begin
            // Set sample select switch
            sw = i[3:0];

            // Pulse start
            @(posedge clk); #1;
            start = 1;
            @(posedge clk); #1;
            start = 0;

            // Wait for done (timeout after 500 cycles)
            begin : wait_loop
                repeat (500) begin
                    @(posedge clk); #1;
                    if (done) disable wait_loop;
                end
            end

            if (done) begin
                if (predicted_class == expected[i]) begin
                    $display("  Sample %0d: predicted=%0d  expected=%0d  PASS", i, predicted_class, expected[i]);
                    pass = pass + 1;
                end else begin
                    $display("  Sample %0d: predicted=%0d  expected=%0d  FAIL", i, predicted_class, expected[i]);
                    fail = fail + 1;
                end
            end else begin
                $display("  Sample %0d: TIMEOUT", i);
                fail = fail + 1;
            end

            // Reset between samples
            btn_rst = 1;
            #20;
            btn_rst = 0;
            #20;
        end

        $display("");
        $display("========================================");
        $display(" Results: %0d/10 PASS,  %0d/10 FAIL", pass, fail);
        $display("========================================");
        #100;
        $finish;
    end

endmodule
