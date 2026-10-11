`timescale 1ns/1ps

module fir_direct_tb;

    reg clk;
    reg reset;
    reg signed [7:0] x_in;
    wire signed [17:0] y_out;

    fir_direct uut (
        .clk(clk),
        .reset(reset),
        .x_in(x_in),
        .y_out(y_out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/fir_direct.vcd");
        $dumpvars(0, fir_direct_tb);

        clk = 0;
        reset = 1;
        x_in = 0;
        #12 reset = 0;

        // feed an impulse: one sample = 100, rest = 0
        // this lets you literally see the coefficients appear
        // at the output, one per clock cycle, in order
        @(posedge clk); #1 x_in = 8'sd100;
        @(posedge clk); #1 x_in = 8'sd0;
        repeat (10) @(posedge clk);

        $finish;
    end

    always @(posedge clk)
        $display("Time=%0t | x_in=%d | y_out=%d", $time, x_in, y_out);

endmodule