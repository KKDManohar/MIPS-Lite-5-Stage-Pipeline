module pipelined_without_forwarding(output bit done);
  import instructions::*;
  r_intf intf();
  int count_cycles;
  int stall;
  int stall_one;
  int stall_two;
  bit temp;
  int Total_instr_count;
  bit branch_taken;
  bit signed [31:0]Registers[32];
  bit signed [7:0]memory[4096];
  bit signed [31:0]PC;
  
  instruction_set instr_lines[5];

  bit [3:0] pipeline_stage[5];
  int i=0;
  int decode_stall;
  bit decode_wait;
  bit fetch_wait;
  int total_stall;
  bit hlt=0;

  initial begin : file_descriptor_block
      $display("File Descriptor initialized!");
      intf.fd = $fopen ("./sample_memory_image.txt", "r");  
      if(intf.fd ==0)
        disable file_descriptor_block; //disable if intf.fd asserts to 0.
      while (!($feof(intf.fd))) 
      begin
        $fscanf(intf.fd, "%32h",{memory[i], memory[i+1], memory[i+2], memory[i+3]});
        i=i+4;
      end
      #10;
      $fclose(intf.fd);
  end : file_descriptor_block


  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
    if(fetch_wait==0) 
    begin
      for(int i=0; i<5; i++)
        begin
          if(pipeline_stage[i]==0 )
          begin		         
            pipeline_stage[i] <=1;
            instr_lines[i].Ir ={memory[PC ], memory[PC+1], memory[PC+2], memory[PC+3] }  ;
            instr_lines[i].pc_value = PC ;
            PC =PC +4;
            break;
          end
        end
      end
    end
  end
  

  always@(posedge intf.CLOCK)
  begin
  if(done==0 )
  begin
  #0;
     for(int i=0; i<5; i++)
  
            begin
              if(pipeline_stage[i]==4'd1)
             
                         begin
                            decode_stage(i) ;                            
                            decode_stall = check_decode_stall(i);
                            if(decode_stall==2 && hlt==0)
                             stall_two=stall_two+1;
                            if(decode_stall==1 && hlt==0)
                             stall_one=stall_one+1;
                            decode_wait =0; 
                            if(decode_stall!=0 && hlt==0 )
                              begin
                            stall=stall+1;
                            repeat(decode_stall)
                             begin
                             decode_wait<=1; 
                             fetch_wait <=1;
                              @(posedge intf.CLOCK);
                              fetch_wait<=0;
                             end
                             decode_stage(i) ; 
                            decode_wait<=0;
                               end
                            pipeline_stage[i]<=2;                         
                         break;
  
             end
             end
  
   end
  end
  
  task decode_stage(int i);
    instr_lines[i].opcode = instr_lines[i].Ir[31:26];
    if ( (instr_lines[i].opcode==intf.add) || (instr_lines[i].opcode==intf.sub) ||   (instr_lines[i].opcode==intf.mul ) || (instr_lines[i].opcode==intf.or_l) ||(instr_lines[i].opcode==intf.and_l) ||(instr_lines[i].opcode==intf.xor_l))
    begin       
      instr_lines[i].src1          = instr_lines[i].Ir[25:21];
      instr_lines[i].src2          = instr_lines[i].Ir[20:16];
      instr_lines[i].dest          = instr_lines[i].Ir[15:11];
      instr_lines[i].source_reg1   = instr_lines[i].Ir[25:21];
      instr_lines[i].source_reg2 = instr_lines[i].Ir[20:16];
      instr_lines[i].dest_reg    = instr_lines[i].Ir[15:11];
      instr_lines[i].rs         = $signed(Registers[instr_lines[i].Ir[25:21]]);
      instr_lines[i].rt         = $signed(Registers[instr_lines[i].Ir[20:16]]);
      instr_lines[i].rd         = $signed(Registers[instr_lines[i].Ir[15:11]]);
    end
                                                    
    else if ((instr_lines[i].opcode==intf.add_imm) ||(instr_lines[i].opcode==intf.sub_imm) ||(instr_lines[i].opcode==intf.mul_imm) ||(instr_lines[i].opcode==intf.or_imm) ||(instr_lines[i].opcode==intf.and_lmm) ||(instr_lines[i].opcode==intf.xor_Imm) || (instr_lines[i].opcode==intf.load_reg) || (instr_lines[i].opcode==intf.store_reg) )
    begin                                     
      instr_lines[i].imm        = $signed(instr_lines[i].Ir[15:0]);
      instr_lines[i].src1     = instr_lines[i].Ir[25:21];
      instr_lines[i].src2     = instr_lines[i].Ir[20:16];
      instr_lines[i].source_reg1 = instr_lines[i].Ir[25:21];
      instr_lines[i].dest_reg     = instr_lines[i].Ir[20:16];
      instr_lines[i].source_reg2  = 32'hffff;
      instr_lines[i].rs         = $signed(Registers[instr_lines[i].Ir[25:21]]);
      instr_lines[i].rt         = $signed(Registers[instr_lines[i].Ir[20:16]]);
    end

    else if ((instr_lines[i].opcode== intf.bz))
    begin
      instr_lines[i].src1     = instr_lines[i].Ir[25:21];
      instr_lines[i].branch_target     = $signed(instr_lines[i].Ir[15:0]);
      instr_lines[i].rs         = $signed(Registers[instr_lines[i].Ir[25:21]]);
      instr_lines[i].source_reg1 = instr_lines[i].Ir[25:21];
      instr_lines[i].dest_reg    = 32'hffff;
      instr_lines[i].source_reg2  = 32'hffff;
    end

    else if ((instr_lines[i].opcode== intf.Beq))
    begin
      instr_lines[i].src1     = instr_lines[i].Ir[25:21];
      instr_lines[i].src2     = instr_lines[i].Ir[20:16];
      instr_lines[i].branch_target     = $signed(instr_lines[i].Ir[15:0]);	                  
      instr_lines[i].source_reg1 = instr_lines[i].Ir[25:21];
      instr_lines[i].source_reg2= instr_lines[i].Ir[20:16];
      instr_lines[i].dest_reg  = 32'hffff;           
      instr_lines[i].rs         =$signed( Registers[instr_lines[i].Ir[25:21]]);
      instr_lines[i].rt         = $signed(Registers[instr_lines[i].Ir[20:16]]);
    end

    else if ((instr_lines[i].opcode== intf.Jmp ))
    begin
      instr_lines[i].src1     = instr_lines[i].Ir[25:21];                          
      instr_lines[i].rs         = $signed(Registers[instr_lines[i].Ir[25:21]]);
      instr_lines[i].source_reg1 = instr_lines[i].Ir[25:21];
      instr_lines[i].dest_reg    = 32'hffff;
      instr_lines[i].source_reg2  = 32'hffff;
    end


    else
    begin
      instr_lines[i].rd         = 0;
      instr_lines[i].rs         = 0;
      instr_lines[i].rt         = 0;
      instr_lines[i].dest       = 0;
      instr_lines[i].src1       = 0;
      instr_lines[i].src2         = 0;
      instr_lines[i].source_reg1 =  32'hffff;
      instr_lines[i].dest_reg   = 32'hffff;
      instr_lines[i].source_reg2= 32'hffff;
    end
  endtask
  
  function int check_decode_stall(int add);
    intf.hit=0;
    for(int i=0; i<5; i++)
    begin
        if( ( ( instr_lines[add].source_reg1== instr_lines[i].dest_reg) || ( instr_lines[add].source_reg2== instr_lines[i].dest_reg) )    &&  ( instr_lines[i].dest_reg != 32'hffff )  && pipeline_stage[i]==4'd2 && branch_taken==0 && temp==0 ) 
        begin   intf.hit=1;  break  ;    end                       
    end       

    for(int i=0; i<5; i++)  
    begin
      if ( ( ( instr_lines[add].source_reg1== instr_lines[i].dest_reg) || ( instr_lines[add].source_reg2== instr_lines[i].dest_reg) )   &&  ( instr_lines[i].dest_reg != 32'hffff )  && pipeline_stage[i]==4'd3 && intf.hit !=1 &&  branch_taken==0 && temp==0) 
      begin
        intf.hit=2;
        break;
      end    
    end
    if(intf.hit==0) begin  return 0; end
    else if (intf.hit==1) return 2;
    else if (intf.hit ==2) return 1 ;
  endfunction
  
  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      for(i=0; i<5; i++)
      begin
        if(pipeline_stage[i]==4'd2)
        begin
          pipeline_stage[i]<=3;
          if(branch_taken ==0 )
          begin   
            case(instr_lines[i].opcode)
              intf.add:    ADD(instr_lines[i].rs, instr_lines[i].rt, instr_lines[i].result );
              intf.add_imm:   ADDI(instr_lines[i].rs, instr_lines[i].imm , instr_lines[i].result );
              intf.sub:     SUB(instr_lines[i].rs, instr_lines[i].rt, instr_lines[i].result );                      
              intf.sub_imm:   SUBI(instr_lines[i].rs, instr_lines[i].imm , instr_lines[i].result );                              
              intf.mul :     MUL(instr_lines[i].rs, instr_lines[i].rt, instr_lines[i].result );        
              intf.mul_imm:   MULI(instr_lines[i].rs, instr_lines[i].imm , instr_lines[i].result );                      
              intf.and_l:     AND(instr_lines[i].rs, instr_lines[i].rt, instr_lines[i].result );                     
              intf.and_lmm:   ANDI(instr_lines[i].rs, instr_lines[i].imm , instr_lines[i].result );
              intf.or_l:      OR(instr_lines[i].rs, instr_lines[i].rt, instr_lines[i].result );         
              intf.or_imm:    ORI(instr_lines[i].rs, instr_lines[i].imm , instr_lines[i].result );                  
              intf.xor_l:     XOR(instr_lines[i].rs, instr_lines[i].rt, instr_lines[i].result );                    
              intf.xor_Imm:   XORI(instr_lines[i].rs, instr_lines[i].imm , instr_lines[i].result );                  
              intf.load_reg :   instr_lines[i].ld_value =instr_lines[i].rs+instr_lines[i].imm;                  
              intf.store_reg:   instr_lines[i].st_value= instr_lines[i].rs+instr_lines[i].imm;                     
              intf.bz:      begin
                            if(instr_lines[i].rs==0)  
                            begin    
                              PC <= (instr_lines[i].branch_target*4 )+instr_lines[i].pc_value;  branch_taken<=1;temp=1; intf.branch_count= intf.branch_count +1;  
                            end
                          end
          
              intf.Beq:    begin
                            if(instr_lines[i].rs==instr_lines[i].rt)
                            begin  
                              PC <= (instr_lines[i].branch_target*4) +instr_lines[i].pc_value ; branch_taken<=1;temp=1; intf.branch_count= intf.branch_count +1; 
                            end
                          end
          
              intf.Jmp:   begin
                            PC <=instr_lines[i].rs;
                            branch_taken<=1;temp=1; intf.branch_count= intf.branch_count +1;
                          end  
              intf.hlt:   hlt=1;                         
            endcase
          end

          else
          begin   
            instr_lines[i].opcode=6'd22; 
            intf.count=intf.count+1;
            if(intf.count>1)
            begin
              intf.count=0;
              branch_taken<=0; 
              temp=0;             
            end
          end
          break;
        end                                       
      end               
    end
  end

  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      for(i=0; i<5; i++)
      begin
      if(pipeline_stage[i]==4'd3)
        begin
          pipeline_stage[i]<=4;
          case(instr_lines[i].opcode)                                                 
            intf.load_reg :
            begin
              instr_lines[i].load_data= {memory[instr_lines[i].ld_value ],memory[instr_lines[i].ld_value +1], memory[instr_lines[i].ld_value +2], memory[instr_lines[i].ld_value +3]};
            end
            
            intf.store_reg: 
            begin
              {memory[instr_lines[i].st_value],memory[instr_lines[i].st_value+1], memory[instr_lines[i].st_value+2], memory[instr_lines[i].st_value+3]}=instr_lines[i].rt;
            end
          endcase
          break;
        end
      end
    end
  end

  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      for(i=0; i<5; i++)
      begin
        if(pipeline_stage[i]==4'd4)

        begin
          if(instr_lines[i].opcode <= 6'd18)
          Total_instr_count =Total_instr_count+1;  
          pipeline_stage[i]<=0;
          case(instr_lines[i].opcode) 
            intf.add:   begin  Registers[instr_lines[i].dest] = instr_lines[i].result;  end                
            intf.add_imm: begin   Registers[instr_lines[i].src2] = instr_lines[i].result; end                       
            intf.sub:     Registers[instr_lines[i].dest] = instr_lines[i].result;                 
            intf.sub_imm:   Registers[instr_lines[i].src2] = instr_lines[i].result;                                 
            intf.mul:     Registers[instr_lines[i].dest] = instr_lines[i].result;                                                
            intf.mul_imm:   Registers[instr_lines[i].src2] = instr_lines[i].result;                        
            intf.or_l:      Registers[instr_lines[i].dest] = instr_lines[i].result;                         
            intf.or_imm:    Registers[instr_lines[i].src2] = instr_lines[i].result;                    
            intf.and_l:     Registers[instr_lines[i].dest] = instr_lines[i].result;                        
            intf.and_lmm:   Registers[instr_lines[i].src2] = instr_lines[i].result;                          
            intf.xor_l:     Registers[instr_lines[i].dest] = instr_lines[i].result;           
            intf.xor_Imm:   Registers[instr_lines[i].src2] = instr_lines[i].result;                      
            intf.load_reg:   Registers[instr_lines[i].src2] = instr_lines[i].load_data;                                                  
            intf.hlt:    begin done<=1;  end                                          
          endcase
          break;                       
        end
      end
    end
  end
  
  always@(posedge intf.CLOCK)
  begin
    if(done==0)
      count_cycles=count_cycles+1;
    if(decode_wait && hlt==0)
      total_stall=total_stall+1;
  end
  
 
  task ADD (input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ; c=a+b ;    endtask
  task ADDI (input bit signed [intf.REGISTER_WIDTH-1:0]a , input  bit signed  [15:0]b , output  bit signed  [intf.REGISTER_WIDTH-1:0]c ) ; c=a+b;  endtask
  task SUB (input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed  [intf.REGISTER_WIDTH-1:0]c ) ;   c=a-b;  endtask
  task SUBI (input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a-b;  endtask
  task MUL (input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a*b;   endtask
  task MULI (input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ; c=a*b;  endtask
  task OR (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ;   c=a|b;  endtask
  task ORI (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [15:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ;  c=a|b;  endtask
  task AND (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ;  c=a&b;  endtask
  task ANDI (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [15:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a&b;  endtask
  task XOR (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [intf.REGISTER_WIDTH-1:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a^b;  endtask
  task XORI (input bit [intf.REGISTER_WIDTH-1:0]a , input bit [15:0]b , output bit [intf.REGISTER_WIDTH-1:0]c ) ; c=a^b;  endtask

  endmodule
