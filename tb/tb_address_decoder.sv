
module tb_address_decoder;

    logic [15:0] address;
    logic [11:0] tag;
    logic [1:0]  index;
    logic [1:0]  offset;

    address_decoder dut (
        .address(address),
        .tag(tag),
        .index(index),
        .offset(offset)
    );

    initial begin
        // Test 1: A normal address
        address = 16'h1234;
        #1;
        if (tag !== 12'h123 ||
            index !== 2'b01 ||
            offset !== 2'b00)
            $fatal(1, "FAIL: address 0x1234");

        // Test 2: Same word, last byte
        address = 16'h1237;
        #1;
        if (tag !== 12'h123 ||
            index !== 2'b01 ||
            offset !== 2'b11)
            $fatal(1, "FAIL: address 0x1237");

        // Test 3: First set boundary
        address = 16'h000C;
        #1;
        if (tag !== 12'h000 ||
            index !== 2'b11 ||
            offset !== 2'b00)
            $fatal(1, "FAIL: address 0x000C");

        // Test 4: Maximum address
        address = 16'hFFFF;
        #1;
        if (tag !== 12'hFFF ||
            index !== 2'b11 ||
            offset !== 2'b11)
            $fatal(1, "FAIL: address 0xFFFF");

        $display("PASS: all address decoder tests passed");
        $finish;
    end

endmodule
