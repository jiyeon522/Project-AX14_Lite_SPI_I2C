
`timescale 1 ns / 1 ps

	module I2C_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 5
	)
	(
		// Users to add ports here
		output wire SCL,
		inout wire SDA,
		// output wire [15:0] LED,
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
	wire [7:0] tx_data, rx_data;
   wire tx_done, rx_done, ready, start, i2c_en, stop;
// Instantiation of Axi Bus Interface S00_AXI
	I2C_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) I2C_v1_0_S00_AXI_inst (
	    .tx_data(tx_data),
        .tx_done(tx_done),
        .rx_data(rx_data),
        .rx_done(rx_done),
        .ready(ready),
        .start(start),
        .i2c_en(i2c_en),
        .stop(stop),
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
   I2C_Master U_I2C_Master(
      .clk(s00_axi_aclk),
      .reset(s00_axi_aresetn),
      .tx_data(tx_data),
      .rx_data(rx_data),
      .tx_done(tx_done),
      .rx_done(rx_done),
      .ready(ready),
      .start(start),
      .i2c_en(i2c_en),
      .stop(stop),
      .SCL(SCL),
      .SDA(SDA)
      //.LED(LED)
   );
	// User logic ends

	endmodule
    
module I2C_Master (
    input             clk,
    input             reset,
    input      [ 7:0] tx_data,
    output     [ 7:0] rx_data,
    output            rx_done,
    output            tx_done,      //곧 ACK 같은 역할?
    output reg        ready,
    input             start,
    input             i2c_en,
    input             stop,
    output            SCL,
    //output     [15:0] LED,
    inout             SDA
);

    parameter IDLE=0, START1=1, START2=2, HOLD=3, READ=4, READ_HOLD=5, WRITE=6, WRITE_ACK=7, READ_ACK=8, READ_NACK=9, STOP1=10, STOP2=11;
    parameter FCOUNT = 500;
    reg [3:0] state, state_next;
    reg tx_done_reg, tx_done_next;
    reg rx_done_reg, rx_done_next;
    reg [$clog2(FCOUNT)-1:0] sclk_counter_reg, sclk_counter_next;
    reg [7:0] temp_tx_data_reg, temp_tx_data_next;
    reg [7:0] temp_rx_data_reg, temp_rx_data_next;
    reg [3:0] bit_counter_reg, bit_counter_next;
    reg [15:0] led_reg, led_next;
    reg read, read_next;
    reg write_ack_reg, write_ack_next;
    reg [2:0] slv_count_reg, slv_count_next;

    //SCL//
    reg tick_sample;
    reg scl_en;
    reg internal_scl;
    reg gen_scl;
    reg sclk_sync0, sclk_sync1;
    wire sclk_rising = sclk_sync0 & ~sclk_sync1;
    wire sclk_falling = ~sclk_sync0 & sclk_sync1;
    
    //SDA//
    reg  sda_en;
    reg  o_data;


    assign SCL = scl_en ? gen_scl : internal_scl;
    assign SDA = sda_en ? o_data : 1'bz;
    //assign LED = led_reg;
    assign rx_data = temp_rx_data_reg;
    assign tx_done = tx_done_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            sclk_counter_reg <= 0;
            temp_tx_data_reg <= 8'b1111_1111;
            bit_counter_reg <= 0;
            led_reg <= 0;
            tx_done_reg <= 0;
            temp_rx_data_reg <= 0;
            read <= 0;
            write_ack_reg <=1'bz;
            rx_done_reg <=0;
        end else begin
            state <= state_next;
            sclk_counter_reg <= sclk_counter_next;
            temp_tx_data_reg <= temp_tx_data_next;
            bit_counter_reg <= bit_counter_next;
            led_reg <= led_next;
            tx_done_reg <= tx_done_next;
            temp_rx_data_reg <= temp_rx_data_next;
            read <= read_next;
            write_ack_reg <= write_ack_next;
            rx_done_reg <= rx_done_next;
        end
    end

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            sclk_sync0 <= 1;
            sclk_sync1 <= 1;
            slv_count_reg <=0;
        end else begin
            sclk_sync0 <= SCL;
            sclk_sync1 <= sclk_sync0;
            slv_count_reg <= slv_count_next;
        end
    end

    always @(*) begin
        state_next = state;
        sclk_counter_next = sclk_counter_reg;
        temp_tx_data_next = temp_tx_data_reg;
        temp_rx_data_next = temp_rx_data_reg;
        bit_counter_next = bit_counter_reg;
        tx_done_next = tx_done_reg;
        rx_done_next = 0;
        ready = 0;
        slv_count_next  = slv_count_reg;
        write_ack_next = write_ack_reg;
        //SCL//

        internal_scl = 1'b1;
        scl_en = 1'b0;

        //SDA//

        sda_en = 1'b1;
        o_data = 1'b1;

        led_next = 0;
        read_next = read;
        case (state)
            IDLE: begin
                o_data = 1'b1;
                ready = 1;
                led_next = 16'b0000_0000_0000_0001;
                if (start && i2c_en) begin
                    state_next = START1;
                    sclk_counter_next = 0;
                    temp_tx_data_next = tx_data;
                    bit_counter_next = 0;
                    slv_count_next =0;
                end
            end
            START1: begin
                o_data = 1'b0;
                led_next = 16'b0000_0000_0000_0010;
                if (sclk_counter_reg == FCOUNT - 1) begin
                    state_next = START2;
                    sclk_counter_next = 0;
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
            START2: begin
                o_data = 1'b0;
                internal_scl = 1'b0;
                led_next = 16'b0000_0000_0000_0100;
                if (sclk_counter_reg == FCOUNT - 1) begin
                    sclk_counter_next = 0;
                    state_next = HOLD;
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
            HOLD: begin
                state_next = HOLD;
                internal_scl = 1'b0;
                o_data = 1'b0;
                ready = 1;
                led_next = 16'b0000_0000_0000_1000;
                write_ack_next = 1'bz;

                if (i2c_en) begin
                    case ({
                        start, stop
                    })
                        2'b00: begin
                            state_next = WRITE;
                            tx_done_next = 0;
                            read_next = 0;
                            temp_tx_data_next = tx_data;
                            scl_en = 1'b1;
                        end
                        //2'b10: state_next = START1;

                        2'b01: begin
                            state_next   = STOP1;
                            tx_done_next = 0;
                        end
                        2'b11: begin
                            scl_en = 1'b1;
                            sda_en = 1'b0;
                            read_next = 1;
                            state_next = READ;
                            tx_done_next = 0;
                        end
                        default: state_next = HOLD;
                    endcase
                end
            end
            READ: begin
                scl_en = 1'b1;
                sda_en = 1'b0;
                led_next = 16'b0000_0000_0001_0000;
                rx_done_next=0;
                if (sclk_rising) begin
                    temp_rx_data_next = {temp_rx_data_reg[6:0], SDA};
                end
                if (tick_sample) begin
                    if(bit_counter_reg ==8-1) begin
                        state_next = READ_HOLD;
                        bit_counter_next =0;
                        slv_count_next = slv_count_reg +1;
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                    end
                end
            end

            READ_HOLD: begin
                scl_en=1;
                led_next = 16'b0000_0000_0010_0000;
                ready=1;
                rx_done_next = 1;
                if(slv_count_reg == 4) begin
                    state_next = READ_NACK;
                end else begin
                    state_next =READ_ACK;
                end
            end
            WRITE: begin
                o_data = temp_tx_data_reg[7];
                scl_en = 1'b1;
                led_next = 16'b0000_0000_0100_0000;
                if (tick_sample) begin
                    temp_tx_data_next = {temp_tx_data_reg[6:0], 1'b0};
                    if (bit_counter_reg == 8 - 1) begin
                        bit_counter_next = 0;
                        state_next = WRITE_ACK;
                        tx_done_next =1'b1;
                    end else begin
                        bit_counter_next = bit_counter_reg + 1;
                    end
                end
            end
    
            WRITE_ACK: begin
                scl_en = 1'b1;
                sda_en = 1'b0;
                led_next = 16'b0000_0000_1000_0000;
                if (sclk_rising) begin
                    write_ack_next = SDA;
                end
                if(tick_sample) begin
                    if(write_ack_reg == 1'b0)
                        state_next = HOLD;
                end
            end

            READ_ACK: begin
                scl_en = 1'b1;
                o_data = 1'b0;
                led_next = 16'b0000_0001_0000_0000;
                if (tick_sample) begin
                    state_next = READ;
                end
            end
            READ_NACK: begin
                scl_en = 1'b1;
                o_data = 1'b1;
                led_next = 16'b0000_0010_0000_0000;
                if (tick_sample) begin
                    state_next = HOLD;
                    slv_count_next = 0;
                end
            end
            STOP1: begin
                o_data = 1'b0;
                internal_scl = 1'b1;
                ready = 0;
                tx_done_next = 0;
                led_next = 16'b0000_0100_0000_0000;

                if (sclk_counter_next == FCOUNT - 1) begin
                    state_next = STOP2;
                    sclk_counter_next = 0;
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
            STOP2: begin
                o_data = 1'b1;
                internal_scl = 1'b1;
                ready = 0;
                tx_done_next = 0;
                led_next = 16'b0000_1000_0000_0000;

                if (sclk_counter_next == FCOUNT - 1) begin
                    state_next = IDLE;
                    sclk_counter_next = 0;
                end else begin
                    sclk_counter_next = sclk_counter_reg + 1;
                end
            end
        endcase
    end

    parameter CLK3 = 1000, CLK0= 250, CLK1=500, CLK2=750;

    reg [$clog2(CLK3)-1:0] counter_reg, counter_next;
    

    always @(posedge clk or negedge reset) begin
        if(!reset) begin
            counter_reg <=0;
            gen_scl <=0;
            tick_sample <=1;
        end else begin
            counter_reg <= counter_next;
            if(scl_en) begin
                if(counter_reg >= 0 && counter_reg < CLK0-1) begin
                    counter_reg <= counter_reg +1;
                    gen_scl <=0;
                    tick_sample <=0;
                end else if(counter_reg >= CLK0-1 && counter_reg < CLK1-1) begin
                    counter_reg <= counter_reg +1;
                    gen_scl <=1;
                    tick_sample <=0;
                end else if(counter_reg >= CLK1-1 && counter_reg < CLK2-1) begin
                    counter_reg <= counter_reg +1;
                    gen_scl <=1;
                    tick_sample <=0;
                end else if (counter_reg >= CLK2-1 && counter_reg < CLK3-1-1) begin
                    counter_reg <= counter_reg +1;
                    gen_scl <=0;
                    tick_sample <=0;
                end else if (counter_reg == CLK3 -1-1)begin
                    counter_reg <= counter_reg +1;
                    gen_scl <=0;
                    tick_sample <=1;
                end else if (counter_reg == CLK3-1) begin
                    counter_reg <= 0;
                    gen_scl <=0;
                    tick_sample <=0;
                end
            end else begin
                counter_reg <= 0;
                gen_scl <=0;
                tick_sample <=1;
            end
        end
    end

endmodule