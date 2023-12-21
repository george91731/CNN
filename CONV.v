//Project: Convolutional Neural Networks
//Date: 2023/12/18

module CONV(
       clk,
       reset,
       busy,
       ready,
       iaddr,
       idata,
       cwr,
       caddr_wr,
       cdata_wr,
       crd,
       caddr_rd,
       cdata_rd,
       csel
);
/////////////////////////////////////////////////////////////////////////////////////////////
// port
input clk, reset;
input ready;
input signed [19:0] idata;
input [19:0] cdata_rd;
output reg busy;
output reg [11:0] iaddr;
output reg cwr;
output reg [11:0] caddr_wr;
output reg [19:0] cdata_wr;
output reg crd;
output reg [11:0] caddr_rd;
output reg [2:0] csel;

//FSM
parameter RESET  = 3'b000;
parameter INPUT  = 3'b001;
parameter CONV   = 3'b010;
parameter LAY0   = 3'b011;
parameter MAXP   = 3'b100;
parameter LAY1   = 3'b101;
parameter FLAT   = 3'b110;
parameter FINISH = 3'b111;

reg [2:0] state;
reg [2:0] n_state;


reg [2:0] img_cnt;
reg signed [19:0] image [0:8];
reg [11:0] img_addr;
// position
reg [11:0] position_X, position_Y;
wire [11:0] position;
wire [11:0] pos_0;
wire [11:0] pos_1;
wire [11:0] pos_2;
wire [11:0] pos_3;
wire [11:0] pos_4;
wire [11:0] pos_5;
wire [11:0] pos_6;
wire [11:0] pos_7;
wire [11:0] pos_8;
//
reg [3:0] img_cnt;
reg signed [19:0] kernel_0 [0:8];
reg signed [19:0] kernel_1 [0:8];
reg signed [19:0] bias_0;
reg signed [19:0] bias_1;
reg position_en;
wire switch = 0;


// Flatten
wire L2_flag;
reg [10:0] L2_cnt;

integer i;



/////////////////////////////////////////////////////////////////////////////////////////////


//busy signal
always @(posedge clk or posedge reset) begin
       if(reset) begin
              busy <= 1'd0;
       end
       else if(ready) begin
              busy <= 1'd1;
       end
       else if(state ==FINISH) begin
              busy <= 1'd0;
       end
       else begin
              busy <= 1'd0;
       end       
end


//FSM current state
always @(posedge clk or posedge reset) begin
       if(reset) begin
              state <= 1'0;
       end
       else begin
              state <= n_state;
       end      
end

//FSM next state
always@(*) begin
        case(state)
             RESET: begin
                   if(ready) n_state = INPUT;
                   else if(L2_flag) n_state = FLAT;
                   else if(L0_ready) n_state = MAXPOOL;
                   else n_state = state;
             end
             INPUT: begin
                   if(img_cnt == 9) n_state = CONV;
                   else n_state = state;
             end
             CONV: begin
                   if(img_cnt == 1) n_state = L0_W;
                   else n_state = state;
             end
             L0_W: begin
                   if(L0_ready) n_state = RESET;
                   else if(img_cnt == 2) n_state = INPUT;
                   else n_state = state;
             end 
             MAXPOOL: begin
                   if(img_cnt == 4) n_state = L1_W;
                   else n_state = state;
             end
             L1_W : begin
                   if(L1_cnt == 0 && max_done) n_state = RESET;
                   else if(img_cnt == 1) n_state = MAXPOOL;
                   else n_state = state;
             end   
             FLAT: begin
                   if(L2_cnt == 2047 && img_cnt == 3) n_state = FINISH;
                   else n_state = state;
             end   
             FINISH: begin
                   n_state = FINISH;
             end
             default: begin
                   n_state = state;
             end 
        endcase
end
// Enable update position
always @(posedge clk or posedge reset) begin
  if (reset) begin
    position_en <= 0;
  end
  else begin
    case(state)
         RESET: position_en <= 0;
         INPUT: begin
           if(img_cnt == 0) position_en <= 1;
           else position_en <= position_en;
         end
         L1_W: begin
           if(img_cnt == 0 && kernel_switch) position_en <= 1;
           else position_en <= 0;
         end
         FLAT: position_en <= 1;
         default: position_en <= 0;
    endcase
  end
end

//image counter

always @(posedge clk or posedge reset) begin
       if(reset) begin
              img_cnt <= 1'd0;
       end
       else begin
              case(state) 
                     RESET: img_cnt <= 1'd0;
                     INPUT: begin
                     if(img_cnt == 1'd9) 
                            img_cnt <= 1'd1;
                            else 
                                   img_cnt <= img_cnt + 1'd1;
                     end
                     CONV: begin
                     if(img_cnt == 1'd1)
                            img_cnt <= 1'd0;
                            else 
                                   img_cnt <= img_cnt + 1'd1;
                     end                                      
                     LAY0: begin
                     if(img_cnt == 1'd2)
                            img_cnt <= 1'd0;
                            else 
                                   img_cnt <= img_cnt + 1'd1;
                     end    
                     MAXP: begin
                     if(img_cnt == 1'd4)
                            img_cnt <= 1'd0;
                            else 
                                   img_cnt <= img_cnt + 1'd1;
                     end    
                     LAY1: begin
                     if(img_cnt == 1'd1)
                            img_cnt <= 1'd0;
                            else 
                                   img_cnt <= img_cnt + 1'd1;
                     end    
                     FLAT: begin
                     if(img_cnt == 1'd3)
                            img_cnt <= 1'd0;
                            else 
                                   img_cnt <= img_cnt + 1'd1;
                     end    
                     default: begin
                            img_cnt <= img_cnt;
                     end        
              endcase       
       end
end

//image position
always @(posedge clk or posedge reset) begin
       if(reset) begin
              position_X <= 12'd0;
              position_Y <= 12'd0;
       end
       else begin
              case(state)
                     RESET: begin
                            position_X <= 12'd0;
                            position_Y <= 12'd0;
                     end
                     INPUT: begin
                            if(img_cnt == 4'd9 && position_en == 1'd1) begin
                                   if(position_Y == 12'd63) begin
                                          position_Y <= 12'd0;
                                          if(position_X == 12'd63) position_X <= 12'd0;
                                                 else position_X <= position_X + 12'd1;
                                   end
                            end
                            else begin
                                   position_Y <= position_Y + 12'd1;
                                   position_X <= position_X;
                            end
                            else begin
                                   position_X <= position_X;
                                   position_Y <= position_Y;
                            end
                     end
                     L1_W: begin
                            if(position_en && img_cnt == 1) begin
                                   if(position_Y == 62) begin
                                   position_Y <= 0;
                                   if(position_X == 62) position_X <= 0;
                                   else position_X <= position_X + 2;  
                                   end
                                   else begin 
                                          position_Y <= position_Y + 2;
                                          position_X <= position_X;
                                   end
                            end
                            else begin
                                   position_X <= position_X;
                                   position_Y <= position_Y;
                            end
                            end
                     default: begin
                            position_X <= position_X;
                            position_Y <= position_Y;
                  end
           endcase
      end
end

assign position = (position_X <<< 6) + position_Y; 
                                              
//3*3 Mask

always @(*) begin
       assign pos_0 = pos_4 - 12'd65;
       assign pos_1 = pos_4 - 12'd64;
       assign pos_2 = pos_4 - 12'd63;
       assign pos_3 = pos_4 - 12'd1;
       assign pos_4 = position
       assign pos_5 = pos_4 + 12'd1;
       assign pos_6 = pos_4 + 12'd63;
       assign pos_7 = pos_4 + 12'd64;
       assign pos_8 = pos_4 + 12'd65;         
       
end


//address of mask
always @(posedge clk or posedge reset) begin
       if(reset) begin
              iaddr <= 12'd0;
       end
       else if(state == INPUT) begin
              case(img_cnt) begin
                     0: iaddr <= pos_0;
                     1: iaddr <= pos_1;
                     2: iaddr <= pos_2;
                     3: iaddr <= pos_3;
                     4: iaddr <= pos_4;
                     5: iaddr <= pos_5;
                     6: iaddr <= pos_6;
                     7: iaddr <= pos_7;
                     8: iaddr <= pos_8;
                     default: iaddr <= iaddr;                     
              end
              endcase
       end
       else begin
              iaddr <= iaddr;
       end

       
end






















endmodule
