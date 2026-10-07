`default_nettype none
module video_clocks(input wire clk27,output wire clk126,clk25,locked);
    // 27 / (2+1) * (13+1) = 126 MHz; /5 = 25.2 MHz.
    rPLL #(.FCLKIN("27"),.IDIV_SEL(2),.FBDIV_SEL(13),.ODIV_SEL(8),
           .DEVICE("GW2AR-18C")) u_pll(
        .CLKIN(clk27),.CLKFB(1'b0),.RESET(1'b0),.RESET_P(1'b0),
        .FBDSEL(6'b0),.IDSEL(6'b0),.ODSEL(6'b0),
        .DUTYDA(4'b1000),.PSDA(4'b0),.FDLY(4'b0),
        .CLKOUT(clk126),.CLKOUTP(),.CLKOUTD(),.CLKOUTD3(),.LOCK(locked));
    CLKDIV #(.DIV_MODE("5"),.GSREN("false")) u_clkdiv(
        .HCLKIN(clk126),.RESETN(locked),.CALIB(1'b1),.CLKOUT(clk25));
endmodule
`default_nettype wire
