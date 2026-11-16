// ============================================================================
// Testbench : tb_acl_spi_master
// DUT       : acl_spi_master (HALF_DIV = 4 so one byte takes 64 clk cycles)
// Model     : a mode-0 SPI slave that shifts out a known byte on the falling
//             edge and samples MOSI on the rising edge.
// Run time  : finishes by itself well within 20 us ("run 20us", never "run all"
//             in the Vivado MCP/Tcl console).
// Expected  : prints "TB PASS" when all bytes match in both directions.
// ============================================================================
`timescale 1ns / 1ps

module tb_acl_spi_master;

    reg        clk_i     = 1'b0;
    reg        rst_n_i   = 1'b0;
    reg        start_i   = 1'b0;
    reg  [7:0] tx_data_i = 8'h00;
    wire [7:0] rx_data_o;
    wire       done_o, busy_o, sclk_o, mosi_o;
    wire       miso_i;

    integer errors = 0;

    acl_spi_master #(.HALF_DIV(4)) dut (
        .clk_i     (clk_i),
        .rst_n_i   (rst_n_i),
        .start_i   (start_i),
        .tx_data_i (tx_data_i),
        .rx_data_o (rx_data_o),
        .done_o    (done_o),
        .busy_o    (busy_o),
        .sclk_o    (sclk_o),
        .mosi_o    (mosi_o),
        .miso_i    (miso_i)
    );

    always #4 clk_i = ~clk_i;        // 125 MHz

    // ---- SPI slave model (mode 0) -----------------------------------------
    reg [7:0] slv_tx   = 8'h00;      // byte the slave will send
    reg [7:0] slv_sh   = 8'h00;
    reg [7:0] slv_rx   = 8'h00;      // byte the slave received
    reg       slv_load = 1'b0;

    assign miso_i = slv_sh[7];

    always @(posedge slv_load)  slv_sh = slv_tx;
    always @(posedge sclk_o)    slv_rx = {slv_rx[6:0], mosi_o};
    always @(negedge sclk_o)    slv_sh = {slv_sh[6:0], 1'b0};

    // ---- One byte transfer and check --------------------------------------
    task xfer;
        input [7:0] m_byte;          // master -> slave
        input [7:0] s_byte;          // slave  -> master
        begin
            slv_tx = s_byte;
            slv_load = 1'b1; #1 slv_load = 1'b0;
            @(posedge clk_i);
            tx_data_i <= m_byte;
            start_i   <= 1'b1;
            @(posedge clk_i);
            start_i   <= 1'b0;
            @(posedge done_o);
            @(posedge clk_i);
            if (rx_data_o !== s_byte) begin
                errors = errors + 1;
                $display("TB ERROR: master received %h, expected %h", rx_data_o, s_byte);
            end
            if (slv_rx !== m_byte) begin
                errors = errors + 1;
                $display("TB ERROR: slave received %h, expected %h", slv_rx, m_byte);
            end
            if (sclk_o !== 1'b0 || busy_o !== 1'b0) begin
                errors = errors + 1;
                $display("TB ERROR: SCLK or busy not idle after the byte");
            end
        end
    endtask

    initial begin
        #40 rst_n_i = 1'b1;
        xfer(8'h0B, 8'hAD);
        xfer(8'hA5, 8'h5A);
        xfer(8'h00, 8'hFF);
        xfer(8'hFF, 8'h00);
        xfer(8'h81, 8'h7E);
        if (errors == 0) $display("TB PASS: 5 bytes matched in both directions");
        else             $display("TB FAIL: %0d errors", errors);
        $finish;
    end

    initial begin
        #20000;
        $display("TB FAIL: timeout");
        $finish;
    end

endmodule
