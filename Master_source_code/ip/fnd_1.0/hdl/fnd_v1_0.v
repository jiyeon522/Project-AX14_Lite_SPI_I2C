
`timescale 1 ns / 1 ps

	module fnd_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
		
		output wire [7:0] fndFont,
		output wire [3:0] fndCom,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	wire [7:0] DATA_DIG;
// Instantiation of Axi Bus Interface S00_AXI
	fnd_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) fnd_v1_0_S00_AXI_inst (
		.DATA_DIG(DATA_DIG),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

	// Add user logic here
		FND_C U_FND(
	    .clk(s00_axi_aclk), 
	    .reset(!s00_axi_aresetn),
	    .Digit(DATA_DIG),
	    .fndFont(fndFont),
	    .fndCom(fndCom)
	    );
	// User logic ends

	endmodule

module FND_C(
    input clk, 
    input reset,
    input  [7:0] Digit,
    output [7:0] fndFont,
    output [3:0] fndCom
    );

    fnd_controller U_FND(
    .clk(clk), 
    .reset(reset),
    .Digit(Digit),
    .seg(fndFont),
    .seg_comm(fndCom)
);
endmodule

module fnd_controller (
    input clk, 
    input reset,
    input  [7:0] Digit,
    output [7:0] seg,
    output [3:0] seg_comm
);

    wire [3:0] w_digit1, w_digit10, w_digit100, w_digit1000;
    wire [3:0] w_bcd;
    wire [1:0] w_seg_sel;
    wire w_clk_100hz;

    clock_divider_fnd U_clock_divider_fnd(
        .clk(clk),
        .rst(reset),
        .o_clk(w_clk_100hz)
    );

    counter_4 U_counter_4(
        .clk(w_clk_100hz),
        .rst(rst),
        .count(w_seg_sel)
    );

    decoder_2x4 U_decoder_2x4(
        .seg_sel(w_seg_sel),
        .seg_comm(seg_comm)
    );

    digit_splitter U_digit_splitter(
        .bcd(Digit),
        .digit_1(w_digit1),
        .digit_10(w_digit10),
        .digit_100(w_digit100),
        .digit_1000(w_digit1000)
    );

    mux_4x1 U_mux_4x1(
    .sel(w_seg_sel),
    .digit_1(w_digit1),
    .digit_10(w_digit10),
    .digit_100(w_digit100),
    .digit_1000(w_digit1000),
    .bcd(w_bcd)
);

    bcdtoseg U_bcdtoseg (
        .bcd(w_bcd),
        .seg(seg)
    );

endmodule

module clock_divider_fnd (
    input clk, rst,
    output o_clk
);
    parameter COUNT = 500_000;
    reg [$clog2(COUNT)-1:0] r_counter;
    reg r_clk;
    assign o_clk = r_clk;
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            r_counter <= 0;
            r_clk <= 0;
        end else begin
            // clock divide 계산, 100MHz -> 200hz
            if (r_counter == COUNT - 1) begin 
                r_counter <= 0;
                r_clk <= 1; // r_clk : 0->1
            end else begin
                r_counter <= r_counter + 1;
                r_clk <= 0; // r_clk : 0으로 유지
            end
        end
    end
endmodule

module counter_4 (
    input clk, rst,
    output reg [1:0] count
);
    always @(posedge clk, posedge rst) begin 
        if (rst) begin
            count <= 0;
        end else begin
            count <= count + 1; 
        end 
    end

endmodule

module decoder_2x4 (
    input [1:0] seg_sel,
    output reg [3:0] seg_comm
); 
    // 2x4 decoder
    always @(seg_sel) begin
        case (seg_sel)
            2'b00: seg_comm = 4'b1110;
            2'b01: seg_comm = 4'b1101;
            2'b10: seg_comm = 4'b1011;
            2'b11: seg_comm = 4'b0111;
            default: seg_comm = 4'b1110;
        endcase

    end

endmodule

module digit_splitter (
    input [7:0] bcd,        // Data_digit
    output [3:0] digit_1, digit_10, digit_100, digit_1000
);
    
    assign digit_1 = bcd % 10; // 1의 자리
    assign digit_10 = bcd / 10 % 10; // 10의 자리
    assign digit_100 = bcd / 100 % 10; // 100의 자리
    assign digit_1000 = bcd / 1000 % 10; // 1000의 자리

endmodule

module mux_4x1 (
    input [1:0] sel,
    input [3:0] digit_1, digit_10, digit_100, digit_1000,
    output reg [3:0] bcd
);

    always @(sel, digit_1, digit_10, digit_100, digit_1000) begin
        case (sel)
            2'b00: bcd = digit_1;
            2'b01: bcd = digit_10;
            2'b10: bcd = digit_100;
            2'b11: bcd = digit_1000;
            default: bcd = 4'bx;
        endcase
    end

endmodule

module bcdtoseg (
    input [3:0] bcd,  // [7:0] SUM 값
    output reg [7:0] seg  
);

    always @(bcd) begin
        case (bcd)
            4'b0000: seg = 8'b11000000;  // 0
            4'b0001: seg = 8'b11111001;  // 1
            4'b0010: seg = 8'b10100100;  // 2
            4'b0011: seg = 8'b10110000;  // 3
            4'b0100: seg = 8'b10011001;  // 4
            4'b0101: seg = 8'b10010010;  // 5
            4'b0110: seg = 8'b10000010;  // 6
            4'b0111: seg = 8'b11111000;  // 7
            4'b1000: seg = 8'b10000000;  // 8
            4'b1001: seg = 8'b10010000;  // 9
            4'b1010: seg = 8'b10001000;  // A
            4'b1011: seg = 8'b10000011;  // b
            4'b1100: seg = 8'b11000110;  // C
            4'b1101: seg = 8'b10100001;  // d
            4'b1110: seg = 8'b10000110;  // E
            4'b1111: seg = 8'b10001110;  // F
            default: seg = 8'b11111111;
        endcase
    end
endmodule