
module tb_replacement_policy;

    logic clk;
    logic rst_n;
    logic [1:0] set_index;
    logic access_valid;
    logic accessed_way;
    logic valid_way0;
    logic valid_way1;
    logic victim_way;

    replacement_policy dut (
        .clk(clk),
        .rst_n(rst_n),
        .set_index(set_index),
        .access_valid(access_valid),
        .accessed_way(accessed_way),
        .valid_way0(valid_way0),
        .valid_way1(valid_way1),
        .victim_way(victim_way)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 1'b0;
        set_index = 2'd0;
        access_valid = 1'b0;
        accessed_way = 1'b0;
        valid_way0 = 1'b0;
        valid_way1 = 1'b0;

        #2;
        rst_n = 1'b1;

        // Test 1: Both ways invalid -> choose way 0.
        #1;
        if (victim_way !== 1'b0)
            $fatal(1, "FAIL: expected invalid way 0");

        // Test 2: Only way 0 valid -> choose way 1.
        valid_way0 = 1'b1;
        valid_way1 = 1'b0;
        #1;
        if (victim_way !== 1'b1)
            $fatal(1, "FAIL: expected invalid way 1");

        // Test 3: Both valid, reset LRU means evict way 0.
        valid_way1 = 1'b1;
        #1;
        if (victim_way !== 1'b0)
            $fatal(1, "FAIL: expected initial LRU way 0");

        // Test 4: Access way 0 -> evict way 1 next.
        @(negedge clk);
        access_valid = 1'b1;
        accessed_way = 1'b0;
        @(negedge clk);
        access_valid = 1'b0;
        #1;
        if (victim_way !== 1'b1)
            $fatal(1, "FAIL: expected LRU way 1 after way 0 access");

        // Test 5: Access way 1 -> evict way 0 next.
        @(negedge clk);
        access_valid = 1'b1;
        accessed_way = 1'b1;
        @(negedge clk);
        access_valid = 1'b0;
        #1;
        if (victim_way !== 1'b0)
            $fatal(1, "FAIL: expected LRU way 0 after way 1 access");

        // Test 6: LRU state is independent per set.
        set_index = 2'd1;
        #1;
        if (victim_way !== 1'b0)
            $fatal(1, "FAIL: set 1 LRU state changed unexpectedly");

        $display("PASS: all replacement policy tests passed");
        $finish;
    end

endmodule
