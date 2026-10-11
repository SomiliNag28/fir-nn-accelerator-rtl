`timescale 1ns/1ps

module fir_serial_tb;

    reg clk;
    reg reset;
    reg signed [7:0] x_in;
    reg sample_valid;
    wire signed [17:0] y_out;
    wire y_valid;

    fir_serial uut (
        .clk(clk),
        .reset(reset),
        .x_in(x_in),
        .sample_valid(sample_valid),
        .y_out(y_out),
        .y_valid(y_valid)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("sim/fir_serial.vcd");
        $dumpvars(0, fir_serial_tb);

        clk = 0;
        reset = 1;
        x_in = 0;
        sample_valid = 0;
        #12 reset = 0;

        // send impulse sample
        @(posedge clk); #1 x_in = 8'sd100; sample_valid = 1;
        @(posedge clk); #1 sample_valid = 0; x_in = 8'sd0;

        // wait for the 8-cycle MAC to complete
        repeat (10) @(posedge clk);

        // send a second (zero) sample so the second impulse value
        // shifts through, to check the next tap value too
        @(posedge clk); #1 sample_valid = 1;
        @(posedge clk); #1 sample_valid = 0;

        repeat (10) @(posedge clk);

        $finish;
    end

    always @(posedge clk) begin
        if (y_valid)
            $display("Time=%0t | y_out=%d (VALID)", $time, y_out);
    end

endmodule