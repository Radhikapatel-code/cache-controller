
module tb_cache_array;

    logic clk, rst_n;
    logic [15:0] address;
    logic hit, hit_way;
    logic [31:0] read_data;
    logic valid_way0, valid_way1;

    logic install, install_way;
    logic [15:0] install_address;
    logic [31:0] install_data;

    logic write_hit;
    logic [15:0] write_address;
    logic [31:0] write_data;
    logic [3:0] byte_enable;

    cache_array dut (
        .clk(clk),
        .rst_n(rst_n),
        .address(address),
        .hit(hit),
        .hit_way(hit_way),
        .read_data(read_data),
        .valid_way0(valid_way0),
        .valid_way1(valid_way1),
        .install(install),
        .install_way(install_way),
        .install_address(install_address),
        .install_data(install_data),
        .write_hit(write_hit),
        .write_address(write_address),
        .write_data(write_data),
        .byte_enable(byte_enable)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic check_read(
        input logic [15:0] test_address,
        input logic expected_hit,
        input logic [31:0] expected_data,
        input string test_name
    );
        begin
            address = test_address;
            #1;

            if (hit !== expected_hit) begin
                $error("%s: expected hit=%b, got=%b",
                       test_name, expected_hit, hit);
                $fatal(1);
            end

            if (expected_hit && read_data !== expected_data) begin
                $error("%s: expected data=%h, got=%h",
                       test_name, expected_data, read_data);
                $fatal(1);
            end

            $display("PASS: %s", test_name);
        end
    endtask

    task automatic install_word(
        input logic [15:0] addr,
        input logic way,
        input logic [31:0] data
    );
        begin
            @(negedge clk);
            install = 1'b1;
            install_address = addr;
            install_way = way;
            install_data = data;

            @(negedge clk);
            install = 1'b0;
        end
    endtask

    task automatic write_word(
        input logic [15:0] addr,
        input logic [31:0] data,
        input logic [3:0] enables
    );
        begin
            @(negedge clk);
            write_hit = 1'b1;
            write_address = addr;
            write_data = data;
            byte_enable = enables;

            @(negedge clk);
            write_hit = 1'b0;
            byte_enable = 4'b0000;
        end
    endtask

    initial begin
        rst_n = 1'b0;
        address = 16'h0000;

        install = 1'b0;
        install_way = 1'b0;
        install_address = 16'h0000;
        install_data = 32'h0;

        write_hit = 1'b0;
        write_address = 16'h0000;
        write_data = 32'h0;
        byte_enable = 4'b0000;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        #1;

        check_read(16'h1234, 1'b0, 32'h0,
                   "empty cache misses");

        if (valid_way0 !== 1'b0 || valid_way1 !== 1'b0)
            $fatal(1, "Reset did not clear valid bits");
        $display("PASS: reset clears both valid bits");

        install_word(16'h1234, 1'b0, 32'hAABBCCDD);
        check_read(16'h1234, 1'b1, 32'hAABBCCDD,
                   "way 0 installation");
        if (hit_way !== 1'b0 || valid_way0 !== 1'b1)
            $fatal(1, "Way 0 hit/valid reporting failed");
        $display("PASS: way 0 hit and valid outputs");

        check_read(16'h2234, 1'b0, 32'h0,
                   "different tag misses");

        install_word(16'h2234, 1'b1, 32'h11223344);
        check_read(16'h2234, 1'b1, 32'h11223344,
                   "way 1 installation");
        if (hit_way !== 1'b1 || valid_way1 !== 1'b1)
            $fatal(1, "Way 1 hit/valid reporting failed");
        $display("PASS: way 1 hit and valid outputs");

        check_read(16'h1234, 1'b1, 32'hAABBCCDD,
                   "way 0 data remains intact");

        check_read(16'h1238, 1'b0, 32'h0,
                   "different set misses");

        write_word(16'h1234, 32'h000000EE, 4'b0001);
        check_read(16'h1234, 1'b1, 32'hAABBCCEE,
                   "lowest byte write");

        write_word(16'h1234, 32'h55660000, 4'b1100);
        check_read(16'h1234, 1'b1, 32'h5566CCEE,
                   "upper two byte write");

        write_word(16'h2234, 32'hDEADBEEF, 4'b1111);
        check_read(16'h2234, 1'b1, 32'hDEADBEEF,
                   "full word write");

        write_word(16'h1234, 32'hFFFFFFFF, 4'b0000);
        check_read(16'h1234, 1'b1, 32'h5566CCEE,
                   "zero byte enables preserve data");

        $display("");
        $display("PASS: all cache array tests passed");
        $finish;
    end

endmodule
