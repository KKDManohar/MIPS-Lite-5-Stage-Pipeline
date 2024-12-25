interface r_intf();

    parameter add=6'd0;
    parameter add_imm=6'd1;
    parameter sub=6'd2;
    parameter sub_imm=6'd3;
    parameter mul=6'd4;
    parameter mul_imm=6'd5;
    parameter or_l=6'd6;
    parameter or_imm=6'd7;
    parameter and_l=6'd8;
    parameter and_lmm=6'd9;
    parameter xor_l=6'd10;
    parameter xor_Imm=6'd11;
    parameter load_reg=6'd12;
    parameter store_reg=6'd13;
    parameter bz=6'd14;
    parameter Beq=6'd15;
    parameter Jmp=6'd16;
    parameter hlt=6'd17;
    
    parameter REGISTER_WIDTH=32;
	parameter DATA_WIDTH=8;
	parameter MEM_SIZE=12;
    parameter PIPE_SIZE=5;
    localparam OPSET_SIZE=5;
    localparam IMM_SIZE=16;
   
    bit signed [REGISTER_WIDTH-1:0]Updated_Registers[REGISTER_WIDTH]; 
    bit CLOCK=0;
    int fd;
    int count;
    int stall_raw;
    int i=0;
    int decode_stall;
    bit fetch_wait;
    int branch_count ;
    int hit;
    bit [3:0] pipeline_stage[PIPE_SIZE];

    bit  signed [REGISTER_WIDTH-1:0]IR;
    bit  [OPSET_SIZE:0]op_set;
    bit  [OPSET_SIZE-1:0]SourceReg1;
    bit  [OPSET_SIZE-1:0]SourceReg2;
    bit  [OPSET_SIZE-1:0]DestReg;

    bit signed  [IMM_SIZE:0]Imm_Data;
    bit signed  [REGISTER_WIDTH-1:0]result;
    bit  [REGISTER_WIDTH-1:0]ld_value;
    bit  [REGISTER_WIDTH-1:0]st_value;
    bit signed  [REGISTER_WIDTH-1:0]ld_data;
    bit  signed [REGISTER_WIDTH-1:0]PC_value;
    bit signed [REGISTER_WIDTH-1:0]branch_target;

    always 
    begin
        #10 CLOCK=~CLOCK;
    end
    
endinterface
