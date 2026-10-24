
module cache_controller (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        cpu_req,
    input  logic        cpu_write,
    input  logic [15:0] cpu_address,
    input  logic [31:0] cpu_write_data,
    input  logic [3:0]  cpu_byte_enable,
    output logic        cpu_ready,
    output logic [31:0] cpu_read_data,

    output logic        mem_req,
    output logic        mem_write,
    output logic [15:0] mem_address,
    output logic [31:0] mem_write_data,
    output logic [3:0]  mem_byte_enable,
    input  logic        mem_ready,
    input  logic [31:0] mem_read_data
);

    typedef enum logic [2:0] {
        IDLE,
        LOOKUP,
        READ_WAIT,
        REFILL,
        WRITE_WAIT,
        RESPOND
    } state_t;

    state_t state;

    logic [15:0] saved_address;
    logic [31:0] saved_write_data;
    logic [3:0]  saved_byte_enable;
    logic        saved_write;
    logic [31:0] saved_read_data;
    logic [31:0] fetched_word;

    logic cache_hit, cache_hit_way;
    logic [31:0] cache_read_data;
    logic valid_way0, valid_way1;

    logic cache_install, cache_install_way;
    logic [15:0] cache_install_address;
    logic [31:0] cache_install_data;

    logic cache_write_hit;
    logic [15:0] cache_write_address;
    logic [31:0] cache_write_data;
    logic [3:0] cache_byte_enable;

    logic [11:0] request_tag;
    logic [1:0] request_index, request_offset;
    logic victim_way;
    logic lru_access_valid, lru_accessed_way;

    logic [31:0] merged_word;

    address_decoder request_decoder (
        .address(saved_address),
        .tag(request_tag),
        .index(request_index),
        .offset(request_offset)
    );

    cache_array cache (
        .clk(clk),
        .rst_n(rst_n),
        .address(saved_address),
        .hit(cache_hit),
        .hit_way(cache_hit_way),
        .read_data(cache_read_data),
        .valid_way0(valid_way0),
        .valid_way1(valid_way1),
        .install(cache_install),
        .install_way(cache_install_way),
        .install_address(cache_install_address),
        .install_data(cache_install_data),
        .write_hit(cache_write_hit),
        .write_address(cache_write_address),
        .write_data(cache_write_data),
        .byte_enable(cache_byte_enable)
    );

    replacement_policy replacement (
        .clk(clk),
        .rst_n(rst_n),
        .set_index(request_index),
        .access_valid(lru_access_valid),
        .accessed_way(lru_accessed_way),
        .valid_way0(valid_way0),
        .valid_way1(valid_way1),
        .victim_way(victim_way)
    );

    always_comb begin
        merged_word = fetched_word;

        for (int b = 0; b < 4; b++) begin
            if (saved_byte_enable[b])
                merged_word[8*b +: 8] =
                    saved_write_data[8*b +: 8];
        end
    end

    always_comb begin
        cpu_ready = 1'b0;
        cpu_read_data = saved_read_data;

        mem_req = 1'b0;
        mem_write = 1'b0;
        mem_address = saved_address;
        mem_write_data = saved_write_data;
        mem_byte_enable = saved_byte_enable;

        cache_install = 1'b0;
        cache_install_way = victim_way;
        cache_install_address = saved_address;
        cache_install_data = fetched_word;

        cache_write_hit = 1'b0;
        cache_write_address = saved_address;
        cache_write_data = saved_write_data;
        cache_byte_enable = saved_byte_enable;

        lru_access_valid = 1'b0;
        lru_accessed_way = 1'b0;

        case (state)
            LOOKUP: begin
                if (cache_hit) begin
                    lru_access_valid = 1'b1;
                    lru_accessed_way = cache_hit_way;

                    if (saved_write) begin
                        cache_write_hit = 1'b1;
                        mem_req = 1'b1;
                        mem_write = 1'b1;
                    end
                end else begin
                    mem_req = 1'b1;
                    mem_write = 1'b0;
                end
            end

            READ_WAIT: begin
                mem_req = 1'b1;
                mem_write = 1'b0;
            end

            REFILL: begin
                cache_install = 1'b1;
                cache_install_data = saved_write ? merged_word : fetched_word;

                if (saved_write) begin
                    mem_req = 1'b1;
                    mem_write = 1'b1;
                    mem_write_data = merged_word;
                end
            end

            WRITE_WAIT: begin
                mem_req = 1'b1;
                mem_write = 1'b1;
            end

            RESPOND: begin
                cpu_ready = 1'b1;
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            saved_address <= 16'b0;
            saved_write_data <= 32'b0;
            saved_byte_enable <= 4'b0;
            saved_write <= 1'b0;
            saved_read_data <= 32'b0;
            fetched_word <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req) begin
                        saved_address <= cpu_address;
                        saved_write_data <= cpu_write_data;
                        saved_byte_enable <= cpu_byte_enable;
                        saved_write <= cpu_write;
                        state <= LOOKUP;
                    end
                end

                LOOKUP: begin
                    if (cache_hit) begin
                        if (saved_write)
                            state <= WRITE_WAIT;
                        else begin
                            saved_read_data <= cache_read_data;
                            state <= RESPOND;
                        end
                    end else begin
                        state <= READ_WAIT;
                    end
                end

                READ_WAIT: begin
                    if (mem_req && mem_ready) begin
                        fetched_word <= mem_read_data;
                        state <= REFILL;
                    end
                end

                REFILL: begin
                    if (saved_write)
                        state <= WRITE_WAIT;
                    else begin
                        saved_read_data <= fetched_word;
                        state <= RESPOND;
                    end
                end

                WRITE_WAIT: begin
                    if (mem_req && mem_ready) begin
                        if (saved_write)
                            saved_read_data <= saved_write_data;
                        state <= RESPOND;
                    end
                end

                RESPOND: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

