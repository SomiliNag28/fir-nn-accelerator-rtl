module fir_serial (
    input  wire               clk,
    input  wire               reset,
    input  wire signed [7:0]  x_in,
    input  wire               sample_valid,  // pulse high for 1 cycle when x_in is new
    output reg  signed [17:0] y_out,
    output reg                y_valid        // pulses high for 1 cycle when y_out is ready
);

    localparam signed [7:0] h0 = 8'sd2;
    localparam signed [7:0] h1 = 8'sd4;
    localparam signed [7:0] h2 = 8'sd8;
    localparam signed [7:0] h3 = 8'sd10;
    localparam signed [7:0] h4 = 8'sd10;
    localparam signed [7:0] h5 = 8'sd8;
    localparam signed [7:0] h6 = 8'sd4;
    localparam signed [7:0] h7 = 8'sd2;

    reg signed [7:0] x0, x1, x2, x3, x4, x5, x6, x7;

    // shift register: same as before, updates once per new sample
    always @(posedge clk) begin
        if (reset) begin
            x0<=0; x1<=0; x2<=0; x3<=0; x4<=0; x5<=0; x6<=0; x7<=0;
        end else if (sample_valid) begin
            x0 <= x_in;
            x1 <= x0; x2 <= x1; x3 <= x2; x4 <= x3;
            x5 <= x4; x6 <= x5; x7 <= x6;
        end
    end

    // pick current tap's sample and coefficient based on counter
    reg [2:0] tap_count;        // counts 0 to 7
    reg signed [7:0] cur_x;
    reg signed [7:0] cur_h;
    reg signed [17:0] accum;
    reg busy;

    always @(*) begin
        case (tap_count)
            3'd0: begin cur_x = x0; cur_h = h0; end
            3'd1: begin cur_x = x1; cur_h = h1; end
            3'd2: begin cur_x = x2; cur_h = h2; end
            3'd3: begin cur_x = x3; cur_h = h3; end
            3'd4: begin cur_x = x4; cur_h = h4; end
            3'd5: begin cur_x = x5; cur_h = h5; end
            3'd6: begin cur_x = x6; cur_h = h6; end
            3'd7: begin cur_x = x7; cur_h = h7; end
        endcase
    end

    // ONE shared multiplier + accumulator, reused 8 times
    always @(posedge clk) begin
        if (reset) begin
            tap_count <= 0;
            accum     <= 0;
            busy      <= 0;
            y_out     <= 0;
            y_valid   <= 0;
        end else begin
            y_valid <= 0; // default: not valid unless set below

            if (sample_valid && !busy) begin
                // start a new 8-cycle MAC sequence
                busy      <= 1;
                tap_count <= 0;
                accum     <= 0;
            end else if (busy) begin
                accum <= accum + (cur_x * cur_h);  // one MAC per cycle

                if (tap_count == 3'd7) begin
                    y_out   <= accum + (cur_x * cur_h); // include final tap
                    y_valid <= 1;
                    busy    <= 0;
                    tap_count <= 0;
                end else begin
                    tap_count <= tap_count + 1;
                end
            end
        end
    end

endmodule