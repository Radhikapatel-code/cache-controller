
`timescale 1ns/1ps

module tb_cache_array;

    logic clk;
    logic rst_n;

    logic [15:0] address;
    logic hit;
    logic [31:0] read_data;

    logic install;
    logic install_way;
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
        .read_data(read_data),
        .install(install),
        .install_way(install_way),
        .install_address(install_address),
        .install_data(install_data),
        .write_hit(write_hit),
        .write_address(write_address),
        .write_data(write_data),
        .byte_enable(byte_enable)
    );

    // 10 ns clock period
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
                $error("%s: expected hit=%b, got hit=%b",
                       test_name, expected_hit, hit);
                $fatal(1);
            end

            if (expected_hit && read_data !== expected_data) begin
                $error("%s: expected data=%h, got data=%h",
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
        install_data = 32'h00000000;

        write_hit = 1'b0;
        write_address = 16'h0000;
        write_data = 32'h00000000;
        byte_enable = 4'b0000;

        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        #1;

        // Test 1: empty cache must miss
        check_read(16'h1234, 1'b0, 32'h00000000,
                   "empty cache produces a miss");

        // Test 2: install a word and read it back
        install_word(16'h1234, 1'b0, 32'hAABBCCDD);
        check_read(16'h1234, 1'b1, 32'hAABBCCDD,
                   "installed word produces a hit");

        // Test 3: same set, different tag must miss
        check_read(16'h2234, 1'b0, 32'h00000000,
                   "different tag produces a miss");

        // Test 4: install another tag in the second way
        install_word(16'h2234, 1'b1, 32'h11223344);
        check_read(16'h2234, 1'b1, 32'h11223344,
                   "second way stores its own word");

        // Test 5: first way must retain its data
        check_read(16'h1234, 1'b1, 32'hAABBCCDD,
                   "first way remains intact");

        // Test 6: an uninstalled set must miss
        check_read(16'h1238, 1'b0, 32'h00000000,
                   "different set produces a miss");

        // Test 7: update only the lowest byte
        write_word(16'h1234, 32'h000000EE, 4'b0001);
        check_read(16'h1234, 1'b1, 32'hAABBCCEE,
                   "byte enable 0001 updates lowest byte");

        // Test 8: update the upper two bytes
        write_word(16'h1234, 32'h55660000, 4'b1100);
        check_read(16'h1234, 1'b1, 32'h5566CCEE,
                   "byte enables 1100 update upper bytes");

        // Test 9: update every byte
        write_word(16'h2234, 32'hDEADBEEF, 4'b1111);
        check_read(16'h2234, 1'b1, 32'hDEADBEEF,
                   "byte enables 1111 update full word");

        // Test 10: writes must not corrupt the other way
        check_read(16'h1234, 1'b1, 32'h5566CCEE,
                   "write to second way preserves first way");

        // Test 11: zero byte enables must preserve all bytes
        write_word(16'h1234, 32'hFFFFFFFF, 4'b0000);
        check_read(16'h1234, 1'b1, 32'h5566CCEE,
                   "zero byte enables preserve the word");

        $display("");
        $display("PASS: all cache array tests passed");
        $finish;
    end

endmodule
