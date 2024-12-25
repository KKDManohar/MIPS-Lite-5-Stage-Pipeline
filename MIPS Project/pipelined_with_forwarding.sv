module pipelined_with_forwarding(output bit done);
  import instructions::*;
  r_intf intf();

  instruction_set Instr_line[5];

  int Total_intsr_count;
  bit branch_taken;
  bit signed [31:0]Registers[32];
  bit signed [7:0]memory[4096];
  bit signed [31:0]PC;

  int i=0;
  int stall_raw;
  int count_cycles;


  initial begin : file_descriptor_block
    $display("File Descriptor initialized!");
    intf.fd = $fopen("./sample_memory_image.txt", "r");
    if(intf.fd==0)
      disable file_descriptor_block;
    while (!($feof(intf.fd))) 
    begin
      $fscanf(intf.fd, "%32h",{memory[i], memory[i+1], memory[i+2], memory[i+3]});
      i=i+4;
    end
    #20;
    $fclose(intf.fd);
  end : file_descriptor_block

  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      if(intf.fetch_wait==0) 
      begin
        for(int i=0; i<5; i++)
        begin
          if(intf.pipeline_stage[i]==0 )
          begin		         
            intf.pipeline_stage[i] <=1;
            Instr_line[i].Ir ={memory[PC], memory[PC+1], memory[PC+2], memory[PC+3] }  ;
            Instr_line[i].pc_value     = PC;
            PC=PC+4;
            break;
          end
        end
      end
    end
  end


  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      #0;
      for(int i=0; i<5; i++)
      begin
        if(intf.pipeline_stage[i]==4'd1)
        begin
          decode_stage(i) ;                            
          intf.decode_stall = check_decode_stall(i);
          if(intf.decode_stall==1)
          begin
            stall_raw=stall_raw+1;
            intf.fetch_wait <=1;
            @(posedge intf.CLOCK);
            intf.fetch_wait<=0;
            decode_stage(i) ; 
          end
          intf.pipeline_stage[i]<=2;                         
          break;
        end
      end
    end
  end
  
  task decode_stage(int i);
    Instr_line[i].opcode = Instr_line[i].Ir[31:26];
    if ( (Instr_line[i].opcode==intf.add) || (Instr_line[i].opcode==intf.sub) ||   (Instr_line[i].opcode==intf.mul) || (Instr_line[i].opcode==intf.or_l) ||(Instr_line[i].opcode==intf.and_l) ||(Instr_line[i].opcode==intf.xor_l))
    begin       
      Instr_line[i].src1     = Instr_line[i].Ir[25:21];
      Instr_line[i].src2     = Instr_line[i].Ir[20:16];
      Instr_line[i].dest     = Instr_line[i].Ir[15:11];
      Instr_line[i].source_reg1 = Instr_line[i].Ir[25:21];
      Instr_line[i].source_reg2     = Instr_line[i].Ir[20:16];
      Instr_line[i].dest_reg     = Instr_line[i].Ir[15:11];
      Instr_line[i].rs         = $signed(Registers[Instr_line[i].Ir[25:21]]);
      Instr_line[i].rt         = $signed(Registers[Instr_line[i].Ir[20:16]]);
      Instr_line[i].rd         = $signed(Registers[Instr_line[i].Ir[15:11]]);
    end
                                                    
  else if ((Instr_line[i].opcode==intf.add_imm) ||(Instr_line[i].opcode==intf.sub_imm) ||(Instr_line[i].opcode==intf.mul_imm) ||(Instr_line[i].opcode==intf.or_imm) ||(Instr_line[i].opcode==intf.and_lmm) ||(Instr_line[i].opcode==intf.xor_Imm) || (Instr_line[i].opcode==intf.load_reg) || (Instr_line[i].opcode==intf.store_reg))
  begin                                     
    Instr_line[i].imm        = $signed(Instr_line[i].Ir[15:0]);
    Instr_line[i].src1     = Instr_line[i].Ir[25:21];
    Instr_line[i].src2     = Instr_line[i].Ir[20:16];
    Instr_line[i].source_reg1 = Instr_line[i].Ir[25:21];
    Instr_line[i].dest_reg     = Instr_line[i].Ir[20:16];
    Instr_line[i].source_reg2  = 32'hffff;
    Instr_line[i].rs         = $signed(Registers[Instr_line[i].Ir[25:21]]);
    Instr_line[i].rt         = $signed(Registers[Instr_line[i].Ir[20:16]]);
  end

  else if ((Instr_line[i].opcode== intf.bz))
  begin
    Instr_line[i].src1     = Instr_line[i].Ir[25:21];
    Instr_line[i].branch_target     = $signed(Instr_line[i].Ir[15:0]);
    Instr_line[i].rs         = $signed(Registers[Instr_line[i].Ir[25:21]]);
    Instr_line[i].source_reg1 = Instr_line[i].Ir[25:21];
    Instr_line[i].dest_reg    = 32'hffff;
    Instr_line[i].source_reg2  = 32'hffff;
  end

  else if ((Instr_line[i].opcode== intf.Beq))
  begin
    Instr_line[i].src1     = Instr_line[i].Ir[25:21];
    Instr_line[i].src2     = Instr_line[i].Ir[20:16];
    Instr_line[i].branch_target     = $signed(Instr_line[i].Ir[15:0]);	                  
    Instr_line[i].source_reg1 = Instr_line[i].Ir[25:21];
    Instr_line[i].source_reg2= Instr_line[i].Ir[20:16];
    Instr_line[i].dest_reg  = 32'hffff;           
    Instr_line[i].rs         = $signed(Registers[Instr_line[i].Ir[25:21]]);
    Instr_line[i].rt         = $signed(Registers[Instr_line[i].Ir[20:16]]);
  end

  else if ((Instr_line[i].opcode== intf.Jmp))
  begin
    Instr_line[i].src1     = Instr_line[i].Ir[25:21];                          
    Instr_line[i].rs         = $signed(Registers[Instr_line[i].Ir[25:21]]);
    Instr_line[i].source_reg1 = Instr_line[i].Ir[25:21];
    Instr_line[i].dest_reg    = 32'hffff;
    Instr_line[i].source_reg2  = 32'hffff;
  end
  else
  begin
      Instr_line[i].rd         = 0;
      Instr_line[i].rs         = 0;
      Instr_line[i].rt         = 0;
      Instr_line[i].dest     = 0;
      Instr_line[i].src1     = 0;
      Instr_line[i].src2     = 0;
      Instr_line[i].source_reg1 =  32'hffff;
      Instr_line[i].dest_reg    = 32'hffff;
      Instr_line[i].source_reg2  = 32'hffff;
    end
  endtask

 function int check_decode_stall(int add );
  for(int i=0; i<5; i++)
  begin
    if( ( ( Instr_line[add].source_reg1== Instr_line[i].dest_reg) || ( Instr_line[add].source_reg2== Instr_line[i].dest_reg) )    &&  ( Instr_line[i].dest_reg != 32'hffff )  && intf.pipeline_stage[i]==4'd2 && branch_taken==0 &&  Instr_line[i].opcode == 6'd12  ) 
    begin    intf.hit=1;  break  ;    end                       
  end    
  if(intf.hit==1) begin intf.hit=0;  return 1; end 
  else  return 0 ;           
 endfunction

  always@(posedge intf.CLOCK)
  begin
    if(done==0)
    begin
      for(i=0; i<5; i++)
      begin
        if(intf.pipeline_stage[i]==4'd2)
        begin
          Instr_line[i].rs=$signed(intf.Updated_Registers[Instr_line[i].src1]);
          Instr_line[i].rt=$signed(intf.Updated_Registers[Instr_line[i].src2]);
          Instr_line[i].rd=$signed(intf.Updated_Registers[Instr_line[i].dest]);                                                 
          intf.pipeline_stage[i]<=3;
          if(branch_taken ==0 )
          begin   
            case(Instr_line[i].opcode)

              intf.add :    begin  
                                  ADD(Instr_line[i].rs, Instr_line[i].rt, Instr_line[i].result ); 
                                  intf.Updated_Registers[Instr_line[i].dest] =  $signed(Instr_line[i].result) ;              
                                end
              
              intf.add_imm:  begin 
                                    ADD_imm(Instr_line[i].rs, Instr_line[i].imm , Instr_line[i].result );
                                    intf.Updated_Registers[Instr_line[i].src2] =  $signed(Instr_line[i].result) ;               
                                  end
              
              intf.sub:    begin 
                                    SUB(Instr_line[i].rs, Instr_line[i].rt, Instr_line[i].result );
                                    intf.Updated_Registers[Instr_line[i].dest] =  $signed(Instr_line[i].result) ;              
                                  end
                                        
              intf.sub_imm:  begin 
                                      SUB_imm(Instr_line[i].rs, Instr_line[i].imm , Instr_line[i].result );
                                      intf.Updated_Registers[Instr_line[i].src2] =  $signed(Instr_line[i].result) ;               
                                    end
                                          
              intf.mul:   begin 
                                      MUL(Instr_line[i].rs, Instr_line[i].rt, Instr_line[i].result );
                                      intf.Updated_Registers[Instr_line[i].dest] =  $signed(Instr_line[i].result) ;               
                                    end
              
              intf.mul_imm:begin 
                                        MUL_imm(Instr_line[i].rs, Instr_line[i].imm , Instr_line[i].result );
                                        intf.Updated_Registers[Instr_line[i].src2] =  $signed(Instr_line[i].result) ;              
                                      end
                                        
              intf.or_l:    begin   
                              OR(Instr_line[i].rs, Instr_line[i].rt, Instr_line[i].result );
                              intf.Updated_Registers[Instr_line[i].dest] =  $signed(Instr_line[i].result) ;              
                            end
                      
              intf.or_imm:   begin 
                              OR_imm(Instr_line[i].rs, Instr_line[i].imm , Instr_line[i].result );
                              intf.Updated_Registers[Instr_line[i].src2] =  $signed(Instr_line[i].result );               
                            end
                                        
              intf.and_l:    begin  
                              AND(Instr_line[i].rs, Instr_line[i].rt, Instr_line[i].result );
                              intf.Updated_Registers[Instr_line[i].dest] =  $signed(Instr_line[i].result) ;              
                            end
                                          
              intf.and_lmm:   begin 
                              AND_imm(Instr_line[i].rs, Instr_line[i].imm , Instr_line[i].result );
                              intf.Updated_Registers[Instr_line[i].src2] =  $signed(Instr_line[i].result );               
                            end
                                        
              intf.xor_l:    begin  
                              XOR(Instr_line[i].rs, Instr_line[i].rt, Instr_line[i].result );
                              intf.Updated_Registers[Instr_line[i].dest] =  $signed(Instr_line[i].result) ;               
                            end
                                        
              intf.xor_Imm:   begin 
                              XOR_imm(Instr_line[i].rs, Instr_line[i].imm , Instr_line[i].result );
                              intf.Updated_Registers[Instr_line[i].src2] =  $signed(Instr_line[i].result) ;              
                            end
                                        
              intf.load_reg :   Instr_line[i].ld_value=Instr_line[i].rs+Instr_line[i].imm;
                                        
              intf.store_reg:   Instr_line[i].st_value= Instr_line[i].rs+Instr_line[i].imm;
                                        
              intf.bz: begin
                        if(Instr_line[i].rs==0)  
                        begin   
                          PC<= (Instr_line[i].branch_target*4 )+Instr_line[i].pc_value; 
                          branch_taken<=1; 
                          intf.branch_count= intf.branch_count +1;  
                        end
                      end

              intf.Beq:begin
                        if(Instr_line[i].rs==Instr_line[i].rt)
                        begin  
                          PC<= (Instr_line[i].branch_target*4) +Instr_line[i].pc_value ; 
                          branch_taken<=1; 
                          intf.branch_count= intf.branch_count +1;
                        end
                      end
              
              intf.Jmp: begin
                          PC<=Instr_line[i].rs;
                          branch_taken<=1; intf.branch_count= intf.branch_count +1;
                        end                           
            endcase
          end

          else
          begin
            Instr_line[i].opcode=6'd22; 
            intf.count=intf.count+1;
            if(intf.count>1)
            begin
              intf.count=0;
              branch_taken<=0;              
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
        if(intf.pipeline_stage[i]==4'd3)
        begin
          intf.pipeline_stage[i]<=4;
          case(Instr_line[i].opcode)                                                 
            intf.load_reg : 
            begin
              Instr_line[i].load_data= {memory[Instr_line[i].ld_value],memory[Instr_line[i].ld_value+1], memory[Instr_line[i].ld_value+2], memory[Instr_line[i].ld_value+3]};
              intf.Updated_Registers[ Instr_line[i].src2] = $signed(Instr_line[i].load_data);
            end
            
            intf.store_reg: 
            begin
              {memory[Instr_line[i].st_value],memory[Instr_line[i].st_value+1], memory[Instr_line[i].st_value+2], memory[Instr_line[i].st_value+3]}=Instr_line[i].rt;
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
        if(intf.pipeline_stage[i]==4'd4)
        begin
          if(Instr_line[i].opcode <= 6'd18)
            Total_intsr_count =Total_intsr_count+1;  
            intf.pipeline_stage[i]<=0;
            case(Instr_line[i].opcode) 
              intf.add :   Registers[Instr_line[i].dest] = Instr_line[i].result;                             
              intf.add_imm:  Registers[Instr_line[i].src2] = Instr_line[i].result;                          
              intf.sub:    Registers[Instr_line[i].dest] = Instr_line[i].result;                 
              intf.sub_imm:  Registers[Instr_line[i].src2] = Instr_line[i].result;                                
              intf.mul:    Registers[Instr_line[i].dest] = Instr_line[i].result;                                                
              intf.mul_imm:  Registers[Instr_line[i].src2] = Instr_line[i].result;                        
              intf.or_l:     Registers[Instr_line[i].dest] = Instr_line[i].result;                             
              intf.or_imm:   Registers[Instr_line[i].src2] = Instr_line[i].result;                          
              intf.and_l:    Registers[Instr_line[i].dest] = Instr_line[i].result;                           
              intf.and_lmm:  Registers[Instr_line[i].src2] = Instr_line[i].result;                               
              intf.xor_l:    Registers[Instr_line[i].dest] = Instr_line[i].result;                         
              intf.xor_Imm:  Registers[Instr_line[i].src2] = Instr_line[i].result;                         
              intf.load_reg :  Registers[Instr_line[i].src2] = Instr_line[i].load_data;                                                    
              intf.hlt:    done<=1;                                         
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
  end
  
  task ADD(input  bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;   c=a+b;  endtask
  task ADD_imm(input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a+b;  endtask
  task SUB(input  bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;   c=a-b;  endtask
  task SUB_imm(input bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a-b;  endtask
  task MUL(input  bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [intf.REGISTER_WIDTH-1:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ;  c=a*b;   endtask
  task MUL_imm(input  bit signed [intf.REGISTER_WIDTH-1:0]a , input bit signed [15:0]b , output bit signed [intf.REGISTER_WIDTH-1:0]c ) ; c=a*b;  endtask
  task OR(input   bit  [intf.REGISTER_WIDTH-1:0]a , input bit  [intf.REGISTER_WIDTH-1:0]b , output bit  [intf.REGISTER_WIDTH-1:0]c ) ;   c=a|b;  endtask
  task OR_imm(input  bit  [intf.REGISTER_WIDTH-1:0]a , input bit  [15:0]b , output bit  [intf.REGISTER_WIDTH-1:0]c ) ;  c=a|b;  endtask
  task AND(input  bit  [intf.REGISTER_WIDTH-1:0]a , input bit  [intf.REGISTER_WIDTH-1:0]b , output bit  [intf.REGISTER_WIDTH-1:0]c ) ;  c=a&b;  endtask
  task AND_imm(input bit  [intf.REGISTER_WIDTH-1:0]a , input bit  [15:0]b , output bit  [intf.REGISTER_WIDTH-1:0]c ) ; c=a&b;  endtask
  task XOR(input  bit  [intf.REGISTER_WIDTH-1:0]a , input bit  [intf.REGISTER_WIDTH-1:0]b , output bit  [intf.REGISTER_WIDTH-1:0]c ) ; c=a^b;  endtask
  task XOR_imm(input bit  [intf.REGISTER_WIDTH-1:0]a , input bit  [15:0]b , output bit  [intf.REGISTER_WIDTH-1:0]c ) ; c=a^b;  endtask

endmodule
