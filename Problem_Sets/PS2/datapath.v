module TOP;

   reg d, we;
   wire q, qb;
   
   initial
      begin
	 
	 d = 0;
	 we = 0;
	 
	 #1
	    we = 1;
	 #1
	    we = 0;
	 
	 #1
	    d = 1;
	 #1
	    we = 1;
	 
	 #1
	    d = 0;
	 #1
	    d = 1;
	 #1
	    d = 0;
	 #0.8
	    we = 0;
	 
      end
   
   // Run simulation for 15 ns.  
   initial #15 $finish;
   
   // Dump all waveforms to d_latch.dump.vpd
   initial
      begin
	 //$dumpfile ("d_latch.dump");
	 //$dumpvars (0, TOP);
	 $vcdplusfile("d_latch.dump.vpd");
	 $vcdpluson(0, TOP); 
      end // initial begin
   
   always @(posedge d)
      $strobe ("at time %0d, wen = %b", $time, we);
   
   d_latch latch1 (d, q, qb, we);
   
endmodule

//---------------------------------------------------------
// Datapath responsible for address generation and execution
// Assumes: decoded instruction
module agex_datapath (clk, modrm, disp, imm);

input clk;

input modrm[7:0];
wire [1:0] mod;
wire [2:0] opcode_reg, rm;
assign mod = modrm[7:6];
assign opcode_reg = modrm[5:3];
assign rm = modrm[2:0];

input [31:0] disp;
wire [7:0] disp8;
wire [31:0] disp32, disp8_sext;
assign disp8 = disp[31:24];
assign disp32 = disp;
sext_8 sext_disp8(disp8, disp8_sext);

input [31:0] imm;
wire [7:0] imm8;
wire [31:0] imm32, imm8_sext;
assign imm8 = imm[31:24];
assign imm32 = imm;
sext_8 sext_imm8(imm8, imm8_sext);

wire [31:0] MEM_BUS;
wire post_instruction_pointer_bar;

// register components
wire [31:0] sr1, sr2;
wire [2:0] sr1_select, sr2_select, dr_select;
assign dr_select = sr1_select;
wire sr1_re, sr2_re, dr_we;

// bus wires
wire [31:0] gen_addr_out;

// gates
bus_gate()

registers regfile(MEM_BUS, sr1_select, sr2_select, sr1_re, sr2_re, dr_select, dr_we, sr1, sr2, clk);




endmodule

//---------------------------------------------------------
// Mapping of x86 register R0-R7 := [EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI]
// 
//used modules: regfile8x8$(IN0,R1,R2,RE1,RE2,W,WE,OUT1,OUT2,CLOCK), double read reg
module registers (IN0, R1, R2, RE1, RE2, W, WE, OUT1, OUT2, CLOCK);

input [31:0] IN0;           // write data
input [2:0] R1, R2, W;     // read1, read2, write select
input RE1, RE2, WE;         // read1, read2, write enable
output [31:0] OUT1, OUT2;   // read data
input CLOCK;


regfile8x8$ low(IN0[7:0], R1, R2, RE1, RE2, W, WE, OUT1[7:0], OUT2[7:0], CLOCK);
regfile8x8$ high(IN0[15:8], R1, R2, RE1, RE2, W, WE, OUT1[15:8], OUT2[15:8], CLOCK);
regfile8x8$ e_low(IN0[23:16], R1, R2, RE1, RE2, W, WE, OUT1[23:16], OUT2[23:16], CLOCK);
regfile8x8$ e_high(IN0[31:24], R1, R2, RE1, RE2, W, WE, OUT1[31:24], OUT2[31:24], CLOCK);    
endmodule


module sext_8(in, out);
input [7:0] in;
output [31:0] out;

wire [31:0] temp_out;
assign temp_out[7:0] = in;
assign out = temp_out;

assign sign_bit = in[7];
genvar i;
generate
    for (i = 31; i > 7; i = i - 1) : sign_extension
    begin
        temp_out[i] = sign_bit;
    end
endgenerate
endmodule


module gen_addr (sr1, disp8_sext, disp32, address_out);
input [31:0] sr1, disp8_sext, disp32;
output [31:0] address_out;

wire [31:0] left_temp, left_in, right_in

mux2_32 left_in_mux0(left_temp, disp8_sext, disp32, <SELECT>);
mux2_32 left_in_mux1(left_in, 'b0, left_temp, <SELECT>);
mux2_32 right_in_mux(right_in, 'b0, sr1, <SELECT>);

adder_32 address_adder(left_in, right_in, out);    
endmodule


module adder_32 (src1, src2, out);
input [31:0] src1, src2;
output [31:0] out;



// TODO, implement structurally
always @(sr1, src2)
    out = sr1 + src2;
    
endmodule


module mux2_32 (out, in0, in1, s);
input [31:0] in0, in1;
output [31:0] out;

mux2_16 low(out[15:0], in0[15:0], in1[15:0], s);
mux2_16 high(out[31:16], in0[31:16], in1[31:16], s);
endmodule

module bus_gate (enable, d, out);
wire enbar;
inv1$ inv_enable (enbar, enable);
tristate_bus_driver16 low(enbar, d[15:0], out[15:0]);
tristate_bus_driver16 high(enbar, d[31:16], out[31:16]);
endmodule
