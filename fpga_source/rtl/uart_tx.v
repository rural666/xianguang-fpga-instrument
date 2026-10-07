`default_nettype none
module uart_tx #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BAUD = 115200
)(
    input wire clk, input wire rst,
    input wire start, input wire [7:0] data,
    output reg tx, output reg busy
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;
    reg [15:0] ticks;
    reg [3:0] bit_index;
    reg [9:0] frame;
    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1; busy <= 1'b0;
            ticks <= 0; bit_index <= 0; frame <= 10'h3ff;
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                frame <= {1'b1, data, 1'b0};
                tx <= 1'b0; busy <= 1'b1;
                ticks <= DIV-1; bit_index <= 0;
            end
        end else if (ticks != 0) begin
            ticks <= ticks - 1'b1;
        end else if (bit_index == 9) begin
            tx <= 1'b1; busy <= 1'b0;
        end else begin
            bit_index <= bit_index + 1'b1;
            frame <= {1'b1, frame[9:1]};
            tx <= frame[1]; ticks <= DIV-1;
        end
    end
endmodule
`default_nettype wire
