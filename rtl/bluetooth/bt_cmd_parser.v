// ============================================================================
// Module : bt_cmd_parser
// Owner  : integrator
// Purpose: Turn bytes from the phone into settings.
//            'A' / 'E' / 'S'      -> mode adult / elderly / sport
//            'H' + three digits   -> height in cm, e.g. H165
//                                    (accepted only inside HEIGHT_MIN..HEIGHT_MAX)
//          Upper and lower case both work. CR, LF and unknown characters are
//          ignored. cfg_update_o pulses for one cycle when a setting was
//          accepted.
//          To change the command letters, edit the localparams below.
// Clock  : clk_i (125 MHz system clock).
// Reset  : rst_n_i, synchronous, active low.
// ============================================================================
`timescale 1ns / 1ps

module bt_cmd_parser #(
    parameter [7:0] HEIGHT_DEFAULT = 8'd170,
    parameter [9:0] HEIGHT_MIN     = 10'd100,
    parameter [9:0] HEIGHT_MAX     = 10'd220
) (
    input  wire       clk_i,
    input  wire       rst_n_i,
    input  wire [7:0] rx_data_i,
    input  wire       rx_valid_i,
    output reg  [1:0] mode_o       = 2'd0,          // 0 adult, 1 elderly, 2 sport
    output reg  [7:0] height_o     = HEIGHT_DEFAULT,
    output reg        cfg_update_o = 1'b0
);

    // command letters (upper case; lower case is folded to upper case)
    localparam [7:0] CH_ADULT   = "A";
    localparam [7:0] CH_ELDERLY = "E";
    localparam [7:0] CH_SPORT   = "S";
    localparam [7:0] CH_HEIGHT  = "H";

    reg [1:0] digits_left_r = 2'd0;      // > 0 while collecting height digits
    reg [9:0] value_r       = 10'd0;

    wire       is_lower = (rx_data_i >= "a") && (rx_data_i <= "z");
    wire [7:0] ch       = is_lower ? (rx_data_i - 8'h20) : rx_data_i;
    wire       is_digit = (rx_data_i >= "0") && (rx_data_i <= "9");
    wire [9:0] next_val = value_r * 10'd10 + {6'd0, rx_data_i[3:0]};

    always @(posedge clk_i) begin
        if (!rst_n_i) begin
            mode_o        <= 2'd0;
            height_o      <= HEIGHT_DEFAULT;
            cfg_update_o  <= 1'b0;
            digits_left_r <= 2'd0;
            value_r       <= 10'd0;
        end else begin
            cfg_update_o <= 1'b0;
            if (rx_valid_i) begin
                if (digits_left_r != 2'd0 && is_digit) begin
                    value_r       <= next_val;
                    digits_left_r <= digits_left_r - 2'd1;
                    if (digits_left_r == 2'd1 && next_val >= HEIGHT_MIN && next_val <= HEIGHT_MAX) begin
                        height_o     <= next_val[7:0];
                        cfg_update_o <= 1'b1;
                    end
                end else begin
                    digits_left_r <= 2'd0;            // anything else ends a height entry
                    case (ch)
                        CH_ADULT:   begin mode_o <= 2'd0; cfg_update_o <= 1'b1; end
                        CH_ELDERLY: begin mode_o <= 2'd1; cfg_update_o <= 1'b1; end
                        CH_SPORT:   begin mode_o <= 2'd2; cfg_update_o <= 1'b1; end
                        CH_HEIGHT:  begin digits_left_r <= 2'd3; value_r <= 10'd0; end
                        default: ;                    // CR, LF, unknown: ignore
                    endcase
                end
            end
        end
    end

endmodule
