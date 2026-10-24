
module tb_cache_controller;

    logic clk, rst_n;

    logic cpu_req, cpu_write;
    logic [15:0] cpu_address;
    logic [31:0] cpu_write_data;
    logic [3:0] cpu_byte_enable;
    logic cpu_ready;
    logic [31:0] cpu_read_data;

    logic mem_req, mem_write;
    logic [15:0] mem_address;
    logic [31:0] mem_write_data;
    logic [3:0] mem_byte_enable;
    logic mem_ready;
    logic [31:0] mem_read_data;

    logic [31:0] memory [0:16383];

    integer read_count;
    integer write_count;
    integer i;

    cache_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_req(cpu_req),
        .cpu_write(cpu_write),
        .cpu_address(cpu_address),
        .cpu_write_data(cpu_write_data),
        .cpu_byte_enable(cpu_byte_enable),
        .cpu_ready(cpu_ready),
        .cpu_read_data(cpu_read_data),
        .mem_req(mem_req),
        .mem_write(mem_write),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_byte_enable(mem_byte_enable),
        .mem_ready(mem_ready),
        .mem_read_data(mem_read_data)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Simple memory: acknowledge requests after a short delay.
    // Address is byte-addressed; each word occupies four bytes.
    initial begin
        mem_ready = 1'b0;
        mem_read_data = 32'b0;
        read_count = 0;
        write_count = 0;

        for (i = 0; i < 16384; i++)
            memory[i] = 32'b0;
    end

    always @(negedge clk) begin
        mem_ready = 1'b0;

        if (rst_n && mem_req) begin
            // Introduce a wait cycle to test request stability.
            @(negedge clk);

            if (mem_req) begin
                mem_ready = 1'b1;

                if (mem_write) begin
                    for (int b = 0; b < 4; b++) begin
                        if (mem_byte_enable[b])
                            memory[mem_address[15:2]][8*b +: 8]
                                = mem_write_data[8*b +: 8];
                    end
                    write_count = write_count + 1;
                end else begin
                    mem_read_data = memory[mem_address[15:2]];
                    read_count = read_count + 1;
                end
            end
        end
    end

    task automatic cpu_transaction(
        input logic is_write,
        input logic [15:0] addr,
        input logic [31:0] wdata,
        input logic [3:0] be,
        input logic [31:0] expected_rdata,
        input string test_name
    );
        integer timeout;
        begin
            @(negedge clk);
            cpu_req = 1'b1;
            cpu_write = is_write;
            cpu_address = addr;
            cpu_write_data = wdata;
            cpu_byte_enable = be;

            @(negedge clk);
            cpu_req = 1'b0;

            timeout = 0;
            while (!cpu_ready && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= 100) begin
                $error("%s: CPU request timed out", test_name);
                $fatal(1);
            end

            if (!is_write && cpu_read_data !== expected_rdata) begin
                $error("%s: expected %h, received %h",
                       test_name, expected_rdata, cpu_read_data);
                $fatal(1);
            end

            $display("PASS: %s", test_name);
            @(negedge clk);
        end
    endtask

    initial begin
        rst_n = 1'b0;
        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_address = 16'b0;
        cpu_write_data = 32'b0;
        cpu_byte_enable = 4'b0;

        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Initialize backing memory words.
        memory[14'h004] = 32'h12345678;
        memory[14'h008] = 32'hAABBCCDD;
        memory[14'h00C] = 32'h0BADF00D;

        // Read miss should fetch from backing memory.
        cpu_transaction(1'b0, 16'h0010, 32'b0, 4'b1111,
                        32'h12345678, "read miss");

        // Repeated read should hit without another memory read.
        begin
            integer reads_before;
            reads_before = read_count;
            cpu_transaction(1'b0, 16'h0010, 32'b0, 4'b1111,
                            32'h12345678, "read hit");
            if (read_count != reads_before)
                $fatal(1, "Read hit unexpectedly accessed memory");
        end

        // Read another address.
        cpu_transaction(1'b0, 16'h0020, 32'b0, 4'b1111,
                        32'hAABBCCDD, "second read miss");

        // Write hit: update only the lowest byte.
        cpu_transaction(1'b1, 16'h0020, 32'h000000EE, 4'b0001,
                        32'b0, "write hit");

        if (memory[14'h008] !== 32'hAABBCCEE)
            $fatal(1, "Write-through failed for write hit");

        cpu_transaction(1'b0, 16'h0020, 32'b0, 4'b1111,
                        32'hAABBCCEE, "read after write hit");

        // Write miss: fetch, merge enabled bytes, and write through.
        cpu_transaction(1'b1, 16'h0030, 32'h00000099, 4'b0001,
                        32'b0, "write miss");

        if (memory[14'h00C] !== 32'h0BADF099)
            $fatal(1, "Write-through failed for write miss");

        cpu_transaction(1'b0, 16'h0030, 32'b0, 4'b1111,
                        32'h0BADF099, "read after write miss");

        $display("");
        $display("Memory reads:  %0d", read_count);
        $display("Memory writes: %0d", write_count);
        $display("PASS: integrated cache controller tests passed");
        $finish;
    end

endmodule
