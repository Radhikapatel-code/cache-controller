`timescale 1ns/1ps

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

    // Memory model state
    logic mem_active;
    logic mem_completed;
    integer wait_count;

    logic saved_mem_write;
    logic [15:0] saved_mem_address;
    logic [31:0] saved_mem_write_data;
    logic [3:0] saved_mem_byte_enable;

    integer i;
    integer b;

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

    // Initialize testbench memory and handshake signals.
    initial begin
        rst_n = 1'b0;

        cpu_req = 1'b0;
        cpu_write = 1'b0;
        cpu_address = 16'b0;
        cpu_write_data = 32'b0;
        cpu_byte_enable = 4'b0;

        mem_ready = 1'b0;
        mem_read_data = 32'b0;

        read_count = 0;
        write_count = 0;

        mem_active = 1'b0;
        mem_completed = 1'b0;
        wait_count = 0;

        saved_mem_write = 1'b0;
        saved_mem_address = 16'b0;
        saved_mem_write_data = 32'b0;
        saved_mem_byte_enable = 4'b0;

        for (i = 0; i < 16384; i++)
            memory[i] = 32'b0;

        memory[14'h004] = 32'h12345678;
        memory[14'h008] = 32'hAABBCCDD;
        memory[14'h00C] = 32'h0BADF00D;
    end

    // Deterministic memory model:
    // - Captures each request once.
    // - Waits several cycles before acknowledging it.
    // - Checks that request fields stay stable while waiting.
    // - Performs each memory operation exactly once.
    // - Holds mem_ready until the controller drops mem_req.
    always @(posedge clk) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            mem_read_data <= 32'b0;

            mem_active = 1'b0;
            mem_completed = 1'b0;
            wait_count = 0;
        end else begin
            if (!mem_req) begin
                mem_ready <= 1'b0;
                mem_active = 1'b0;
                mem_completed = 1'b0;
                wait_count = 0;
            end else if (!mem_active) begin
                // Capture a new memory request.
                mem_active = 1'b1;
                mem_completed = 1'b0;
                wait_count = 3;

                saved_mem_write = mem_write;
                saved_mem_address = mem_address;
                saved_mem_write_data = mem_write_data;
                saved_mem_byte_enable = mem_byte_enable;

                mem_ready <= 1'b0;
            end else begin
                // The request must not change during a stall.
                if (mem_write !== saved_mem_write ||
                    mem_address !== saved_mem_address ||
                    (saved_mem_write &&
                     (mem_write_data !== saved_mem_write_data ||
                      mem_byte_enable !== saved_mem_byte_enable))) begin
                    $error("Memory request changed while waiting");
                    $fatal(1);
                end

                if (!mem_completed) begin
                    if (wait_count > 1) begin
                        wait_count = wait_count - 1;
                        mem_ready <= 1'b0;
                    end else begin
                        // Complete this request exactly once.
                        if (saved_mem_write) begin
                            for (b = 0; b < 4; b++) begin
                                if (saved_mem_byte_enable[b]) begin
                                    memory[saved_mem_address[15:2]]
                                          [8*b +: 8]
                                        = saved_mem_write_data[8*b +: 8];
                                end
                            end

                            write_count = write_count + 1;
                        end else begin
                            mem_read_data <=
                                memory[saved_mem_address[15:2]];

                            read_count = read_count + 1;
                        end

                        mem_completed = 1'b1;
                        mem_ready <= 1'b1;
                    end
                end else begin
                    // Keep the acknowledgement asserted until mem_req drops.
                    mem_ready <= 1'b1;
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

            // Allow the controller to capture the request.
            @(negedge clk);
            cpu_req = 1'b0;

            timeout = 0;

            while (cpu_ready !== 1'b1 && timeout < 200) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if (cpu_ready !== 1'b1) begin
                $error("%s: CPU request timed out", test_name);
                $fatal(1);
            end

            if (!is_write && cpu_read_data !== expected_rdata) begin
                $error("%s: expected %h, received %h",
                       test_name, expected_rdata, cpu_read_data);
                $fatal(1);
            end

            $display("PASS: %s", test_name);

            // Let the controller leave its response state.
            @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // 1. Read miss: fetch from backing memory.
        cpu_transaction(
            1'b0, 16'h0010, 32'b0, 4'b1111,
            32'h12345678, "read miss with memory wait"
        );

        // 2. Read hit: no backing-memory read should occur.
        begin
            integer reads_before;
            reads_before = read_count;

            cpu_transaction(
                1'b0, 16'h0010, 32'b0, 4'b1111,
                32'h12345678, "read hit"
            );

            if (read_count != reads_before)
                $fatal(1, "Read hit unexpectedly accessed memory");
        end

        // 3. A second address causes another miss.
        cpu_transaction(
            1'b0, 16'h0020, 32'b0, 4'b1111,
            32'hAABBCCDD, "second read miss"
        );

        // 4. Write hit: change only the lowest byte.
        begin
            integer writes_before;
            writes_before = write_count;

            cpu_transaction(
                1'b1, 16'h0020, 32'h000000EE, 4'b0001,
                32'b0, "write hit"
            );

            if (write_count != writes_before + 1)
                $fatal(1, "Write hit did not produce exactly one memory write");
        end

        if (memory[14'h008] !== 32'hAABBCCEE)
            $fatal(1, "Write-through failed for write hit");

        // 5. Confirm the updated value is present in the cache.
        cpu_transaction(
            1'b0, 16'h0020, 32'b0, 4'b1111,
            32'hAABBCCEE, "read after write hit"
        );

        // 6. Write miss: fetch, merge the enabled byte, then write through.
        begin
            integer reads_before;
            integer writes_before;

            reads_before = read_count;
            writes_before = write_count;

            cpu_transaction(
                1'b1, 16'h0030, 32'h00000099, 4'b0001,
                32'b0, "write miss"
            );

            if (read_count != reads_before + 1)
                $fatal(1, "Write miss should fetch one memory word");

            if (write_count != writes_before + 1)
                $fatal(1, "Write miss should produce exactly one memory write");
        end

        if (memory[14'h00C] !== 32'h0BADF099)
            $fatal(1, "Write-through failed for write miss");

        // 7. Confirm the write-miss data is cached correctly.
        cpu_transaction(
            1'b0, 16'h0030, 32'b0, 4'b1111,
            32'h0BADF099, "read after write miss"
        );

        $display("");
        $display("Memory reads:  %0d", read_count);
        $display("Memory writes: %0d", write_count);
        $display("PASS: integrated cache controller tests passed");

        $finish;
    end

    // Global watchdog catches deadlocks in the testbench or controller.
    initial begin
        #10000;
        $fatal(1, "Global simulation timeout");
    end

endmodule
