package instructions;
typedef struct{
    bit [31:0]Ir;
    bit [5:0]opcode;
    bit [4:0]src1;
    bit [4:0]src2;
    bit [4:0]dest;
    bit signed[31:0]rs;
    bit signed[31:0]rt;
    bit signed[31:0]rd;
    bit signed[16:0]imm;
    bit signed[31:0]result;
    bit [31:0]ld_value ;
    bit [31:0]st_value;
    bit signed[31:0]load_data;
    bit signed[31:0]pc_value;
    int signed source_reg1;
    int signed source_reg2;
    int signed dest_reg;
    bit signed [31:0]branch_target; 
} instruction_set;
endpackage