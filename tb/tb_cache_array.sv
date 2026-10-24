
module tb_cache_array;

    logic        clk;
    logic        rst_n;
    logic [15:0] address;
    logic        hit;
    logic [31:0] read_data;

    logic        install;
    logic        install_way;
    logic [15:0] install_address;
    logic [31:0] install_data;

    cache_array dut (
        .clk(clk),
        .rst_n(rst_n),
        .address(address),
        .hit(hit),
        .read_data(read_data),
        .install(install),
        .install_way(install_way),
        .install_address(install_address),
        .install_data(install_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        rst_n          = 1'b0;
        address        = 16'h1234;
        install        = 1'b0;
        install_way    = 1'b0;
        install_address = 16'h0000;
        install_data   = 32'h00000000;

        // Test 1: Reset invalidates all lines.
        #2;
        if (hit !== 1'b0)
            $fatal(1, "FAIL: empty cache should miss");

        // Release reset away from a rising clock edge.
        @(negedge clk);
        rst_n = 1'b1;

        // Test 2: Install address 0x1234 in set 1, way 0.
        install_address = 16'h1234;
        install_data    = 32'hDEADBEEF;
        install_way     = 1'b0;
        install         = 1'b1;

        @(negedge clk);
        install = 1'b0;

        address = 16'h1234;
        #1;
        if (hit !== 1'b1 || read_data !== 32'hDEADBEEF)
            $fatal(1, "FAIL: installed line should hit with correct data");

        // Test 3: Different tag, same set must miss.
        address = 16'h2234;
        #1;
        if (hit !== 1'b0)
            $fatal(1, "FAIL: different tag in same set should miss");

        // Test 4: Install another tag in way 1 of set 1.
        install_address = 16'h2234;
        install_data    = 32'hCAFEBABE;
        install_way     = 1'b1;
        install         = 1'b1;

        @(negedge clk);
        install = 1'b0;

        address = 16'h2234;
        #1;
        if (hit !== 1'b1 || read_data !== 32'hCAFEBABE)
            $fatal(1, "FAIL: way 1 lookup failed");

        // Test 5: Original way 0 entry must still be present.
        address = 16'h1234;
        #1;
        if (hit !== 1'b1 || read_data !== 32'hDEADBEEF)
            $fatal(1, "FAIL: installing way 1 damaged way 0");

        // Test 6: Different set must remain empty.
        address = 16'h1238;
        #1;
        if (hit !== 1'b0)
            $fatal(1, "FAIL: unrelated set should miss");

        $display("PASS: all cache array tests passed");
        $finish;
    end

endmodule
