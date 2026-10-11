`timescale 1ns/1ps

module fir_direct_check_tb;

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

    integer file, r;
    integer x_val, y_expected;
    integer errors;
    integer latency_cycles;
    integer sample_num;

    // shift register to delay the "expected" value by the pipeline latency
    reg signed [31:0] expected_pipe [0:2];
    integer i;

    initial begin
        $dumpfile("sim/fir_direct_check.vcd");
        $dumpvars(0, fir_direct_check_tb);

        clk = 0;
        reset = 1;
        x_in = 0;
        errors = 0;
        sample_num = 0;
        latency_cycles = 1;  // corrected based on observed mismatch pattern

        for (i = 0; i <= 2; i = i + 1)
            expected_pipe[i] = 0;

        #12 reset = 0;

        file = $fopen("sim/test_vectors.txt", "r");
        if (file == 0) begin
            $display("ERROR: could not open test_vectors.txt");
            $finish;
        end

        while (!$feof(file)) begin
            r = $fscanf(file, "%d %d\n", x_val, y_expected);
            if (r == 2) begin
                @(posedge clk); #1;
                x_in = x_val[7:0];

                // shift expected value into delay pipe to align with latency
                expected_pipe[2] = expected_pipe[1];
                expected_pipe[1] = expected_pipe[0];
                expected_pipe[0] = y_expected;

                sample_num = sample_num + 1;
                if (sample_num > latency_cycles) begin
                    #1;
                    if (y_out !== expected_pipe[latency_cycles]) begin
                        $display("MISMATCH at time %0t: got %d, expected %d",
                                  $time, y_out, expected_pipe[latency_cycles]);
                        errors = errors + 1;
                    end else begin
                        $display("PASS at time %0t: y_out=%d", $time, y_out);
                    end
                end
            end
        end

        $fclose(file);

        repeat (5) @(posedge clk); // flush remaining pipeline

        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TESTS FAILED", errors);

        $finish;
    end

endmodule