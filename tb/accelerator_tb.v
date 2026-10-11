`timescale 1ns/1ps

module accelerator_tb;

    reg clk;
    reg reset;
    reg start;
    reg image_load_en;
    reg [9:0] image_load_addr;
    reg signed [7:0] image_load_data;

    wire [319:0] logit_out_flat;
    wire all_done;

    accelerator_top uut (
        .clk(clk), .reset(reset), .start(start),
        .image_load_en(image_load_en),
        .image_load_addr(image_load_addr),
        .image_load_data(image_load_data),
        .logit_out_flat(logit_out_flat),
        .all_done(all_done)
    );

    always #5 clk = ~clk;

    reg signed [7:0] image_pixels [0:783];
    integer i, img_idx;
    integer best_idx;
    integer best_val;
    integer cur_val;

    integer true_labels [0:9];
    integer correct_count;

    initial begin
        true_labels[0]=7; true_labels[1]=2; true_labels[2]=1; true_labels[3]=0;
        true_labels[4]=4; true_labels[5]=1; true_labels[6]=4; true_labels[7]=9;
        true_labels[8]=5; true_labels[9]=9;

        $dumpfile("sim/accelerator.vcd");
        $dumpvars(0, accelerator_tb);

        correct_count = 0;

        // clk initialized ONCE, here — never touched again
        clk = 0;
        reset = 1;
        start = 0;
        image_load_en = 0;
        image_load_addr = 0;
        image_load_data = 0;
        #12 reset = 0;

        for (img_idx = 0; img_idx < 10; img_idx = img_idx + 1) begin

            // per-image reset pulse, WITHOUT touching clk
            @(posedge clk); #1;
            reset = 1;
            @(posedge clk); #1;
            reset = 0;

            case (img_idx)
                0: $readmemh("sim/test_image_0.hex", image_pixels);
                1: $readmemh("sim/test_image_1.hex", image_pixels);
                2: $readmemh("sim/test_image_2.hex", image_pixels);
                3: $readmemh("sim/test_image_3.hex", image_pixels);
                4: $readmemh("sim/test_image_4.hex", image_pixels);
                5: $readmemh("sim/test_image_5.hex", image_pixels);
                6: $readmemh("sim/test_image_6.hex", image_pixels);
                7: $readmemh("sim/test_image_7.hex", image_pixels);
                8: $readmemh("sim/test_image_8.hex", image_pixels);
                9: $readmemh("sim/test_image_9.hex", image_pixels);
            endcase

            for (i = 0; i < 784; i = i + 1) begin
                @(posedge clk); #1;
                image_load_en   = 1;
                image_load_addr = i;
                image_load_data = image_pixels[i];
            end
            @(posedge clk); #1;
            image_load_en = 0;

            @(posedge clk); #1;
            start = 1;
            @(posedge clk); #1;
            start = 0;

            wait (all_done == 1);
            @(posedge clk); #1;

            best_idx = 0;
            best_val = $signed(logit_out_flat[0 +: 32]);
            for (i = 1; i < 10; i = i + 1) begin
                cur_val = $signed(logit_out_flat[i*32 +: 32]);
                if (cur_val > best_val) begin
                    best_val = cur_val;
                    best_idx = i;
                end
            end

            if (best_idx == true_labels[img_idx])
                correct_count = correct_count + 1;

            $display("Image %0d: true=%0d, RTL_predicted=%0d, match=%0d",
                      img_idx, true_labels[img_idx], best_idx,
                      (best_idx == true_labels[img_idx]));

        end

        $display("\nRTL accuracy on this 10-image set: %0d/10", correct_count);
        $finish;
    end

endmodule