
module cache_array (
    input  logic        clk,
    input  logic        rst_n,

    // Lookup interface
    input  logic [15:0] address,
    output logic        hit,
    output logic [31:0] read_data,

    // Install a word after a cache miss
    input  logic        install,
    input  logic        install_way,
    input  logic [15:0] install_address,
    input  logic [31:0] install_data,

    // Update selected bytes on a write hit
    input  logic        write_hit,
    input  logic [15:0] write_address,
    input  logic [31:0] write_data,
    input  logic [3:0]  byte_enable
);

    // Four sets, two ways per set
    logic [11:0] tag_array   [0:3][0:1];
    logic        valid_array [0:3][0:1];
    logic [31:0] data_array  [0:3][0:1];

    // Lookup address fields
    logic [11:0] lookup_tag;
    logic [1:0]  lookup_index;
    logic [1:0]  lookup_offset;

    // Installation address fields
    logic [11:0] install_tag;
    logic [1:0]  install_index;
    logic [1:0]  install_offset;

    // Write address fields
    logic [11:0] write_tag;
    logic [1:0]  write_index;
    logic [1:0]  write_offset;

    logic hit_way0;
    logic hit_way1;

    // Decode the lookup address
    address_decoder lookup_decoder (
        .address(address),
        .tag(lookup_tag),
        .index(lookup_index),
        .offset(lookup_offset)
    );

    // Decode the installation address
    address_decoder install_decoder (
        .address(install_address),
        .tag(install_tag),
        .index(install_index),
        .offset(install_offset)
    );

    // Decode the write address
    address_decoder write_decoder (
        .address(write_address),
        .tag(write_tag),
        .index(write_index),
        .offset(write_offset)
    );

    // Combinational lookup
    always_comb begin
        hit_way0 =
            valid_array[lookup_index][0] &&
            (tag_array[lookup_index][0] == lookup_tag);

        hit_way1 =
            valid_array[lookup_index][1] &&
            (tag_array[lookup_index][1] == lookup_tag);

        hit = hit_way0 || hit_way1;
        read_data = 32'b0;

        if (hit_way0)
            read_data = data_array[lookup_index][0];
        else if (hit_way1)
            read_data = data_array[lookup_index][1];
    end

    // Reset, install new words, or update selected bytes
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 0; s < 4; s++) begin
                for (int w = 0; w < 2; w++) begin
                    valid_array[s][w] <= 1'b0;
                    tag_array[s][w]   <= 12'b0;
                    data_array[s][w]  <= 32'b0;
                end
            end
        end else if (install) begin
            // Installation has priority over a write update
            valid_array[install_index][install_way] <= 1'b1;
            tag_array[install_index][install_way]   <= install_tag;
            data_array[install_index][install_way]  <= install_data;
        end else if (write_hit) begin
            // Update only the matching cached word
            if (valid_array[write_index][0] &&
                (tag_array[write_index][0] == write_tag)) begin

                for (int b = 0; b < 4; b++) begin
                    if (byte_enable[b])
                        data_array[write_index][0][8*b +: 8]
                            <= write_data[8*b +: 8];
                end

            end else if (valid_array[write_index][1] &&
                         (tag_array[write_index][1] == write_tag)) begin

                for (int b = 0; b < 4; b++) begin
                    if (byte_enable[b])
                        data_array[write_index][1][8*b +: 8]
                            <= write_data[8*b +: 8];
                end
            end
        end
    end

endmodule

