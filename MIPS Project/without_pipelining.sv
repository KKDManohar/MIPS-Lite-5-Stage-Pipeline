module without_pipeline(output bit done);
  r_intf intf();
  
  int Total_instr_count;
  int Arth_Instr_count;
  int Log_Instr_count;
  int memory_count;
  int branches;
  int register_array[intf.REGISTER_WIDTH];
  int memory_array[1<<intf.MEM_SIZE];
  int branch_taken;
  bit signed [31:0]Registers[intf.REGISTER_WIDTH];
  bit signed [intf.DATA_WIDTH-1:0]memory[1<<intf.MEM_SIZE];
  bit signed [31:0]PC;
  int cycles_count;
  bit signed  [intf.REGISTER_WIDTH-1:0]Rs;
  bit signed  [intf.REGISTER_WIDTH-1:0]Rt;
  bit signed  [intf.REGISTER_WIDTH-1:0]Rd;
  int i;

  initial begin : file_descriptor_block
    $display("File Descriptor initialized!");
    intf.fd = $fopen("./sample_memory_image.txt", "r");  
    if(intf.fd==0)
      disable file_descriptor_block;  
    while(!($feof(intf.fd))) 
    begin
      $fscanf(intf.fd, "%32h",{memory[i], memory[i+1], memory[i+2], memory[i+3]});
      i=i+4;
    end
    $fclose(intf.fd);
  end : file_descriptor_block

  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      fetch_stage();
      decode_stage();
      execute_stage();
      memory_stage();
      write_back_stage();
    end
  end


  task fetch_stage();

            begin	         
              intf.IR ={memory[PC], memory[PC+1], memory[PC+2], memory[PC+3] }  ;
              PC=PC+4;
            end

  endtask



  task decode_stage( );
    intf.op_set = intf.IR[31:26];                      
    if ( (intf.op_set==intf.add) || (intf.op_set==intf.sub) || (intf.op_set==intf.mul) || (intf.op_set==intf.or_l) || (intf.op_set==intf.and_l) || (intf.op_set==intf.xor_l))
    begin       
      intf.SourceReg1     = intf.IR[25:21];
      intf.SourceReg2     = intf.IR[20:16];
      intf.DestReg     = intf.IR[15:11];
      Rs         = $signed(Registers[intf.IR[25:21]]);
      Rt         = $signed(Registers[intf.IR[20:16]]);
      Rd         = $signed(Registers[intf.IR[15:11]]);                               
    end
    else if ((intf.op_set==intf.add_imm) || (intf.op_set==intf.sub_imm) || (intf.op_set==intf.mul_imm) || (intf.op_set==intf.or_imm) || (intf.op_set==intf.and_lmm) || ( intf.op_set==intf.xor_Imm) || (intf.op_set==intf.load_reg) || (intf.op_set==intf.store_reg))                       
    begin                                     
      intf.Imm_Data        = $signed(intf.IR[15:0]);
      intf.SourceReg1     = intf.IR[25:21];
      intf.SourceReg2     = intf.IR[20:16];
      Rs         = $signed(Registers[intf.IR[25:21]]);
      Rt         = $signed(Registers[intf.IR[20:16]]);
    end
    else if ((intf.op_set== intf.bz))
    begin
      intf.SourceReg1     = intf.IR[25:21];
      intf.branch_target     = $signed(intf.IR[15:0]);
      Rs         = $signed(Registers[intf.IR[25:21]]);
    end
    else if (intf.op_set== intf.Beq)
    begin
      intf.SourceReg1     = intf.IR[25:21];
      intf.SourceReg2     = intf.IR[20:16];
      intf.branch_target   = $signed(intf.IR[15:0]);	                                        	                                  
      Rs       = $signed(Registers[intf.IR[25:21]]);
      Rt       = $signed(Registers[intf.IR[20:16]]);
    end
    else if (intf.op_set== intf.Jmp)

  begin
        intf.SourceReg1     = intf.IR[25:21];                          
          Rs         = $signed(Registers[intf.IR[25:21]]);
        end
  else
      begin
        Rd         = 0;
        Rs         = 0;
        Rt         = 0;
        intf.DestReg     = 0;
        intf.SourceReg1     = 0;
        intf.SourceReg2     = 0;
  end

                          register_array[intf.SourceReg1]=1;
                          register_array[intf.SourceReg2]=1;
                          register_array[intf.DestReg]=1;
  endtask

  
  task execute_stage();
    case(intf.op_set)
      intf.add    : ADD(Rs, Rt, intf.result );
      intf.add_imm  : ADD_imm(Rs, intf.Imm_Data , intf.result );                           
      intf.sub    : SUB(Rs, Rt,   intf.result );                           	     
      intf.sub_imm  : SUB_imm(Rs, intf.Imm_Data , intf.result );                           
      intf.mul    : MUL(Rs, Rt,   intf.result );                           
      intf.mul_imm  : MUL_imm(Rs, intf.Imm_Data , intf.result );                           
      intf.or_l     : OR(Rs, Rt,   intf.result );                           
      intf.or_imm   : OR_imm(Rs, intf.Imm_Data , intf.result );                           
      intf.and_l    : AND(Rs, Rt,   intf.result );                           
      intf.and_lmm  : AND_imm(Rs, intf.Imm_Data , intf.result );                          
      intf.xor_l    : XOR(Rs, Rt,   intf.result );                           
      intf.xor_Imm  : XOR_imm(Rs, intf.Imm_Data , intf.result );                           
      intf.load_reg    : begin 
                         	intf.ld_value=Rs+intf.Imm_Data;  
                            memory_count=memory_count+1;   
                         end                           
      intf.store_reg    :begin
                         	intf.st_value=Rs+intf.Imm_Data;
                      		memory_count=memory_count+1;
                      		memory_array[ intf.st_value]=1;
                    	end
      intf.bz      : begin      
                     	branches=branches+1;                     
                        if(Rs==0)  
                      begin    
                      	branch_taken=branch_taken+1;                                  
                        PC<= (intf.branch_target*4 )+ PC-4;      
                      end
                    end                           
      intf.Beq     : begin      
                      branches=branches+1;                                  
                      if( Rs == Rt)     
                      begin                                       
                        PC<= (intf.branch_target*4) + PC-4 ;  
						branch_taken=branch_taken+1; 
                      end                           
                    end                           
      intf.Jmp    : begin
                      PC<= Rs;   
					  branches=branches+1; 
					  branch_taken=branch_taken+1;  
                    end                                                  
    endcase
  endtask

  task memory_stage();   
    case(intf.op_set)                           
    intf.load_reg  : intf.ld_data= $signed({memory[intf.ld_value],memory[intf.ld_value+1], memory[intf.ld_value+2], memory[intf.ld_value+3]});                           
    intf.store_reg : {memory[intf.st_value],memory[intf.st_value+1], memory[intf.st_value+2], memory[intf.st_value+3]}=$signed(Rt);                           
    endcase
  endtask

  task write_back_stage();
    Total_instr_count =Total_instr_count+1;                                
    case(intf.op_set)                            
      intf.add : 
      begin                           
        Registers[intf.DestReg] = intf.result;
        Arth_Instr_count=Arth_Instr_count+1;                              
      end

      intf.add_imm: 
      begin                           
        Registers[intf.SourceReg2] = intf.result;
        Arth_Instr_count=Arth_Instr_count+1;                              
      end

      intf.sub: 
      begin                           
        Registers[intf.DestReg] = intf.result;                           	     
        Arth_Instr_count=Arth_Instr_count+1;                              
      end

      intf.sub_imm: 
      begin                           
        Registers[intf.SourceReg2] = intf.result;                           	      
        Arth_Instr_count=Arth_Instr_count+1;                              
      end

      intf.mul: 
      begin                           
        Registers[intf.DestReg] = intf.result;                           
        Arth_Instr_count=Arth_Instr_count+1;                              
      end

      intf.mul_imm: 
      begin                           
        Registers[intf.SourceReg2] = intf.result;                           
        Arth_Instr_count=Arth_Instr_count+1;                              
      end

      intf.or_l: 
      begin                           
        Registers[intf.DestReg] = intf.result; 
        Log_Instr_count=Log_Instr_count+1;                          	       
      end                           

      intf.or_imm: 
      begin                           
        Registers[intf.SourceReg2] = intf.result;                           
        Log_Instr_count=Log_Instr_count+1;                          	       
      end

      intf.and_l: 
      begin                           
        Registers[intf.DestReg] = intf.result;                           	   
        Log_Instr_count=Log_Instr_count+1;                          	       
      end

      intf.and_lmm:
      begin                                 
        Registers[intf.SourceReg2] = intf.result;
        Log_Instr_count=Log_Instr_count+1;                          	       
      end

      intf.xor_l: 
      begin                           
        Registers[intf.DestReg] = intf.result;                           
        Log_Instr_count=Log_Instr_count+1;                          	       
      end

      intf.xor_Imm: 
      begin                           
        Registers[intf.SourceReg2] =intf.result;                           	   
        Log_Instr_count=Log_Instr_count+1;                          	       
      end
                                
      intf.load_reg : 
      begin                           
        Registers[intf.SourceReg2] = intf.ld_data;                           
      end                     

      intf.hlt: done<=1;
                                                        
    endcase                       
  endtask

  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    cycles_count=cycles_count+1;
  end

  task ADD(input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ; c=a+b ;  endtask
  task ADD_imm(input bit signed [intf.REGISTER_WIDTH-1:0]a , input  bit signed  [15:0]b , output  bit signed  [intf.REGISTER_WIDTH-1:0]c ) ; c=a+b;  endtask
  task SUB(input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed  [intf.REGISTER_WIDTH-1:0]c ) ;   c=a-b;  endtask
  task SUB_imm (input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a-b;  endtask
  task MUL(input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a*b;   endtask
  task MUL_imm(input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ; c=a*b;  endtask
  task OR(input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ;   c=a|b; endtask
  task OR_imm(input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ;  c=a|b; endtask
  task AND(input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a&b; endtask
  task AND_imm(input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a&b; endtask
  task XOR(input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a^b;  endtask
  task XOR_imm (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a^b; endtask

endmodule
