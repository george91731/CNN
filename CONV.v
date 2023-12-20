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



//FSM current state
always @(posedge clk or posedge reset) begin
       if(reset) begin
              state <= 1'b0;
       end
       else begin
              state <= n_state;
       end      
end

//FSM next state
always @(*) begin
       case(state)
              RESET: begin
              if(ready) n_state = INPUT;
              else n_state = state;
              end

              INPUT :begin
              
              if
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























endmodule
