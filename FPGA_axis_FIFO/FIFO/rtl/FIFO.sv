module FIFO #(
    parameter int unsigned BITWIDTH = 32,  
    parameter int unsigned ADDRESS_WIDTH = 11,
)(
      input   wire                 rst 
    , input   wire                 clr 
    , input   wire                 aclk
    // write
    , output  wire                 wr_rdy
    , input   wire                 wr_vld
    , input   wire [BITWIDTH-1:0]  wr_din
    // read
    , input   wire                 rd_rdy
    , output  wire                 rd_vld
    , output  wire [BITWIDTH-1:0] rd_dout
    // state
    , output  wire                 full
    , output  wire                 empty
    , output  wire                 fullN  // lookahead full
    , output  wire                 emptyN // lookahead empty
    , output  reg  [ADDRESS_WIDTH:0]         rd_cnt // num of elements in the FIFO to be read
    , output  wire [ADDRESS_WIDTH:0]         wr_cnt // num of rooms in the FIFO to be written
);
   //---------------------------------------------------
   localparam FDT = 1<<ADDRESS_WIDTH;
   //---------------------------------------------------
   reg  [ADDRESS_WIDTH:0]   fifo_head; // where data to be read
   reg  [ADDRESS_WIDTH:0]   fifo_tail; // where data to be written
   reg  [ADDRESS_WIDTH:0]   next_tail;
   reg  [ADDRESS_WIDTH:0]   next_head;
   wire [ADDRESS_WIDTH-1:0] read_addr = (rd_vld&rd_rdy) ? next_head[ADDRESS_WIDTH-1:0]
                                              : fifo_head[ADDRESS_WIDTH-1:0];

   //---------------------------------------------------
   // accept input
   // push data item into the entry pointed by fifo_tail
   //
   always @(posedge aclk or posedge rst) begin
      if (rst) begin
          fifo_tail <= 0;
          next_tail <= 1;
      end else if (clr) begin
          fifo_tail <= 0;
          next_tail <= 1;
      end else begin
          if (!full && wr_vld) begin
              fifo_tail <= next_tail;
              next_tail <= next_tail + 1;
          end 
      end
   end
   //---------------------------------------------------
   // provide output
   // pop data item from the entry pointed by fifo_head
   //
   always @(posedge aclk or posedge rst) begin
      if (rst) begin
          fifo_head <= 0;
          next_head <= 1;
      end else if (clr) begin
          fifo_head <= 0;
          next_head <= 1;
      end else begin
          if (!empty && rd_rdy) begin
              fifo_head <= next_head;
              next_head <= next_head + 1;
          end
      end
   end
   //---------------------------------------------------
   // how many items in the FIFO
   //
   assign  wr_cnt = FDT-rd_cnt;
   always @(posedge aclk or posedge rst) begin
      if (rst) begin
         rd_cnt <= 0;
      end else if (clr) begin
         rd_cnt <= 0;
      end else begin
         if (wr_vld&&!full&&!(rd_rdy&&!empty)) begin
             rd_cnt <= rd_cnt + 1;
         end else
         if (rd_rdy&&!empty&&!(wr_vld&&!full)) begin
             rd_cnt <= rd_cnt - 1;
         end
      end
   end
   
   //---------------------------------------------------
   assign rd_vld = ~empty;
   assign wr_rdy = ~full;
   assign empty  = (fifo_head == fifo_tail);
   assign full   = (rd_cnt>=FDT);
   //---------------------------------------------------
   assign fullN  = (rd_cnt>=(FDT-ADDRESS_WIDTH));
   assign emptyN = (rd_cnt<=ADDRESS_WIDTH);
   //---------------------------------------------------
 
   //---------------------------------------------------
   reg [BITWIDTH-1:0] Mem [0:FDT-1];
   assign rd_dout  = Mem[fifo_head[ADDRESS_WIDTH-1:0]];
   always @(posedge aclk) begin
       if (!full && wr_vld) begin
           Mem[fifo_tail[ADDRESS_WIDTH-1:0]] <= wr_din;
       end
   end
   //---------------------------------------------------
endmodule
