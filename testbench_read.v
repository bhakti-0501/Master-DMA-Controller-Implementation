`timescale 1ns/1ns
`include "read.v"

module tb;

  // Clock and Reset
  reg clk, reset, trigger;

  // Control signals
  reg [3:0] length;
  reg [31:0] source_address,destination_address;
  wire [31:0] araddr;
  wire arvalid;

  // AXI Read Signals
  reg arready, rvalid;
  reg [31:0] rdata;
  wire rready;
  wire done;
  
  wire[31:0] awaddr,wdata;
  wire awvalid,wvalid,bready,w_done;
  reg awready,wready,bvalid;
  
  // Clock Generation
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // Memory
  reg [31:0] mem [0:255];
  reg [31:0] read_address,write_address;
  localparam BASE_ADDR = 32'h1000;
  // AXI Read Task
  task axi_read;
    begin
      arready = 1'b1;
      wait(arvalid && arready);
      read_address = araddr;
      $display("[TB] ARADDR received: 0x%h", read_address);
      #10;
      arready = 1'b0;

      rdata = mem[(read_address - BASE_ADDR) >> 2];  // word-aligned
      rvalid = 1'b1;
      wait(rready && rvalid);
      #10;
      rvalid = 1'b0;
      $display("[TB] RDATA sent: 0x%h", rdata);
    end
  endtask

  task axi_write;
    begin
    awready = 1'b1;
    wready = 1'b1;
    fork
    begin
        wait(awvalid && awready);
      	write_address = (awaddr - BASE_ADDR) >> 2;
        #20;
        awready = 1'b0;
    end
    begin
      	wait(wvalid && wready);
      	#20
        mem[write_address] = wdata;
        $display("writing in memory ");
        #40;
        wready = 1'b0;
    end
    join

    bvalid = 1'b1;
    wait(bvalid && bready);
    // bresp = 1;
    #20;
    bvalid = 1'b0;
    // bresp = 0;
	#20;
  end
endtask

  // Run read transactions when triggered
  always @(posedge trigger) begin
    #50;
    repeat (length) axi_read();
  end

  always @(posedge trigger)
  begin
    #1000
    repeat((length + 4'd3) >> 2)
    begin
        axi_write();
    end
  end

  // Simulation Timeout
  initial begin
    #5000;
    $finish;
  end

  // Stimulus
  initial begin
    $dumpfile("see.vcd");
    $dumpvars(0, tb);

    reset = 1'b1;
    trigger = 1'b1;
    length = 4'd13;
    source_address = 32'h00001003;
    destination_address = 32'h00002000;
    // Initialize memory at 0x1000 (little-endian)
    mem[(32'h1000 - BASE_ADDR) >> 2] = 32'h11223344; // mem[0]
    mem[(32'h1004 - BASE_ADDR) >> 2] = 32'hAABBCCDD; // mem[1]
    mem[(32'h1008 - BASE_ADDR) >> 2] = 32'h55667788; // mem[2]
    mem[(32'h100C - BASE_ADDR) >> 2] = 32'hFFEEDDCC; // mem[3

    #20 reset = 1'b0;
    #50 reset = 1'b1;

    // Trigger read
    @(posedge clk) trigger = 1'b1;
    @(posedge clk) trigger = 1'b0;
    
    wait(w_done);
    $display("[TB] DONE asserted. Test Passed.");
    $finish;
    
  end

  read dut(source_address,destination_address,length,trigger,~reset,clk,araddr,arvalid,arready,rdata,rvalid,rready,done,awaddr,awvalid,awready,wdata,wvalid,wready,bvalid,bready,w_done);
endmodule
