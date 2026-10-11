module mac_layer #(
    parameter IN_SIZE    = 784,
    parameter OUT_SIZE   = 32,
    parameter APPLY_RELU = 1,
    parameter WEIGHT_FILE = ""   // hex file path, loaded via $readmemh if non-empty
) (
    input  wire                        clk,
    input  wire                        reset,
    input  wire                        start,

    // Input vector load interface (write one value per cycle before `start`)
    input  wire                        in_load_en,
    input  wire [$clog2(IN_SIZE)-1:0]  in_load_addr,
    input  wire signed [7:0]           in_load_data,

    output reg                         done,
    output reg  signed [31:0]          out_val,
    output reg  [$clog2(OUT_SIZE)-1:0] out_idx,
    output reg                         out_valid
);

    reg signed [7:0] weights [0:(OUT_SIZE*IN_SIZE)-1];
    reg signed [7:0] in_vec  [0:IN_SIZE-1];

    initial begin
        if (WEIGHT_FILE != "")
            $readmemh(WEIGHT_FILE, weights);
    end

    // External write port for loading the input vector
    always @(posedge clk) begin
        if (in_load_en)
            in_vec[in_load_addr] <= in_load_data;
    end

    reg [$clog2(OUT_SIZE)-1:0] neuron_idx;
    reg [$clog2(IN_SIZE)-1:0]  tap_idx;
    reg signed [31:0] accum;
    reg signed [31:0] final_val;
    reg busy;

    wire [31:0] weight_addr = neuron_idx * IN_SIZE + tap_idx;
    wire signed [7:0] cur_w = weights[weight_addr];
    wire signed [7:0] cur_x = in_vec[tap_idx];

    always @(posedge clk) begin
        if (reset) begin
            neuron_idx <= 0;
            tap_idx    <= 0;
            accum      <= 0;
            busy       <= 0;
            done       <= 0;
            out_valid  <= 0;
        end else begin
            out_valid <= 0;
            done      <= 0;

            if (start && !busy) begin
                busy       <= 1;
                neuron_idx <= 0;
                tap_idx    <= 0;
                accum      <= 0;
            end else if (busy) begin
                accum <= accum + (cur_x * cur_w);

                if (tap_idx == IN_SIZE-1) begin
                    final_val = accum + (cur_x * cur_w);
                    if (APPLY_RELU && final_val < 0)
                        final_val = 0;

                    out_val   <= final_val;
                    out_idx   <= neuron_idx;
                    out_valid <= 1;

                    tap_idx <= 0;
                    accum   <= 0;

                    if (neuron_idx == OUT_SIZE-1) begin
                        busy <= 0;
                        done <= 1;
                    end else begin
                        neuron_idx <= neuron_idx + 1;
                    end
                end else begin
                    tap_idx <= tap_idx + 1;
                end
            end
        end
    end

endmodule