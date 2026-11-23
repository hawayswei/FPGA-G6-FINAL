// ============================================================================
// Module : bt_msg_tx
// Owner  : integrator
// Purpose: Send short text messages to the phone. Each bit of req_i asks for
//          one message; requests are remembered until sent (lowest index
//          first). Every message is followed by CR LF.
//          The texts are parameters (up to 16 characters each), so they can
//          be changed where this module is instantiated without touching
//          the logic. An empty string disables that message.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module bt_msg_tx #(
    parameter           CLKS_PER_BIT = 13021,
    parameter [127:0]   MSG0 = "FALL",
    parameter [127:0]   MSG1 = "SOS",
    parameter [127:0]   MSG2 = "OK",
    parameter [127:0]   MSG3 = "TEMP HIGH",
    parameter [127:0]   MSG4 = "TEMP LOW",
    parameter [127:0]   MSG5 = "SET",
    parameter [127:0]   MSG6 = "ARE YOU OK?",
    parameter [127:0]   MSG7 = ""
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire [7:0] req_i,           // one-cycle pulses, bit n = send MSGn
    output wire       tx_o,
    output wire       busy_o
);

    localparam [1:0] ST_IDLE = 2'd0;
    localparam [1:0] ST_TEXT = 2'd1;
    localparam [1:0] ST_CR   = 2'd2;
    localparam [1:0] ST_LF   = 2'd3;

    reg [7:0]   pending_r = 8'd0;
    reg [1:0]   state_r   = ST_IDLE;
    reg [127:0] text_r    = 128'd0;
    reg [4:0]   left_r    = 5'd0;      // characters left in text_r
    reg         tx_start_r = 1'b0;
    reg [7:0]   tx_data_r  = 8'h00;
    wire        tx_busy;

    assign busy_o = (state_r != ST_IDLE) || tx_busy || tx_start_r || (pending_r != 8'd0);

    bt_uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk_i   (clk_i),
        .rst_n_i (rst_n_i),
        .start_i (tx_start_r),
        .data_i  (tx_data_r),
        .tx_o    (tx_o),
        .busy_o  (tx_busy)
    );

    // lowest pending request first
    reg [2:0] sel;
    wire      any = (pending_r != 8'd0);
    always @(*) begin
        if      (pending_r[0]) sel = 3'd0;
        else if (pending_r[1]) sel = 3'd1;
        else if (pending_r[2]) sel = 3'd2;
        else if (pending_r[3]) sel = 3'd3;
        else if (pending_r[4]) sel = 3'd4;
        else if (pending_r[5]) sel = 3'd5;
        else if (pending_r[6]) sel = 3'd6;
        else                   sel = 3'd7;
    end

    function [127:0] msg_text;
        input [2:0] idx;
        begin
            case (idx)
                3'd0: msg_text = MSG0;
                3'd1: msg_text = MSG1;
                3'd2: msg_text = MSG2;
                3'd3: msg_text = MSG3;
                3'd4: msg_text = MSG4;
                3'd5: msg_text = MSG5;
                3'd6: msg_text = MSG6;
                default: msg_text = MSG7;
            endcase
        end
    endfunction

    wire tx_ready = !tx_busy && !tx_start_r;

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            pending_r  <= 8'd0;
            state_r    <= ST_IDLE;
            text_r     <= 128'd0;
            left_r     <= 5'd0;
            tx_start_r <= 1'b0;
            tx_data_r  <= 8'h00;
        end else begin
            tx_start_r <= 1'b0;
            pending_r  <= pending_r | req_i;

            case (state_r)
                ST_IDLE: begin
                    if (any) begin
                        pending_r <= (pending_r | req_i) & ~(8'd1 << sel);
                        text_r    <= msg_text(sel);
                        left_r    <= 5'd16;
                        // an empty text means "message disabled": drop the request
                        state_r   <= (msg_text(sel) == 128'd0) ? ST_IDLE : ST_TEXT;
                    end
                end
                ST_TEXT: begin
                    if (left_r == 5'd0) begin
                        state_r <= ST_CR;
                    end else if (text_r[127:120] == 8'h00) begin
                        text_r <= {text_r[119:0], 8'h00};      // skip padding
                        left_r <= left_r - 5'd1;
                    end else if (tx_ready) begin
                        tx_data_r  <= text_r[127:120];
                        tx_start_r <= 1'b1;
                        text_r     <= {text_r[119:0], 8'h00};
                        left_r     <= left_r - 5'd1;
                    end
                end
                ST_CR: begin
                    if (tx_ready) begin
                        tx_data_r  <= 8'h0D;
                        tx_start_r <= 1'b1;
                        state_r    <= ST_LF;
                    end
                end
                ST_LF: begin
                    if (tx_ready) begin
                        tx_data_r  <= 8'h0A;
                        tx_start_r <= 1'b1;
                        state_r    <= ST_IDLE;
                    end
                end
                default: state_r <= ST_IDLE;
            endcase
        end
    end

endmodule
