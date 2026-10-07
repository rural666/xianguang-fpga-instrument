`default_nettype none
module video_hdmi_tx(
    input wire pix_clk,serial_clk,reset,de,hs,vs,
    input wire [23:0] rgb,
    output wire tmds_clk_p,tmds_clk_n,
    output wire [2:0] tmds_data_p,tmds_data_n
);
    wire [9:0] blue,green,red;
    wire [3:0] bitstream;
    tmds_encoder u_blue(.clk(pix_clk),.reset(reset),.de(de),.data(rgb[7:0]),.control({vs,hs}),.symbol(blue));
    tmds_encoder u_green(.clk(pix_clk),.reset(reset),.de(de),.data(rgb[15:8]),.control(2'b00),.symbol(green));
    tmds_encoder u_red(.clk(pix_clk),.reset(reset),.de(de),.data(rgb[23:16]),.control(2'b00),.symbol(red));
    wire [9:0] clock_pattern=10'b1111100000;
    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1)begin:SERIAL
        wire [9:0] word10;
        if(lane==0)assign word10=blue;
        else if(lane==1)assign word10=green;
        else if(lane==2)assign word10=red;
        else assign word10=clock_pattern;
        OSER10 #(.GSREN("false"),.LSREN("true")) u_oser(
            .Q(bitstream[lane]),.PCLK(pix_clk),.FCLK(serial_clk),.RESET(reset),
            .D0(word10[0]),.D1(word10[1]),.D2(word10[2]),.D3(word10[3]),
            .D4(word10[4]),.D5(word10[5]),.D6(word10[6]),.D7(word10[7]),
            .D8(word10[8]),.D9(word10[9]));
    end endgenerate
    TLVDS_OBUF u_b(.I(bitstream[0]),.O(tmds_data_p[0]),.OB(tmds_data_n[0]));
    TLVDS_OBUF u_g(.I(bitstream[1]),.O(tmds_data_p[1]),.OB(tmds_data_n[1]));
    TLVDS_OBUF u_r(.I(bitstream[2]),.O(tmds_data_p[2]),.OB(tmds_data_n[2]));
    TLVDS_OBUF u_c(.I(bitstream[3]),.O(tmds_clk_p),.OB(tmds_clk_n));
endmodule
`default_nettype wire
