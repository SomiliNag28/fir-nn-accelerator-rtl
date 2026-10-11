module accelerator_top (
    input  wire clk,
    input  wire reset,
    input  wire start,

    input  wire                image_load_en,
    input  wire [9:0]          image_load_addr,
    input  wire signed [7:0]   image_load_data,

    output reg  [319:0]        logit_out_flat,
    output reg                 all_done
);

    localparam SHIFT_AMT = 11;  // calibrated in Python against the quantized reference model — see ml/calibrate_shift.py

    reg  l1_start;
    wire l1_done;
    wire signed [31:0] l1_out_val;
    wire [4:0] l1_out_idx;
    wire l1_out_valid;

    mac_layer #(
        .IN_SIZE(784), .OUT_SIZE(32), .APPLY_RELU(1),
        .WEIGHT_FILE("rtl/fc1_weights.hex")
    ) layer1 (
        .clk(clk), .reset(reset), .start(l1_start),
        .in_load_en(image_load_en),
        .in_load_addr(image_load_addr),
        .in_load_data(image_load_data),
        .done(l1_done), .out_val(l1_out_val),
        .out_idx(l1_out_idx), .out_valid(l1_out_valid)
    );

    reg  l2_start;
    wire l2_done;
    wire signed [31:0] l2_out_val;
    wire [3:0] l2_out_idx;
    wire l2_out_valid;

    reg                l2_in_load_en;
    reg  [4:0]          l2_in_load_addr;
    reg  signed [7:0]   l2_in_load_data;

    mac_layer #(
        .IN_SIZE(32), .OUT_SIZE(10), .APPLY_RELU(0),
        .WEIGHT_FILE("rtl/fc2_weights.hex")
    ) layer2 (
        .clk(clk), .reset(reset), .start(l2_start),
        .in_load_en(l2_in_load_en),
        .in_load_addr(l2_in_load_addr),
        .in_load_data(l2_in_load_data),
        .done(l2_done), .out_val(l2_out_val),
        .out_idx(l2_out_idx), .out_valid(l2_out_valid)
    );

    localparam IDLE=0, RUN_L1=1, FEED_L2=2, RUN_L2=3, FINISHED=4;
    reg [2:0] state;

    reg signed [31:0] shifted_val;  // module-level, used for the rescale computation

    always @(posedge clk) begin
        if (reset) begin
            state         <= IDLE;
            l1_start      <= 0;
            l2_start      <= 0;
            l2_in_load_en <= 0;
            all_done      <= 0;
        end else begin
            l1_start      <= 0;
            l2_start      <= 0;
            l2_in_load_en <= 0;
            all_done      <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        l1_start <= 1;
                        state <= RUN_L1;
                    end
                end

                RUN_L1: begin
                    if (l1_out_valid) begin
                        // Rescale: right-shift (power-of-two approx of 1/scale),
                        // then saturate to signed int8 range. This replaces naive
                        // truncation, which was taking meaningless low-order bits.
                        shifted_val = l1_out_val >>> SHIFT_AMT;
                        if (shifted_val > 127)
                            shifted_val = 127;
                        else if (shifted_val < -128)
                            shifted_val = -128;

                        l2_in_load_en   <= 1;
                        l2_in_load_addr <= l1_out_idx;
                        l2_in_load_data <= shifted_val[7:0];
                    end
                    if (l1_done) begin
                        state <= FEED_L2;
                    end
                end

                FEED_L2: begin
                    l2_start <= 1;
                    state <= RUN_L2;
                end

                RUN_L2: begin
                    if (l2_out_valid) begin
                        logit_out_flat[l2_out_idx*32 +: 32] <= l2_out_val;
                    end
                    if (l2_done) begin
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    all_done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule