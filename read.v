`include "fifo.v"
module read(source_address,destination_address,length,trigger,reset,clk,araddr,arvalid,arready,rdata,rvalid,rready,done,awaddr,awvalid,awready,wdata,wvalid,wready,bvalid,bready,w_done);
  input trigger,reset,clk;
  input [3:0] length;
  input[31:0] source_address,destination_address;

  output reg[31:0] araddr;
  output reg arvalid;
  input arready;

  input [31:0] rdata;
  input rvalid;
  output reg rready;

  output reg done;

  output reg[31:0] awaddr;
  output reg awvalid;
  input awready;

  output reg[31:0] wdata;
  output reg wvalid;
  input wready;

  input bvalid;
  output reg bready;

  output reg w_done;
  
  parameter idle=3'd0,send_addr=3'd1,capture_data=3'd2,update_addr=3'd3,complete_read=3'd4;
  reg[2:0] state,count,rem_count;
  reg[1:0] offset;
  reg[3:0] bytes;
  reg[31:0] sa,data,shifted,rem_data;
  reg first_read,wr_en;

  always @(*)
  begin shifted = rdata >> (8 * offset); end
  
  always @(posedge clk)
  begin
  if(reset)
  begin
    arvalid <= 1'b0;
    rready <= 1'b0;
    state <= idle;
    bytes <= 4'b0;
    done <= 1'b0;
    first_read <= 1'b1;
  end
  else
  begin
  case(state)
  idle: begin
            if (trigger) 
            begin
              sa <= {source_address[31:2],2'b0};
              bytes <= length;
              state <= send_addr;
              first_read <= 1'b1;
              offset <= source_address[1:0];
              done <= 1'b0;
            end
            else
            state <= idle;
        end
  send_addr : begin
              arvalid <= 1'b1;
              araddr <= sa;
              state <= capture_data;
              rready <= 1'b1;
              end
   capture_data : begin
                  if(arready & arvalid)
                  begin
                  arvalid <= 1'b0;
                  end
                  if(rready & rvalid)
                  begin
                    rready <= 1'b0;
                    state <= update_addr;
                    if(first_read)
                    begin 
                      count <= 3'd4 - offset;
                      case(offset)
                       0 : rem_data <= rdata;
                       1 : rem_data <= {rdata[31:8],8'b0};
                       2 : rem_data <= {rdata[31:16],16'b0};
                       3 : rem_data <= {rdata[31:24],24'b0};
                      endcase
                      if(bytes < 4)
                      begin
                      case (bytes)
                       0: begin wr_en <= 0; done <= 1; data <= 32'h0; end
                       1: begin data <= {24'h0,shifted[7:0]}; wr_en <= 1; bytes <= 0; end
                       2: begin data <= {16'h0,shifted[15:0]}; wr_en <= 1; bytes <= 0; end
                       3: begin data <= {8'h0,shifted[23:0]}; wr_en <= 1; bytes <= 0; end
                       default: begin wr_en <= 0; done <= 0; end
                      endcase
                      end
                      first_read <= 1'b0;
                    end
                  else
                    begin
                    if(bytes >= 4)
                    begin
                      case(count)
                       1 : begin 
                        data <= {rdata[23:0],rem_data[31:24]}; 
                        rem_data <= {rdata[31:24],24'h0}; 
                        wr_en <= 1'b1;
                        count <= count;
                        bytes <= bytes - 4'd4;
                        end
                      2 : begin 
                        data <= {rdata[15:0],rem_data[31:16]}; 
                        rem_data <= {rdata[31:16],16'h0}; 
                        wr_en <= 1'b1;
                        count <= count;
                        bytes <= bytes - 4'd4;
                        end
                      3 : begin 
                        data <= {rdata[7:0],rem_data[31:8]}; 
                        rem_data <= {rdata[31:8],8'h0};
                        wr_en <= 1'b1;
                        count <= count;
                        bytes <= bytes - 4'd4;
                        end
                      4 : begin
                        data <= rem_data;
                        rem_data <= rdata;
                        wr_en <= 1'b1;
                        count <= count;
                        bytes <= bytes - 4'd4;
                        end
                      default : begin
                         wr_en <= 1'b0;
                         end
                      endcase
                    end
                    else
                    begin
                    case(bytes)
                      0 : begin wr_en <= 1'b0; done <= 1'b1; end
                      1 : begin wr_en <= 1'b1; 
                                bytes <= 4'd0;
                                case(count)
                                  1 : data <= {24'b0,rem_data[31:24]};
                                  2 : data <= {24'b0,rem_data[23:16]};
                                  3 : data <= {24'b0,rem_data[15:8]};
                                  4 : data <= {24'b0,rem_data[7:0]};
                                endcase
                          end
                      2 : begin
                            wr_en <= 1'b1;
                            bytes <= 4'd0;
                            case(count)
                              1 : data <= {16'b0,rdata[7:0],rem_data[31:24]};
                              2 : data <= {16'b0,rem_data[31:16]};
                              3 : data <= {16'b0,rem_data[23:8]};
                              4 : data <= {16'b0,rem_data[15:0]}; 
                            endcase
                          end
                      3 : begin
                              wr_en <= 1'b1;
                              bytes <= 4'd0;
                              case(count)
                                1 : data <= {8'b0,rdata[15:0],rem_data[31:24]};
                                2 : data <= {8'b0,rdata[7:0],rem_data[31:16]};//
                                3 : data <= {8'b0,rem_data[31:8]};
                                4 : data <= {8'b0,rem_data[23:0]};
                              endcase
                          end
                    endcase
                    end
                  end
                end
              end
   update_addr :  begin
                  wr_en <= 1'b0;//Very important
                  if(bytes!=0)
                  begin
                  sa <= sa + 4;
                  state <= send_addr;
                  end
                  else
                  begin
                  state <= complete_read;
                  end
                  end
   complete_read : begin done <= 1'b1; state <= complete_read; end
   default : state <= idle;
  endcase
  end
  end
  
  wire[31:0] data_out;
  reg rd_en;
  wire empty,full;
  fifo dut(clk,reset,data,wr_en,rd_en,data_out,empty,full);
  
  reg[3:0] w_state;
  reg[3:0] words;
  reg[31:0] da;
  parameter w_idle = 4'd5,w_send_addr = 4'd6,w_send_data = 4'd7,w_updata_addr=4'd8,w_complete=4'd9;
  
  always@(posedge clk)
  begin
  if(reset)
    begin
      w_state <= w_idle;
      wvalid <= 1'b0;
      awvalid <= 1'b0;
      bready <= 1'b0;
      words <= 5'b0;
    end
  else
    begin
    case(w_state)
    w_idle : begin
               if(~empty)
               begin
               words <= (length + 4'd3) >> 2;
               w_state <= w_send_addr;
               da <= destination_address;
               end
               else
               w_state <= w_idle;
               end
    w_send_addr : begin
                    if(words == 0)
                    w_state <= w_complete;
                    else
                    begin
                    awaddr <= da;
                    awvalid <= 1'b1;
                    w_state <= w_send_data;
                    rd_en <= 1'b1;
                    end
                    end
    w_send_data : begin
                    // if(words != 0)
                    // state <= w_complete;
                    rd_en <= 1'b0;
                    if(awvalid & awready)
                      begin 
                         awvalid <= 1'b0;
                      end
                    wdata <= data_out;
                    wvalid <= 1'b1;
                    if(wvalid & wready)
                    begin
                    wvalid <= 1'b0;
                    bready <= 1'b1;
                    w_state <= w_updata_addr;
                    end
                  end
    w_updata_addr : begin
                    if(bvalid)
                    begin
                    bready <= 1'b0;
                    words <= words - 1;
                    if(words != 0)
                    begin
                    da <= da + 4;
                    w_state <= w_send_addr;
                    end
                    else
                    w_state <= w_complete;
                    end
                    end
    w_complete : begin
                w_done <= (words != 0) ? 1'b0 : 1'b1;
                w_state <= w_complete;
                end
      endcase
    end

end

endmodule