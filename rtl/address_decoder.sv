
module address_decoder (
    input  logic [15:0] address,
    output logic [11:0] tag,
    output logic [1:0]  index,
    output logic [1:0]  offset
);

    always_comb begin
        tag    = address[15:4];
        index  = address[3:2];
        offset = address[1:0];
    end

endmodule
