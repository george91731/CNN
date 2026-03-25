//==================================
//Project: IC Design Contest_2019
//Designer: William
//Date: 2022/04/08
//Version: 2.0
//==================================
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
// FSM
reg [2:0] state;
reg [2:0] n_state;
parameter RESET   = 3'b000;
parameter INPUT   = 3'b001;
parameter CONV    = 3'b010;
parameter L0_W    = 3'b011;
parameter MAXPOOL = 3'b100;
parameter L1_W    = 3'b101;
parameter FLAT    = 3'b110;
parameter FINISH  = 3'b111;
//
//reg [12:0] in_cnt;
reg signed [19:0] image [0:8];
reg [11:0] img_addr;
// position
reg [11:0] position_X, position_Y;
wire [11:0] position;
wire [11:0] position_0;
wire [11:0] position_1;
wire [11:0] position_2;
wire [11:0] position_3;
wire [11:0] position_4;
wire [11:0] position_5;
wire [11:0] position_6;
wire [11:0] position_7;
wire [11:0] position_8;
//
reg [3:0] img_cnt;
reg signed [19:0] kernel_0 [0:8];
reg signed [19:0] kernel_1 [0:8];
reg signed [19:0] bias_0;
reg signed [19:0] bias_1;
reg position_en;
wire switch = 0;
// Convolution && Rounding
reg signed [19:0] mul_image;
reg signed [19:0] mul_kernel_0;
reg signed [19:0] mul_kernel_1;
reg signed [39:0] mul_result_0;
reg signed [39:0] mul_result_1;
reg signed [43:0] mul_sum_0;
reg signed [43:0] mul_sum_1;
reg signed [20:0] round_0;
reg signed [20:0] round_1;
// ReLU
reg signed [19:0] relu_0;
reg signed [19:0] relu_1;
// 
reg [11:0] position_buffer;
reg L0_ready;
reg kernel_switch; // select kernel_0 or kernel_1
// Maxpooling
reg [19:0] maxpool_data [3:0];
reg [19:0] big_1, big_2, max;
reg max_read = 0;
reg max_done = 0;
reg [9:0] L1_cnt;
// Flatten
wire L2_flag;
reg [10:0] L2_cnt;

integer i;

// Busy
always @(posedge clk or posedge reset) begin
  if (reset) begin
    busy <= 0;
  end
  else if (ready) begin
    busy <= 1;
  end
  else if (state == FINISH) begin
    busy <= 0;
  end
  else begin
    busy <= busy;
  end
end

// FSM_current state
always@(posedge clk or posedge reset) begin
    if(reset) begin
       state <= 0;
    end
    else begin
       state <= n_state;
    end
end

// FSM_state transition
always@(*) begin
        case(state)
             RESET: begin
                   if(ready) n_state = INPUT;
                   else if(L2_flag) n_state = FLAT;
                   else if(L0_ready) n_state = MAXPOOL;
                   else n_state = state;
             end
             INPUT: begin
                   if(img_cnt == 12) n_state = CONV;
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
         /*MAXPOOL: begin
           if(img_cnt == 0) position_en <= 0;
           else position_en <= position_en;
         end*/
         L1_W: begin
           if(img_cnt == 0 && kernel_switch) position_en <= 1;
           else position_en <= 0;
         end
         FLAT: position_en <= 1;
         default: position_en <= 0;
    endcase
  end
end

// Image position
always@(posedge clk or posedge reset) begin
      if(reset) begin
       position_X <= 0;
       position_Y <= 0;
      end
      else begin
             case(state)
                  RESET: begin
                    position_X <= 0;
                    position_Y <= 0;
                  end 
                  INPUT: begin
                    if(img_cnt == 12 && position_en) begin
                       if(position_Y == 63) begin
                          position_Y <= 0;
                          if(position_X == 63) position_X <= 0;
                          else position_X <= position_X + 1;  
                       end
                       else begin 
                            position_Y <= position_Y + 1;
                            position_X <= position_X;
                       end
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

// Construct the 9*9 mask
assign position_0 = position_4 - 65;
assign position_1 = position_4 - 64;
assign position_2 = position_4 - 63;
assign position_3 = position_4 - 1;
assign position_4 = position;
assign position_5 = position_4 + 1;
assign position_6 = position_4 + 63;
assign position_7 = position_4 + 64;
assign position_8 = position_4 + 65;

// Image counter
always @(posedge clk or posedge reset) begin
      if(reset) begin
       img_cnt <= 0;
      end
      else begin
        case(state)
             RESET: img_cnt <= 0;
             INPUT: begin
               if(img_cnt == 12) img_cnt <= 0;
               else img_cnt <= img_cnt + 1;                             
             end
             CONV: begin
               if(img_cnt == 1) img_cnt <= 0;
               else img_cnt <= img_cnt + 1;
             end
             L0_W: begin
               if(img_cnt == 2) img_cnt <= 0;
               else img_cnt <= img_cnt + 1;
             end
             MAXPOOL: begin
               if(img_cnt == 4) img_cnt <= 0;
               else img_cnt <= img_cnt + 1;
             end
             L1_W: begin
               if(img_cnt == 1) img_cnt <= 0;
               else img_cnt <= img_cnt + 1;
             end
             FLAT: begin
               if(img_cnt == 3) img_cnt <= 0;
               else img_cnt <= img_cnt + 1;
             end
             default: begin
               img_cnt <= img_cnt;
             end
        endcase    
      end
end

// Address of the 9*9 mask
always @(posedge clk or posedge reset) begin
      if(reset) begin
       iaddr <= 0;
      end
      else if(state == INPUT) begin
               case(img_cnt)
                    0: iaddr <= position_0;
                    1: iaddr <= position_1;
                    2: iaddr <= position_2;
                    3: iaddr <= position_3;
                    4: iaddr <= position_4;
                    5: iaddr <= position_5;
                    6: iaddr <= position_6;
                    7: iaddr <= position_7;
                    8: iaddr <= position_8;
                    default: iaddr <= iaddr;
               endcase
      end
      else begin
         iaddr <= iaddr;
      end
end

// Read 9 pixels 
always @(posedge clk or posedge reset) begin
  if (reset) begin
    for(i = 0; i < 9; i = i + 1) begin
      image[i] <= 20'd0;
    end
  end
  else begin
    if(state == INPUT)begin
      case(img_cnt)
           1: begin
             if(position_X == 0 || position_Y == 0) image[0] <= 0;
             else image[0] <= idata;
           end
           2: begin
             if(position_X == 0) image[1] <= 0;
             else image[1] <= idata;
           end
           3: begin
             if(position_Y == 63 || position_X == 0) image[2] <= 0;
             else image[2] <= idata;
           end
           4: begin
             if(position_Y == 0) image[3] <= 0;
             else image[3] <= idata;
           end
           5: begin
             image[4] <= idata;
           end
           6: begin 
             if(position_Y == 63) image[5] <= 0;
             else image[5] <= idata;
           end
           7: begin
             if(position_Y == 0 || position_X == 63) image[6] <= 0;
             else image[6] <= idata;
           end
           8: begin
             if(position_X == 63) image[7] <= 0;
             else image[7] <= idata;
           end
           9: begin
             if(position_X == 63 || position_Y == 63) image[8] <= 0;
             else image[8] <= idata;
           end
           default: begin
             for(i = 0; i < 9; i = i + 1) begin
               image[i] <= image[i];
             end
           end
      endcase
    end
    else begin
      for(i = 0; i < 9; i = i + 1) begin
          image[i] <= image[i];
      end
    end
  end
end

// kernel_0 value && bias_0
always @(posedge clk or posedge reset) begin
  if (reset) begin
    for(i = 0; i < 9; i = i + 1) begin
      kernel_0[i] <= 0;
    end
    bias_0 <= 0;  
  end
  else begin
      kernel_0[0] <= 20'h0A89E;
      kernel_0[1] <= 20'h092D5;
      kernel_0[2] <= 20'h06D43;
      kernel_0[3] <= 20'h01004;
      kernel_0[4] <= (~20'hF8F71) + 1;
      kernel_0[5] <= (~20'hF6E54) + 1;
      kernel_0[6] <= (~20'hFA6D7) + 1;
      kernel_0[7] <= (~20'hFC834) + 1;
      kernel_0[8] <= (~20'hFAC19) + 1;
      //
      bias_0 <= 20'h01310;
  end
end

// kernel_1 value && bias_1
always @(posedge clk or posedge reset) begin
  if (reset) begin
    for(i = 0; i < 9; i = i + 1) begin
      kernel_1[i] <= 0;
    end
    bias_1 <= 0;  
  end
  else begin
      kernel_1[0] <= (~20'hFDB55) + 1;
      kernel_1[1] <= 20'h02992;
      kernel_1[2] <= (~20'hFC994) + 1;
      kernel_1[3] <= 20'h050FD;
      kernel_1[4] <= 20'h02F20;
      kernel_1[5] <= 20'h0202D;
      kernel_1[6] <= 20'h03BD7;
      kernel_1[7] <= (~20'hFD369) + 1;
      kernel_1[8] <= 20'h05E68;
      //
      bias_1 <= 20'hF7295;
  end
end

// Convolution 

// mul_image
always @(posedge clk or posedge reset) begin
  if (reset) begin
    mul_image <= 20'd0;
    mul_kernel_0 <= 20'd0;
    mul_kernel_1 <= 20'd0;
  end
  else begin
    if(state == INPUT)begin
      case(img_cnt)
           1: begin
             if(position_X == 0 || position_Y == 0) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[0];
               mul_kernel_1 <= kernel_1[0];
             end
           end
           2: begin
             if(position_X == 0) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[1];
               mul_kernel_1 <= kernel_1[1];
             end
           end
           3: begin
             if(position_Y == 63 || position_X == 0) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[2];
               mul_kernel_1 <= kernel_1[2];
             end
           end
           4: begin
             if(position_Y == 0) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[3];
               mul_kernel_1 <= kernel_1[3];
             end
           end
           5: begin
             mul_image <= idata;
             mul_kernel_0 <= kernel_0[4];
             mul_kernel_1 <= kernel_1[4];
           end
           6: begin 
             if(position_Y == 63) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[5];
               mul_kernel_1 <= kernel_1[5];
             end
           end
           7: begin
             if(position_Y == 0 || position_X == 63) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[6];
               mul_kernel_1 <= kernel_1[6];
             end
           end
           8: begin
             if(position_X == 63) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[7];
               mul_kernel_1 <= kernel_1[7];
             end
           end
           9: begin
             if(position_X == 63 || position_Y == 63) mul_image <= 0;
             else begin
               mul_image <= idata;
               mul_kernel_0 <= kernel_0[8];
               mul_kernel_1 <= kernel_1[8];
             end
           end
           default: begin
             mul_image <= mul_image;
           end
      endcase
    end
    else begin
      mul_image <= mul_image;
    end
  end
end

// mul_conv
always @(posedge clk or posedge reset) begin
  if (reset) begin
    mul_result_0 <= 40'd0;
    mul_result_1 <= 40'd0;
  end
  else begin
    case(state)
        INPUT: begin
          case(state)
              INPUT: begin
                if(img_cnt > 1) begin
                  if(img_cnt > 5) mul_result_0 <= ~(mul_image * mul_kernel_0) + 40'd1;
                  else mul_result_0 <= mul_image * mul_kernel_0;
                  if( (img_cnt == 2) || (img_cnt == 4) || (img_cnt == 9) ) mul_result_1 <= ~(mul_image * mul_kernel_1) + 40'd1;
                  else mul_result_1 <= mul_image * mul_kernel_1;
                end
              end
          endcase
        end
    endcase
  end
end

// mul_sum
always @(posedge clk or posedge reset) begin
  if (reset) begin
    mul_sum_0 <= 44'd0;
    mul_sum_1 <= 44'd0;
  end
  else begin
    case(state)
        INPUT: begin
          if(img_cnt == 3) begin
            mul_sum_0 <= mul_result_0;
            mul_sum_1 <= mul_result_1;
          end
          else if(img_cnt > 3 && (img_cnt < 12)) begin
            mul_sum_0 <= mul_sum_0 + mul_result_0;
            mul_sum_1 <= mul_sum_1 + mul_result_1;
          end
          else if(img_cnt == 12) begin
            mul_sum_0 <= mul_sum_0 + {bias_0, 16'd0};
            mul_sum_1 <= mul_sum_1 + {bias_1, 16'd0};
          end
        end
        L0_W: begin
        if(img_cnt == 2) begin
          mul_sum_0 <= 0;
          mul_sum_1 <= 0;
        end
        end
    endcase
  end
end

// Rounding 
always @(*) begin
  round_0 = (mul_sum_0 > 0) ? mul_sum_0[35:15] + 21'd1 : 0;
  round_1 = (mul_sum_1 > 0) ? mul_sum_1[35:15] + 21'd1 : 0;
end

// ReLU function
always @(*) begin
  if(round_0 > 0) relu_0 = round_0[20:1];
  else relu_0 = 0;
  if(round_1 > 0) relu_1 = round_1[20:1];
  else relu_1 = 0;
end

// Kernel selection signal
always @(posedge clk or posedge reset) begin
  if (reset) begin
    kernel_switch <= 0;
  end
  else begin
    case(state)
         L0_W: kernel_switch <= ~kernel_switch;
         MAXPOOL: begin
           /*if(max_read && img_cnt == 0) kernel_switch <= ~kernel_switch;
           else kernel_switch <= kernel_switch;*/
           kernel_switch <= kernel_switch;
         end 
         L1_W: begin
           if(max_read && img_cnt == 0) kernel_switch <= ~kernel_switch;
           else kernel_switch <= kernel_switch;
         end
         FLAT: kernel_switch <= ~kernel_switch;
         default: kernel_switch <= 0;
    endcase
  end 
end

// Memory address by one delay
always @(posedge clk or posedge reset) begin
  if (reset) begin
    position_buffer <= 0;
  end
  else begin
    case(state)
         INPUT: position_buffer <= position;
         MAXPOOL: position_buffer <= position;
         default: position_buffer <= position_buffer;
    endcase
  end
end

// Ready for layer_0 memory
always @(posedge clk or posedge reset) begin
  if (reset) begin
    L0_ready <= 0;
  end
  else if (state == L0_W && img_cnt == 2 && position_buffer == 4095) begin
    L0_ready <= 1;
  end
  else begin
    L0_ready <= L0_ready;
  end
end

//==================================//
//             MEMORY               //
//==================================//

// Memory selection 
always @(posedge clk or posedge reset) begin
  if (reset) begin
    csel <= 3'b000;
  end
  else begin
    case(state)
         L0_W: begin
           if(!kernel_switch) csel <= 3'b001;
           else csel <= 3'b010;
         end
         MAXPOOL: begin
           if(!kernel_switch) csel <= 3'b001;
           else csel <= 3'b010;
         end
         L1_W: begin
           if(!kernel_switch) csel <= 3'b011;
           else csel <= 3'b100;
         end
         FLAT: begin
           case(img_cnt)
                0: csel <= 3'b011;
                2: csel <= 3'b100;
                default: csel <= 3'b101;
           endcase
         end
         default: begin
           csel <= 3'b000;
         end
    endcase
  end
end

// WRITE MODE
// Write enable
always @(posedge clk or posedge reset) begin
  if (reset) begin
    cwr <= 0;
  end
  else begin
    case(state)
         L0_W:begin
           if(img_cnt == 2) cwr <= 0;
           else cwr <= 1;
         end
         L1_W: begin
           if(img_cnt == 0) cwr <= 1;
           else cwr <= 0;
         end
         FLAT: begin
           case(img_cnt)
                1: cwr <= 1;
                3: cwr <= 3;
                default: cwr <= 0;
           endcase
         end
         default:begin
           cwr <= 0;
         end
    endcase
  end
end

// Write-in address
always @(posedge clk or posedge reset) begin
  if (reset) begin
    caddr_wr <= 0;
  end
  else begin
    case(n_state)
         L0_W: begin
           if(!kernel_switch) caddr_wr <= position_buffer;
           else caddr_wr <= caddr_wr;
         end
         /*MAXPOOL: begin
           if() begin
             if(img_cnt == 0 || img_cnt == 2) caddr_wr <= position_buffer >> 1;
             else caddr_wr <= caddr_wr;
           end
           else begin
             caddr_wr <= caddr_wr;
           end
         end*/
         L1_W: begin
           caddr_wr <= L1_cnt;
         end
         FLAT: begin
           caddr_wr <= L2_cnt;
         end
         default:begin
           caddr_wr <= caddr_wr;
         end
    endcase
  end
end

// Write-in data
always @(posedge clk or posedge reset) begin
  if (reset) begin
    cdata_wr <= 0;
  end
  else begin
    case(state)
         L0_W: begin
           if(!kernel_switch) cdata_wr <= relu_0;
           else cdata_wr <= relu_1;
         end
         /*MAXPOOL: begin
           if(img_cnt == 4) cdata_wr <= max;
           else cdata_wr <= cdata_wr;
         end*/
         L1_W: begin
           cdata_wr <= max;
         end
         FLAT: begin
           cdata_wr <= cdata_rd;
         end
         default: begin
           cdata_wr <= cdata_wr;
         end
    endcase
  end
end

// READ MODE
// Read enable
always @(posedge clk or posedge reset) begin
  if (reset) begin
    crd <= 0;
  end
  else begin
    case(state)
         MAXPOOL: begin
           crd <= 1;
         end
         FLAT: begin
           crd <= 1;
         end
         default: begin
           crd <= 0;
         end
    endcase
  end
end

// Read address
always @(posedge clk or posedge reset) begin
  if (reset) begin
    caddr_rd <= 0;
  end
  else begin
    case(state)
         MAXPOOL: begin
           case(img_cnt)
                 0: begin
                   caddr_rd <= position;
                 end 
                 1: begin
                   caddr_rd <= position + 1;
                 end 
                 2: begin
                   caddr_rd <= position + 64;
                 end 
                 3: begin
                   caddr_rd <= position + 65;
                 end 
                 default: begin
                   caddr_rd <= caddr_rd;
                 end 
           endcase 
         end
         FLAT: caddr_rd <= L1_cnt;
         default: begin
           caddr_rd <= caddr_rd;
         end
    endcase
  end
end

//==================================

// Read four pixels for maxpooling
always @(posedge clk or posedge reset) begin
  if (reset) begin
    for(i = 0; i < 4; i = i + 1) begin
      maxpool_data[i] <= 0;
    end  
  end
  else begin
    case(state)
         MAXPOOL: begin
           case(img_cnt)
                1: begin
                  maxpool_data[0] <= cdata_rd;
                end
                2: begin
                  maxpool_data[1] <= cdata_rd;
                end
                3: begin
                  maxpool_data[2] <= cdata_rd;
                end
                4: begin
                  maxpool_data[3] <= cdata_rd;
                end
                default: begin
                  for(i = 0; i < 4; i = i + 1) begin
                    maxpool_data[i] <= maxpool_data[i];
                  end 
                end
           endcase
         end
         default: begin
           for(i = 0; i < 4; i = i + 1) begin
             maxpool_data[i] <= maxpool_data[i];
           end
         end
    endcase
  end
end

// Maxpooling ready for input data
always @(posedge clk or posedge reset) begin
  if(reset) begin
    max_read <= 0;
  end
  else begin
    if(state == MAXPOOL && img_cnt == 1) max_read <= 1;
    else max_read <= max_read;
  end
end

//Find max pixel
always @(*) begin
    big_1 = (maxpool_data[0] > maxpool_data[1]) ? maxpool_data[0] : maxpool_data[1];
    big_2 = (maxpool_data[2] > maxpool_data[3]) ? maxpool_data[2] : maxpool_data[3];
    max = (big_1 > big_2) ? big_1 : big_2;
end

// Flag for the last result of maxpooling
always @(posedge clk or posedge reset) begin
  if(reset) begin
    max_done <= 0;
  end
  else begin
    if(state == MAXPOOL && L1_cnt == 1) max_done <= 1;
    else max_done <= max_done;
  end 
end

// Address of layer1 result
always @(posedge clk or posedge reset) begin
  if (reset) begin
    L1_cnt <= 0;
  end
  else begin
    case(state)
         RESET: begin
           L1_cnt <= 0;
         end
         L1_W: begin
           if(position_en) begin
           //if(img_cnt == 0 && kernel_switch) begin
             if(L1_cnt == 1023) L1_cnt <= 0;
             else L1_cnt <= L1_cnt + 1;
           end
           else begin
             L1_cnt <= L1_cnt;
           end
         end
         FLAT: begin 
           if(L1_cnt == 1023) L1_cnt <= L1_cnt;
           else if(img_cnt == 3) L1_cnt <= L1_cnt + 1;
         end
         default: begin
           L1_cnt <= L1_cnt;
         end
    endcase
  end
end

assign L2_flag = (L1_cnt == 0 && max_done) ? 1 : 0;

always @(posedge clk or posedge reset) begin
  if (reset) begin
    L2_cnt <= 0;    
  end
  else begin
    case(state)
         FLAT: begin
           if(L2_cnt == 2047) L2_cnt <= L2_cnt; 
           else if(img_cnt == 1 || img_cnt == 3) L2_cnt <= L2_cnt + 1;
           else L2_cnt <= L2_cnt;
         end
         default: begin
           L2_cnt <= L2_cnt;
         end
    endcase
  end
end

endmodule
