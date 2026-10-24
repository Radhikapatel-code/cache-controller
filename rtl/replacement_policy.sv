
module replacement_policy (
    input  logic       clk,
    input  logic       rst_n,

    input  logic [1:0] set_index,
    input  logic       access_valid,
    input  logic       accessed_way,

    input  logic       valid_way0,
    input  logic       valid_way1,

    output logic       victim_way
);

    logic lru [0:3];

    always_comb begin
        if (!valid_way0)
            victim_way = 1'b0;
        else if (!valid_way1)
            victim_way = 1'b1;
        else
            victim_way = lru[set_index];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int s = 0; s < 4; s++)
                lru[s] <= 1'b0;
        end else if (access_valid) begin
            // The opposite way becomes the next eviction candidate.
            lru[set_index] <= ~accessed_way;
        end
    end

endmodule
