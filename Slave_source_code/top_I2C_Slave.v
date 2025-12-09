`timescale 1ns / 1ps

module top_i2c_slave(
    input clk,
    input reset,
    input [3:0] sw,
    input SCL,
    inout SDA,
    output [7:0] fndFont,
    output [3:0] fndCom,
    output [15:0] LED
    );

    wire [7:0] slv_reg0;
    wire [7:0] slv_reg1;
    wire [7:0] slv_reg2;
    wire [7:0] slv_reg3;

    I2C_Slave U_I2C_Slave(
    .clk(clk),
    .reset(reset),
    .SCL(SCL),
    .SDA(SDA),
    .LED(LED),
    .slv_reg0(slv_reg0),
    .slv_reg1(slv_reg1),
    .slv_reg2(slv_reg2),
    .slv_reg3(slv_reg3)
    );

    FND_C U_FND_C(
    .clk(clk), 
    .reset(reset),
    .sw(sw),
    .slv_reg0(slv_reg0),
    .slv_reg1(slv_reg1),
    .slv_reg2(slv_reg2),
    .slv_reg3(slv_reg3),
    .fndFont(fndFont),
    .fndCom(fndCom)
    );

endmodule