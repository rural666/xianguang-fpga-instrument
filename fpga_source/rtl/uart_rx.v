`default_nettype none
module uart_rx #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BAUD = 115200
)(
    input wire clk, input wire rst, input wire rx,
    output reg valid, output reg [7:0] data,
    output reg framing_error
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;
    reg rx_meta, rx_sync;
    reg [1:0] state;
    reg [15:0] ticks;
    reg [2:0] bit_index;
    reg [7:0] shift;
    always @(posedge clk) begin
        if (rst) begin rx_meta <= 1'b1; rx_sync <= 1'b1; end
        else begin rx_meta <= rx; rx_sync <= rx_meta; end
    end
    always @(posedge clk) begin
        if (rst) begin
            state <= 0; ticks <= 0; bit_index <= 0;
            valid <= 0; data <= 0; shift <= 0; framing_error <= 0;
        end else begin
            valid <= 0; framing_error <= 0;
            case (state)
                0: if (!rx_sync) begin ticks <= DIV/2-1; state <= 1; end
                1: if (ticks != 0) ticks <= ticks-1'b1;
                   else if (rx_sync) state <= 0;
                   else begin ticks <= DIV-1; bit_index <= 0; state <= 2; end
                2: if (ticks != 0) ticks <= ticks-1'b1;
                   else begin
                       shift[bit_index] <= rx_sync; ticks <= DIV-1;
                       if (bit_index == 7) state <= 3;
                       else bit_index <= bit_index+1'b1;
                   end
                3: if (ticks != 0) ticks <= ticks-1'b1;
                   else begin
                       if (rx_sync) begin data <= shift; valid <= 1; end
                       else framing_error <= 1;
                       state <= 0;
                   end
            endcase
        end
    end
endmodule
`default_nettype wire
