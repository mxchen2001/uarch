module TOP;
	reg clk = 1;
	reg [1:0] mod;
	reg [2:0] opcode_reg, rm; 
	reg [31:0] disp, imm;

	wire [7:0] modrm = {mod, opcode_reg, rm};
	reg gate_eip, gate_sr1, gate_addr_gen;

	reg clr_eip, pre_eip, en_eip;
	reg [1:0] eip_disp_mux_s, eip_mux_s;

	reg sr1_mux_s;
	reg [1:0] alu_shf_mux_s, sr2_mux_s, aluk;
	reg clr_alu_shf, pre_alu_shf, en_alu_shf;

	wire [31:0] sr1, sr2;
	reg [2:0] dr_select, sr1_select, sr2_select;
	reg sr1_re, sr2_re, dr_we;

	reg gate_alu;
	reg test_gate;
	reg [31:0] test_gate_d;
	wire [31:0] MEM_BUS;
	
   	initial
	begin
		// testing: ADD EBX, [EBP + disp32]
		mod = 'b10;
		opcode_reg = 'b011;
		rm = 'b101;
		aluk = 'b00;

		sr1_re = 'b0; 
		sr2_re = 'b0;

		gate_eip = 'b0;
		gate_addr_gen = 'b0;
		gate_alu = 'b0;
		gate_sr1 = 'b0;
		disp = 32'h00ff00ff;
		imm = 32'h1234abcd;
		#100

		// setting default value for EBX (R2)
		test_gate = 'b1;
		test_gate_d = 32'hcccccccc;
		dr_select = 'b011;
		#5
		dr_we = 'b1;
		#190
		test_gate = 'b0;
		dr_we = 'b0;
		#5

		// setting default value for EBP (R5)
		test_gate = 'b1;
		test_gate_d = 32'hb234abcd;
		dr_select = 'b101;
		#5
		dr_we = 'b1;
		#190
		test_gate = 'b0;
		dr_we = 'b0;
		#5


		// loading the evaluated address to memory
		sr1_select = 'b101;
		sr1_re = 'b1;
		gate_addr_gen = 'b1;
		#100
		sr1_re = 'b0;
		gate_addr_gen = 'b0;
		if (MEM_BUS == 'hb333accc)
			$strobe ("at time %0d, bus value matched", $time);

		// memory access, lets say ~ 3 clk
		#300

		// load into ALU_R
		test_gate = 'b1;
		test_gate_d = 32'h0123beef;
		#5
		en_alu_shf = 'b1;
		alu_shf_mux_s = 'b11;
		clr_alu_shf = 'b1; 
		pre_alu_shf = 'b1;
		#190
		test_gate = 'b0;
		en_alu_shf = 'b0;
		#5

		// write back
		dr_select = 'b011;
		sr2_select = 'b011;
		sr2_re = 'b1;
		gate_alu = 'b1;
		sr1_mux_s = 'b1;
		sr2_mux_s = 'b00;
		#5
		dr_we = 'b1;
		#95
		gate_alu = 'b0;
		#95
		dr_we = 'b0;
		#5


		gate_eip = 'b0;
		gate_sr1 = 'b0;
		gate_addr_gen = 'b0;
	end
   
   	// Run simulation for 15 ns.  
   	initial #4000 $finish;
	
   	// Dump all waveforms to d_latch.dump.vpd
   	initial
	begin
		//$dumpfile ("d_latch.dump");
		//$dumpvars (0, TOP);
		$vcdplusfile("datapath.dump.vpd");
		$vcdpluson(0, TOP); 
	end // initial begin
   	bus_gate test(test_gate, test_gate_d, MEM_BUS);
   	agex_datapath agex (clk, modrm, disp, imm,
						eip_disp_mux_s, eip_mux_s, gate_eip,
						clr_eip, pre_eip, en_eip,
						sr1, sr2,
						gate_addr_gen,
						alu_shf_mux_s, sr1_mux_s, sr2_mux_s, aluk,
						clr_alu_shf, pre_alu_shf, en_alu_shf,
						gate_alu,
						MEM_BUS
						);
	register_structure reg_struct (gate_sr1, 
								   dr_select, sr1_select, sr2_select,
								   sr1_re, sr2_re, dr_we,
								   sr1, sr2, 
								   MEM_BUS, clk
								   );

	always
		#50 clk = ~clk;
   
endmodule

module register_structure (
	gate_sr1, 
	dr_select, sr1_select, sr2_select,
	sr1_re, sr2_re, dr_we,
	sr1, sr2,
	MEM_BUS, clk
);
input clk;
input gate_sr1;
input sr1_re, sr2_re, dr_we;
input [2:0] dr_select, sr1_select, sr2_select;
input [31:0] MEM_BUS; 
output [31:0] sr1, sr2;

wire [2:0]dr_select;
bus_gate sr1_gate(gate_sr1, sr1, MEM_BUS);
regfile8x32 regfile(MEM_BUS, sr1_select, sr2_select, sr1_re, sr2_re, dr_select, dr_we, sr1, sr2, clk);	
endmodule

//---------------------------------------------------------
// Datapath responsible for address generation and execution
// Assumes: decoded instruction
module agex_datapath (clk, modrm, disp, imm,
eip_disp_mux_s, eip_mux_s, gate_eip,
clr_eip, pre_eip, en_eip,
sr1, sr2,
gate_addr_gen,
alu_shf_mux_s, sr1_mux_s, sr2_mux_s, aluk,
clr_alu_shf, pre_alu_shf, en_alu_shf,
gate_alu,
MEM_BUS
);

input clk;
inout [31:0] MEM_BUS;

input [7:0] modrm;
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

input [31:0] sr1, sr2;

// EIP
input [1:0] eip_disp_mux_s, eip_mux_s;
input gate_eip;
wire eip_disp_mux_s0, eip_disp_mux_s1, eip_mux_s0, eip_mux_s1;
assign eip_disp_mux_s0 = eip_disp_mux_s[0];
assign eip_disp_mux_s1 = eip_disp_mux_s[1];
assign eip_mux_s0 = eip_mux_s[0];
assign eip_mux_s1 = eip_mux_s[1];
input clr_eip, pre_eip, en_eip;
wire [31:0] eip_d, eip_dbar;
wire [31:0] eip_in, eip_disp_cal, eip_disp_ret;
mux4_32 eip_disp_mux (eip_disp_cal, 'b1, 'b1, disp8_sext, disp32, eip_disp_mux_s0, eip_disp_mux_s1);
mux4_32 eip_mux (eip_in, eip_disp_ret, sr1, imm32, MEM_BUS, eip_mux_s0, eip_mux_s1);
adder_32 eip_disp_adder (eip_disp_ret, eip_disp_cal, eip_d);
reg32e$ EIP (clk, eip_in, eip_d, eip_dbar, clr_eip, pre_eip, en_eip);
bus_gate eip_gate (gate_eip, eip_d, MEM_BUS);

// address generation
input gate_addr_gen;
wire [31:0] gen_addr_out;
bus_gate address_gen_gate(gate_addr_gen, gen_addr_out, MEM_BUS);
address_gen address_generation(sr1, disp8_sext, disp32, mod, opcode_reg, rm, gen_addr_out);

// ALU components
input [1:0] alu_shf_mux_s, sr2_mux_s, aluk;
input sr1_mux_s;
wire alu_shf_mux_s0, alu_shf_mux_s1, sr2_mux_s0, sr2_mux_s1;
assign alu_shf_mux_s0 = alu_shf_mux_s[0];
assign alu_shf_mux_s1 = alu_shf_mux_s[1];
assign sr2_mux_s0 = sr2_mux_s[0];
assign sr2_mux_s1 = sr2_mux_s[1];

input clr_alu_shf, pre_alu_shf, en_alu_shf;
wire [31:0] alu_shf_in, alu_shf_d, alu_shf_dbar;
mux4_32 alu_shf_mux (alu_shf_in, 'b0, 'b1, sr2, MEM_BUS, alu_shf_mux_s0, alu_shf_mux_s1);
reg32e$ ALU_SHF_R (clk, alu_shf_in, alu_shf_d, alu_shf_dbar, clr_alu_shf, pre_alu_shf, en_alu_shf);

input gate_alu;
wire [31:0] left_in_alu, right_in_alu, alu_out;
mux2_32 sr1_mux (right_in_alu, sr1, alu_shf_d, sr1_mux_s);
mux4_32 sr2_mux (left_in_alu, sr2, imm32, imm8_sext, alu_shf_d, sr2_mux_s0, sr2_mux_s1);
ALU_SHF alu_shf_unit (aluk, right_in_alu, left_in_alu, alu_out);
bus_gate alu_gate(gate_alu, alu_out, MEM_BUS);
endmodule

//---------------------------------------------------------
// Mapping of x86 register R0-R7 := [EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI]
// 
//used modules: regfile8x8$(IN0,R1,R2,RE1,RE2,W,WE,OUT1,OUT2,CLOCK), double read reg
module regfile8x32 (IN0, R1, R2, RE1, RE2, W, WE, OUT1, OUT2, CLOCK);

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

wire sign_bit;
assign sign_bit = in[7];
genvar i;
generate
    for (i = 31; i > 7; i = i - 1) begin : sign_extension
        assign temp_out[i] = sign_bit;
    end
endgenerate
endmodule


module address_gen (sr1, disp8_sext, disp32, mod, opcode_reg, rm, address_out);
input [31:0] sr1, disp8_sext, disp32;
output [31:0] address_out;
input [1:0] mod;
input [2:0] opcode_reg, rm;

wire [31:0] left_temp, left_in, right_in;
wire l0_select, l1_select, r_select;

effective_address_LUT select_LUT(mod, opcode_reg, rm, l0_select, l1_select, r_select);

mux2_32 left_in_mux0(left_temp, disp8_sext, disp32, l0_select);
mux2_32 left_in_mux1(left_in, 'b0, left_temp, l1_select);
mux2_32 right_in_mux(right_in, 'b0, sr1, r_select);

adder_32 address_adder(address_out, left_in, right_in);
endmodule


module adder_32 (out, src1, src2);
input [31:0] src1, src2;
output [31:0] out;

// TODO, implement structurally
reg [31:0] out_temp;
assign out = out_temp;
always @(src1, src2)
    out_temp = src1 + src2;
endmodule

module effective_address_LUT (mod, opcode_reg, rm, l0, l1, r);
input [1:0] mod;
input [2:0] opcode_reg, rm;

reg l0_temp, l1_temp, r_temp;
assign l0 = l0_temp;
assign l1 = l1_temp;
assign r = r_temp;

// TODO, implement structurally
output l0, l1, r;
always @(mod, opcode_reg, rm) begin
	if (mod == 'b00) begin
		if (rm == 'b101) begin
			l0_temp <= 'b1;
			l1_temp <= 'b1;
			r_temp <= 'b0;
		end else begin
			l0_temp <= 'b0;
			l1_temp <= 'b0;
			r_temp <= 'b1;
		end
	end else begin
			l1_temp <= 'b1;
			r_temp <= 'b1;
		if (mod == 'b01)
			l0_temp <= 'b0;
		else
			l0_temp <= 'b1;
	end
end
endmodule


module mux2_32 (out, in0, in1, s);
input [31:0] in0, in1;
input s;
output [31:0] out;

mux2_16$ low(out[15:0], in0[15:0], in1[15:0], s);
mux2_16$ high(out[31:16], in0[31:16], in1[31:16], s);
endmodule

module mux4_32 (out, in0, in1, in2, in3, s0, s1);
input [31:0] in0, in1, in2, in3;
input s0, s1;
output [31:0] out;

mux4_16$ low(out[15:0], in0[15:0], in1[15:0], in2[15:0], in3[15:0], s0, s1);
mux4_16$ high(out[31:16], in0[31:16], in1[31:16], in2[31:16], in3[31:16], s0, s1);
endmodule

module bus_gate (enable, d, out);
input enable;
input [31:0] d;
output [31:0] out;

wire enbar;
inv1$ inv_enable (enbar, enable);
tristate_bus_driver16$ low(enbar, d[15:0], out[15:0]);
tristate_bus_driver16$ high(enbar, d[31:16], out[31:16]);
endmodule

// 00 == add
// 01 == or
// 11 == right shift
module ALU_SHF (control, sr1, sr2, out);
	// TODO make structural
	input [1:0] control;
	input [31:0] sr1, sr2;
	output reg [31:0] out;
	always @(control, sr1, sr2) begin
		case (control)
			2'b00: out <= sr1 + sr2;
			2'b01: out <= sr1 | sr2;
			2'b11: out <= sr1 >> sr2;
			default: out <= sr1;
		endcase
	end
endmodule
