
module tb_register_1bit;

    logic clk;
    logic rst_n;
    logic d;
    logic q;

    register_1bit dut (
        .clk   (clk),
        .rst_n (rst_n),
        .d     (d),
        .q     (q)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 1'b0;
        d     = 1'b0;

        #12;
        if (q !== 1'b0)
            $fatal(1, "FAIL: reset did not clear q");

        rst_n = 1'b1;
        d     = 1'b1;

        @(posedge clk);
        #1;
        if (q !== 1'b1)
            $fatal(1, "FAIL: q did not capture 1");

        d = 1'b0;

        @(posedge clk);
        #1;
        if (q !== 1'b0)
            $fatal(1, "FAIL: q did not capture 0");

        $display("PASS: all register tests passed");
        $finish;
    end

endmodule
