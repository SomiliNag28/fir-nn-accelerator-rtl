`timescale 1ns/1ps

module fir_serial_check_tb;

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

    integer file, r;
    integer x_val, y_expected;
    integer errors;

    initial begin
        $dumpfile("sim/fir_serial_check.vcd");
        $dumpvars(0, fir_serial_check_tb);

        clk = 0;
        reset = 1;
        x_in = 0;
        sample_valid = 0;
        errors = 0;

        #12 reset = 0;

        file = $fopen("sim/test_vectors.txt", "r");
        if (file == 0) begin
            $display("ERROR: could not open test_vectors.txt");
            $finish;
        end

        while (!$feof(file)) begin
            r = $fscanf(file, "%d %d\n", x_val, y_expected);
            if (r == 2) begin
                // send the new sample
                @(posedge clk); #1;
                x_in = x_val[7:0];
                sample_valid = 1;

                @(posedge clk); #1;
                sample_valid = 0;

                // wait for the 8-cycle MAC to finish and y_valid to pulse
                while (!y_valid) @(posedge clk);
                #1;

                if (y_out !== y_expected) begin
                    $display("MISMATCH: got %d, expected %d", y_out, y_expected);
                    errors = errors + 1;
                end else begin
                    $display("PASS: y_out=%d", y_out);
                end

                @(posedge clk); // let y_valid drop before next sample
            end
        end

        $fclose(file);

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TESTS FAILED", errors);

        $finish;
    end

endmodule