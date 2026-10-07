`default_nettype none
// MPU6050 (ID 0x68) and MPU6500-compatible (ID 0x70), at I2C address 0x68/0x69.
// Wake, configure, read back settings and atomically read 14-byte samples.
// No MPR121 access. Failed transactions never publish partial or stale data as valid.
module mpu6050_reader #(
    parameter integer CLK_HZ=27000000, BUS_HZ=10000, TIMEOUT_CYCLES=270000,
    parameter integer BOOT_CYCLES=2700000, RETRY_CYCLES=27000000, POLL_CYCLES=540000
)(
    input wire clk,rst, inout wire scl,sda,
    output reg online,output reg sample_valid,output reg [2:0] status,
    output reg [6:0] address,output reg [7:0] whoami,
    output reg [31:0] samples,output reg [15:0] errors,
    output reg signed [15:0] ax,ay,az,temperature,gx,gy,gz
);
    localparam BOOT=0,ID_GO=1,ID_WAIT=2,CFG_GO=3,CFG_WAIT=4,SETTLE=5,
        VERIFY_GO=6,VERIFY_WAIT=7,DATA_GO=8,DATA_WAIT=9,INTERVAL=10,RETRY=11;
    reg [3:0] state;
    reg [31:0] timer;
    reg [2:0] config_index;
    reg verify_index;
    reg start,write;
    reg [7:0] reg_address,write_data;
    reg [4:0] read_count;
    wire busy,done;
    wire [1:0] result;
    wire [127:0] read_data;
    i2c_reg_xfer #(.CLK_HZ(CLK_HZ),.BUS_HZ(BUS_HZ),.TIMEOUT_CYCLES(TIMEOUT_CYCLES)) bus(
        .clk(clk),.rst(rst),.start(start),.address(address),.reg_address(reg_address),
        .write(write),.write_data(write_data),.read_count(read_count),.scl(scl),.sda(sda),
        .busy(busy),.done(done),.result(result),.read_data(read_data));
    always @(posedge clk) begin
        if(rst) begin
            state<=BOOT;timer<=BOOT_CYCLES;config_index<=0;verify_index<=0;
            start<=0;write<=0;reg_address<=0;write_data<=0;read_count<=1;
            online<=0;sample_valid<=0;status<=5;address<=7'h68;whoami<=0;samples<=0;errors<=0;
            ax<=0;ay<=0;az<=0;temperature<=0;gx<=0;gy<=0;gz<=0;
        end else begin
            start<=0;sample_valid<=0;
            if(done && result!=0) begin
                online<=0;status<={1'b0,result};errors<=errors+1'b1;
                if(state==ID_WAIT && address==7'h68) begin address<=7'h69;state<=ID_GO;end
                else begin timer<=RETRY_CYCLES;state<=RETRY;end
            end else case(state)
                BOOT: if(timer==0) state<=ID_GO;else timer<=timer-1'b1;
                ID_GO: begin write<=0;reg_address<=8'h75;read_count<=1;start<=1;state<=ID_WAIT;end
                ID_WAIT: if(done) begin
                    whoami<=read_data[7:0];
                    if(read_data[7:0]==8'h68 || read_data[7:0]==8'h70) begin config_index<=0;status<=5;state<=CFG_GO;end
                    else begin
                        status<=3;errors<=errors+1'b1;
                        if(address==7'h68) begin address<=7'h69;state<=ID_GO;end
                        else begin timer<=RETRY_CYCLES;state<=RETRY;end
                    end
                end
                CFG_GO: begin
                    write<=1;start<=1;state<=CFG_WAIT;
                    case(config_index)
                        0:begin reg_address<=8'h6b;write_data<=8'h01;end
                        1:begin reg_address<=8'h6c;write_data<=8'h00;end
                        2:begin reg_address<=8'h1a;write_data<=8'h03;end
                        3:begin reg_address<=8'h19;write_data<=8'h13;end // 50 Hz with DLPF enabled
                        4:begin reg_address<=8'h1b;write_data<=8'h00;end // +/-250 degrees/s
                        5:begin reg_address<=8'h1c;write_data<=8'h00;end // +/-2g
                        6:begin reg_address<=8'h1d;write_data<=8'h03;end // MPU6500 accelerometer DLPF
                        default:begin reg_address<=8'h6b;write_data<=8'h01;end
                    endcase
                end
                CFG_WAIT: if(done) begin
                    if(config_index==(whoami==8'h70 ? 6:5)) begin timer<=BOOT_CYCLES;state<=SETTLE;end
                    else begin config_index<=config_index+1'b1;state<=CFG_GO;end
                end
                SETTLE: if(timer==0) begin verify_index<=0;state<=VERIFY_GO;end else timer<=timer-1'b1;
                VERIFY_GO: begin
                    write<=0;reg_address<=verify_index ? 8'h6b:8'h19;
                    read_count<=verify_index ? 5'd2:(whoami==8'h70 ? 5'd5:5'd4);start<=1;state<=VERIFY_WAIT;
                end
                VERIFY_WAIT: if(done) begin
                    if((!verify_index && ((whoami==8'h70 && read_data[39:0]!=40'h1303000003) ||
                                          (whoami==8'h68 && read_data[31:0]!=32'h13030000))) ||
                       (verify_index && read_data[15:0]!=16'h0100)) begin
                        online<=0;status<=4;errors<=errors+1'b1;timer<=RETRY_CYCLES;state<=RETRY;
                    end else if(!verify_index) begin verify_index<=1;state<=VERIFY_GO;end
                    else state<=DATA_GO;
                end
                DATA_GO: begin write<=0;reg_address<=8'h3b;read_count<=14;start<=1;state<=DATA_WAIT;end
                DATA_WAIT: if(done) begin
                    ax<=read_data[111:96];ay<=read_data[95:80];az<=read_data[79:64];
                    temperature<=read_data[63:48];gx<=read_data[47:32];gy<=read_data[31:16];gz<=read_data[15:0];
                    online<=1;status<=0;sample_valid<=1;samples<=samples+1'b1;
                    timer<=POLL_CYCLES;state<=INTERVAL;
                end
                INTERVAL: if(timer==0) state<=DATA_GO;else timer<=timer-1'b1;
                RETRY: if(timer==0) begin address<=7'h68;state<=ID_GO;end else timer<=timer-1'b1;
                default:begin online<=0;timer<=RETRY_CYCLES;state<=RETRY;end
            endcase
        end
    end
endmodule
`default_nettype wire
