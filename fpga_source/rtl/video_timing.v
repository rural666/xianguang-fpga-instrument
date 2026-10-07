`default_nettype none
// VESA/CEA 640x480 at 60 Hz: 25.2 MHz pixel clock, 800 x 525 total.
module video_timing(
    input wire clk,reset,
    output wire [10:0] x,output wire [9:0] y,
    output wire active,hs,vs,frame_blank
);
    reg [10:0] h=0;
    reg [9:0] v=0;
    always @(posedge clk)begin
        if(reset)begin h<=0;v<=0;end
        else if(h==799)begin h<=0;v<=v==524?10'd0:v+1'b1;end
        else h<=h+1'b1;
    end
    // Negative sync pulse; horizontal: 96+48+640+16.
    // Vertical: 2+33+480+10.
    assign hs=!(h<96);
    assign vs=!(v<2);
    assign active=(h>=144 && h<784 && v>=35 && v<515);
    assign x=active?h-11'd144:11'd0;
    assign y=active?v-10'd35:10'd0;
    assign frame_blank=(h==0 && v==515);
endmodule
`default_nettype wire
