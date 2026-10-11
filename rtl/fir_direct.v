module fir_direct (
    input  wire               clk,
    input  wire               reset,
    input  wire signed [7:0]  x_in,      // new input sample each cycle
    output reg  signed [17:0] y_out      // filtered output
);

    // 8 fixed coefficients (example: simple low-pass weights)
    // you'll replace these with real designed coefficients later
    localparam signed [7:0] h0 = 8'sd2;
    localparam signed [7:0] h1 = 8'sd4;
    localparam signed [7:0] h2 = 8'sd8;
    localparam signed [7:0] h3 = 8'sd10;
    localparam signed [7:0] h4 = 8'sd10;
    localparam signed [7:0] h5 = 8'sd8;
    localparam signed [7:0] h6 = 8'sd4;
    localparam signed [7:0] h7 = 8'sd2;

    // shift register chain: holds the 8 most recent input samples
    reg signed [7:0] x0, x1, x2, x3, x4, x5, x6, x7;

    always @(posedge clk) begin
        if (reset) begin
            x0 <= 0; x1 <= 0; x2 <= 0; x3 <= 0;
            x4 <= 0; x5 <= 0; x6 <= 0; x7 <= 0;
        end else begin
            x0 <= x_in;  // newest sample comes in
            x1 <= x0;    // everything shifts down by one
            x2 <= x1;
            x3 <= x2;
            x4 <= x3;
            x5 <= x4;
            x6 <= x5;
            x7 <= x6;
        end
    end

    // multiply-accumulate: combinational, happens every cycle
    // based on the CURRENT shift register contents
    always @(*) begin
        y_out = (x0*h0) + (x1*h1) + (x2*h2) + (x3*h3)
              + (x4*h4) + (x5*h5) + (x6*h6) + (x7*h7);
    end

endmodule