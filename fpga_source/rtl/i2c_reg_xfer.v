`default_nettype none
// One-byte register write or 1..16 byte repeated-START register read.
// Open-drain outputs, clock stretching and a bounded timeout. Result is valid at done.
// Burst bytes accumulate in the low bytes of read_data, first byte most significant.
module i2c_reg_xfer #(
    parameter integer CLK_HZ = 27000000,
    parameter integer BUS_HZ = 100000,
    parameter integer TIMEOUT_CYCLES = 270000
)(
    input wire clk, input wire rst, input wire start,
    input wire [6:0] address, input wire [7:0] reg_address,
    input wire write, input wire [7:0] write_data, input wire [4:0] read_count,
    inout wire scl, inout wire sda,
    output reg busy, output reg done,
    output reg [1:0] result, // 0=OK, 1=NACK, 2=bus busy/stretch timeout
    output reg [127:0] read_data
);
    localparam integer Q = (CLK_HZ + 4*BUS_HZ-1)/(4*BUS_HZ);
    localparam IDLE=0, BUS_FREE=1, START_HOLD=2,
        TX_SETUP=3, TX_RISE=4, TX_HIGH=5, TX_FALL=6,
        ACK_SETUP=7, ACK_RISE=8, ACK_HIGH=9, ACK_FALL=10,
        RESTART_SETUP=11, RESTART_RISE=12, RESTART_HIGH=13,
        RX_SETUP=14, RX_RISE=15, RX_HIGH=16, RX_FALL=17,
        NACK_SETUP=18, NACK_RISE=19, NACK_HIGH=20,
        STOP_SETUP=21, STOP_RISE=22, STOP_HIGH=23, STOP_FREE=24,
        CLEAR_LOW=25,CLEAR_RISE=26,CLEAR_HIGH=27;
    reg [4:0] state;
    reg scl_low, sda_low;
    reg scl_meta, scl_sync, sda_meta, sda_sync;
    reg [15:0] delay_count;
    reg [31:0] timeout_count;
    reg [7:0] tx_shift, reg_latched;
    reg [6:0] address_latched;
    reg [2:0] bit_index;
    reg [1:0] phase;
    reg ack_n, write_latched;
    reg [7:0] data, write_latched_data;
    reg [4:0] length_latched, byte_index;
    reg [3:0] clear_clocks;
    reg clear_attempted;
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    always @(posedge clk) begin
        if (rst) begin
            scl_meta<=1; scl_sync<=1; sda_meta<=1; sda_sync<=1;
        end else begin
            scl_meta<=scl; scl_sync<=scl_meta;
            sda_meta<=sda; sda_sync<=sda_meta;
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; scl_low<=0; sda_low<=0;
            busy<=0; done<=0; result<=0; data<=0; read_data<=0;
            write_latched<=0; write_latched_data<=0; length_latched<=1; byte_index<=0;
            clear_clocks<=0;clear_attempted<=0;
            delay_count<=0; timeout_count<=0;
            tx_shift<=0; reg_latched<=0; address_latched<=0;
            bit_index<=0; phase<=0; ack_n<=1;
        end else begin
            done<=0;
            if (busy && timeout_count == TIMEOUT_CYCLES-1) begin
                state<=IDLE; busy<=0; done<=1; result<=2;
                scl_low<=0; sda_low<=0; timeout_count<=0;
            end else if (delay_count != 0) begin
                delay_count<=delay_count-1'b1;
            end else begin
                case (state)
                    IDLE: if (start) begin
                        address_latched<=address; reg_latched<=reg_address;
                        write_latched<=write; write_latched_data<=write_data;
                        length_latched<=read_count==0 ? 5'd1 : (read_count>16 ? 5'd16 : read_count);
                        byte_index<=0; read_data<=0;
                        clear_clocks<=0;clear_attempted<=0;
                        tx_shift<={address,1'b0}; bit_index<=7; phase<=0;
                        busy<=1; result<=0; data<=0; timeout_count<=0;
                        scl_low<=0; sda_low<=0; delay_count<=Q-1; state<=BUS_FREE;
                    end
                    BUS_FREE: if (scl_sync && sda_sync) begin
                        timeout_count<=0; sda_low<=1; delay_count<=2*Q-1; state<=START_HOLD;
                    end else if(scl_sync && !sda_sync && !clear_attempted) begin
                        // FPGA SRAM reload can interrupt a slave mid-byte. Nine open-drain
                        // clocks plus STOP release a slave waiting for the rest of that byte.
                        clear_attempted<=1;clear_clocks<=0;timeout_count<=0;state<=CLEAR_LOW;
                    end else timeout_count<=timeout_count+1'b1;
                    CLEAR_LOW: begin
                        scl_low<=1;sda_low<=0;delay_count<=2*Q-1;state<=CLEAR_RISE;
                    end
                    CLEAR_RISE: begin
                        scl_low<=0;
                        if(scl_sync)begin timeout_count<=0;delay_count<=2*Q-1;state<=CLEAR_HIGH;end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    CLEAR_HIGH: begin
                        scl_low<=1;
                        if(clear_clocks==8)begin result<=2;state<=STOP_SETUP;end
                        else begin clear_clocks<=clear_clocks+1'b1;state<=CLEAR_LOW;end
                    end
                    START_HOLD: begin scl_low<=1; state<=TX_SETUP; end
                    TX_SETUP: begin
                        sda_low<=!tx_shift[bit_index]; delay_count<=2*Q-1; state<=TX_RISE;
                    end
                    TX_RISE: begin
                        scl_low<=0;
                        if (scl_sync) begin timeout_count<=0; delay_count<=2*Q-1; state<=TX_HIGH; end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    TX_HIGH: begin scl_low<=1; state<=TX_FALL; end
                    TX_FALL: if (bit_index == 0) state<=ACK_SETUP;
                             else begin bit_index<=bit_index-1'b1; state<=TX_SETUP; end
                    ACK_SETUP: begin sda_low<=0; delay_count<=2*Q-1; state<=ACK_RISE; end
                    ACK_RISE: begin
                        scl_low<=0;
                        if (scl_sync) begin timeout_count<=0; delay_count<=2*Q-1; state<=ACK_HIGH; end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    ACK_HIGH: begin ack_n<=sda_sync; scl_low<=1; state<=ACK_FALL; end
                    ACK_FALL: begin
                        if (ack_n) begin result<=1; state<=STOP_SETUP; end
                        else if (phase == 0) begin
                            phase<=1; tx_shift<=reg_latched; bit_index<=7; state<=TX_SETUP;
                        end else if (phase == 1) begin
                            if(write_latched) begin phase<=3; tx_shift<=write_latched_data; bit_index<=7; state<=TX_SETUP; end
                            else begin phase<=2; state<=RESTART_SETUP; end
                        end else if(phase==3) state<=STOP_SETUP;
                        else begin bit_index<=7; state<=RX_SETUP; end
                    end
                    RESTART_SETUP: begin sda_low<=0; delay_count<=2*Q-1; state<=RESTART_RISE; end
                    RESTART_RISE: begin
                        scl_low<=0;
                        if (scl_sync) begin timeout_count<=0; delay_count<=2*Q-1; state<=RESTART_HIGH; end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    RESTART_HIGH: begin
                        sda_low<=1; tx_shift<={address_latched,1'b1}; bit_index<=7;
                        delay_count<=2*Q-1; state<=START_HOLD;
                    end
                    RX_SETUP: begin sda_low<=0; delay_count<=2*Q-1; state<=RX_RISE; end
                    RX_RISE: begin
                        scl_low<=0;
                        if (scl_sync) begin timeout_count<=0; delay_count<=2*Q-1; state<=RX_HIGH; end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    RX_HIGH: begin data[bit_index]<=sda_sync; scl_low<=1; state<=RX_FALL; end
                    RX_FALL: if (bit_index == 0) begin read_data<={read_data[119:0],data}; state<=NACK_SETUP; end
                             else begin bit_index<=bit_index-1'b1; state<=RX_SETUP; end
                    NACK_SETUP: begin sda_low<=(byte_index+1<length_latched); delay_count<=2*Q-1; state<=NACK_RISE; end
                    NACK_RISE: begin
                        scl_low<=0;
                        if (scl_sync) begin timeout_count<=0; delay_count<=2*Q-1; state<=NACK_HIGH; end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    NACK_HIGH: begin
                        scl_low<=1;
                        if(byte_index+1<length_latched) begin byte_index<=byte_index+1'b1; bit_index<=7; state<=RX_SETUP; end
                        else state<=STOP_SETUP;
                    end
                    STOP_SETUP: begin sda_low<=1; delay_count<=2*Q-1; state<=STOP_RISE; end
                    STOP_RISE: begin
                        scl_low<=0;
                        if (scl_sync) begin timeout_count<=0; delay_count<=2*Q-1; state<=STOP_HIGH; end
                        else timeout_count<=timeout_count+1'b1;
                    end
                    STOP_HIGH: begin sda_low<=0; delay_count<=2*Q-1; state<=STOP_FREE; end
                    STOP_FREE: if (scl_sync && sda_sync) begin
                        busy<=0; done<=1; state<=IDLE;
                    end else timeout_count<=timeout_count+1'b1;
                    default: begin state<=IDLE; busy<=0; scl_low<=0; sda_low<=0; end
                endcase
            end
        end
    end
endmodule
`default_nettype wire
