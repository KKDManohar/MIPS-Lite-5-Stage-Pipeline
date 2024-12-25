module top_tb();
    bit done1;//for without pipeline
    bit done2;//for pipelined with forwarding
    bit done3;//for pipelined without forwarding
    bit clock=0;
	r_intf intf();
    without_pipeline w_p1(done1);
    pipelined_without_forwarding pwf(done2);
    pipelined_with_forwarding pf(done3);

    always #10 clock=~clock;

    always@(posedge clock)
    begin
        if(done1 && done2 && done3)
        $finish();
    end

    final
    begin
        $display("*************** Without Pipeline Statistics ****************");
        $display("____________________________________________________________");
        $display("Total Number of Instructions               : %d" , w_p1.Total_instr_count );
        $display("Arithmetic Instructions                    : %d" , w_p1.Arth_Instr_count );
        $display("Logical Instructions                       : %d" , w_p1.Log_Instr_count );
        $display("Memory Access Instructions                 : %d" , w_p1.memory_count );
        $display("Control Tranfer Instructions               : %d\n" , w_p1.branches + 1); // +1 is to include halt instruction
        $display("Final Register Stage:\n");
        $display("Program Counter                            : %d\n" , w_p1.PC );
        foreach(w_p1.register_array[i])
        begin
        if(w_p1.register_array[i]==1)
            $display("The data of R%0d                   : %d" ,i, w_p1.Registers[i]);
        end
        $display("\nThe number of Branches taken               : %d" , w_p1.branch_taken);

        $display("The number of clock cycles                 : %d" , w_p1.cycles_count);

        foreach(w_p1.memory_array[i])
        begin
            if(w_p1.memory_array[i]==1)
            $display("Contents of Memory Address[%0d] is : %d" ,i, {w_p1.memory[i], w_p1.memory[i+1],w_p1.memory[i+2],w_p1.memory[i+3] });
        end
        $display("____________________________________________________________");
        $display("********Pipelined MIPS without forwarding statistics********");
        $display("____________________________________________________________");
        $display("Total number of clock cycles without forwarding : %d" , pwf.count_cycles );
        $display("Total stall cycles without forwarding           : %d" , pwf.total_stall );
        $display("Total number of Data Hazards                    : %d" , pwf.stall);

        $display("____________________________________________________________");
        $display("*********Pipelined MIPS with forwarding statistics**********");
        $display("____________________________________________________________");
        $display("Total number of clock cycles with forwarding    : %d" , pf.count_cycles );
        $display("Total number of stalls with forwarding          : %d" , pf.stall_raw );
        $display("Total number of Data Hazards                    : %d" , pf.stall_raw );
    end
endmodule
