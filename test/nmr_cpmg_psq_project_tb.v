`timescale 1ns / 1ps

module tt_um_thanusit_cpmg_pulse_sequencer_tb;

    // Testbench signals
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg ena;
    reg clk;
    reg rst_n;

    // Instantiate UUT
    tt_um_thanusit_cpmg_pulse_sequencer uut(
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );

    // Watch aliases
    wire rf_pulse_A = uo_out[0];
    wire rf_pulse_B = uo_out[1];
    wire rx_gate    = uo_out[2];
    wire status_busy = uo_out[3];

    // Clock generator (50MHz -> 20ns period)
    always #10 clk = ~clk;

    // SPI Configuration Master emulation task
    task spi_send_word(input [127:0] data_stream);
        integer i;
        begin
            ui_in[3] = 1'b0; // Pull SS_N Low
            #40;
            for (i = 127; i >= 0; i = i - 1) begin
                ui_in[2] = data_stream[i]; // Set MOSI bit
                #20;
                ui_in[1] = 1'b1;           // SCLK High
                #40;
                ui_in[1] = 1'b0;           // SCLK Low
                #20;
            end
            #40;
            ui_in[3] = 1'b1; // Pull SS_N High (Applies Config changes)
            #100;
        end
    endtask

    initial begin
        // Initialize Inputs
        clk    = 0;
        rst_n  = 0;
        ui_in  = 8'h08; // SS_N initialized high, all others low
        uio_in = 8'h00;

        $dumpfile("tt_um_thanusit_cpmg_pulse_sequencer_tb.vcd");
        $dumpvars(0, tt_um_thanusit_cpmg_pulse_sequencer_tb);

        // Reset Sequence
        #100;
        rst_n = 1;
        #100;

        // Configuration values setup: 
        // cfg_tA=5, tau=20, cfg_tB=10, cfg_echo_count=2
        $display("[TB] Sending configuration packet over SPI interface...");
        spi_send_word({32'd5, 32'd20, 32'd10, 32'd2});

        // Trigger pulse sequencing sequence execution
        $display("[TB] Pulsing START to activate sequence execution.");
        #40;
        ui_in[0] = 1'b1; // Start high
        #20;
        ui_in[0] = 1'b0; // Start low

        // Track outputs down active sequencing states
        @(posedge rf_pulse_A);
        $display("[TB] Detected 90-degree RF channel excitation start.");
        
        @(posedge rf_pulse_B);
        $display("[TB] Detected 180-degree refocusing RF pulse start.");
        
        @(posedge rx_gate);
        $display("[TB] Data Acquisition window active.");

        // Wait until completion
        @(negedge status_busy);
        $display("[TB] Sequencer finished sequence and returned to IDLE.");

        #200;
        $display("[TB] Simulation completed successfully.");
        $finish;
    end

endmodule
