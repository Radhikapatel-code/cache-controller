
module cache_array (
    input  logic        clk,
    input  logic        rst_n,

    input  logic [15:0] address,
    output logic        hit,
    output logic [31:0] read_data,

    input  logic        install,
    input  logic        install_way,
    input  logic [15:0] install_address,
    input  logic [31:0] install_data
);

    logic [11:0] tag_array   [0:3][0:1];
    logic        valid_array [0:3][0:1];
    logic [31:0] data_array  [0:3][0:1];

    logic [11:0] lookup_tag;
    logic [1:0]  lookup_index;
    logic [1:0]  lookup_offset;

    logic [11:0] install_tag;
    logic [1:0]  install_index;
    logic [1:0]  install_offset;

    logic hit_way0;
    logic hit_way1;

    address_decoder lookup_decoder (
        .address(address),
        .tag(lookup_tag),
        .index(lookup_index),
        .offset(lookup_offset)
    );

    address_decoder install_decoder (
        .address(install_address),
        .tag(install_tag),
        .index(install_index),
        .offset(install_offset)
    );

    always_comb begin
        hit_way0 = valid_array[lookup_index][0] &&
                   (tag_array[lookup_index][0] == lookup_tag);

        hit_way1 = valid_array[lookup_index][1] &&
                   (tag_array[lookup_index][1] == lookup_tag);

        hit = hit_way0 || hit_way1;
        read_data = 32'b0;

        if (hit_way0)
            read_data = data_array[lookup_index][0];
        else if (hit_way1)
            read_data = data_array[lookup_index][1];
    end

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
            valid_array[install_index][install_way] <= 1'b1;
            tag_array[install_index][install_way]   <= install_tag;
            data_array[install_index][install_way]  <= install_data;
        end
    end

endmodule
