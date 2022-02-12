`define SR1_MUX_sr1   0
`define SR1_MUX_alu_r 1

`define SR2_MUX_sr2   0
`define SR2_MUX_imm8  1
`define SR2_MUX_imm32 2
`define SR2_MUX_alu_R 3

`define EIP_IN_MUX_adder  0
`define EIP_IN_MUX_sr1    1
`define EIP_IN_MUX_imm32  2
`define EIP_IN_MUX_bus    3

`define EIP_ADDER_MUX_1       0
`define EIP_ADDER_MUX_disp8   1
`define EIP_ADDER_MUX_disp32  2

`define GATE_NONE 0
`define GATE_ALU  1
`define GATE_SR1  2
`define GATE_SR2  3
`define GATE_EIP  4
`define GATE_AGEN 5

`define LD_NONE  'b000000
`define LD_REG   'b000001
`define LD_EIP   'b000010
`define LD_ALU_R 'b000100

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

module gate_signals_encoder(gate_type, gate_signal);
input [2:0] gate_type; 
output [5:0] gate_signal;

always @(*) begin
    case (gate)
        'h1: gate_signal = 'b00001;
        'h2: gate_signal = 'b00010;
        'h3: gate_signal = 'b00100;
        'h4: gate_signal = 'b01000;
        'h5: gate_signal = 'b10000;
        default: gate_signal = 'b00000;
    endcase
end
endmodule

module alu_signal(opcode, opcode_reg, aluk);
    input [7:0] opcode;
    input [2:0] opcode_reg; 
    output [1:0] aluk;
    always @* begin 
        case (opcode)
            'h81, 'h83: aluk = {'b0, opcode_reg[0]};
            'h01, 'h03: aluk = 'b00; 
            'h09, 'h0b: aluk = 'b01; 
            'hd1, 'hd3, 'hc1: aluk = 'b11;
            default: 
        endcase
    end
endmodule

module datapathCS (state, opcode, modrm, clk
aluk, sr1_out, sr2_out, dr_out, 
eip_adder_mux, eip_in_mux,
gate_signals, load_signalss
);

input [7:0] state, opcode, modrm;
input clk;

wire [1:0] mod;
wire [2:0] opcode_reg, rm;
assign mod = modrm[7:6];
assign opcode_reg = modrm[5:3];
assign rm = modrm[2:0];

output [2:0] sr1_out, sr2_out, dr_out;
addressingModeCS agen(opcode, 'hzz, 'hzz, modrm, sr1_out, sr2_out, dr_out );

output [7:0] gate_signals;
reg [2:0] gate_type;
gate_signals_encoder gs_encoder(gate_type, gate_signals);

output [5:0] load_signals;

output [1:0] eip_adder_mux;
output [1:0] eip_in_mux;

output [1:0] aluk;
alu_signal alu_sig(opcode, opcode_reg, aluk);

reg [1:0] SR2_MUX;

always @(posedge clk) begin
    case (state)
        'h8 : begin // ADD dr <- sr1 + sr2
            if (opcode == 'h83) begin
                dr_out = sr1_out;
            end
            SR2_MUX = SR2_MUX_imm32;
            gate_type = GATE_ALU;
            load_signals = LD_REG;
        end
        'h12 : begin // MOV dr <- imm32
            SR2_MUX = SR2_MUX_imm32;
            gate_type = GATE_SR2;
            load_signals = LD_REG;
        end
        'h16 : begin // JMP eip + rel32
            load_signals = LD_EIP;
            eip_in_mux = EIP_IN_MUX_adder;
            eip_adder_mux = EIP_ADDER_MUX_disp32;
        end
        default: begin
            load_signals = LD_NONE;
            gate_type = GATE_NONE;
        end
    endcase
end

endmodule


module addressingModeCS (
  opcode0, opcode1, opcode2, modrm, 
  sr1_out, sr2_out, dr_out
);
    
// 1, 2, 3 byte opcode
input [7:0] opcode0, opcode1, opcode2;
output [2:0] sr1_out, sr2_out, dr_out;

// MODRM byte
input [7:0] modrm;
// MODRM sub-fields
wire [1:0] mode;
wire [2:0] reg_opcode, rm;

// Implement for relavent test
// Register Order: EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI
/*
        MOV EAX,0x12340000   //  B8 00 00 34 12
        MOV ECX,0x00001234   //  B9 34 12 00 00
        ADD EAX,ECX          //  01 C8
        ADD EAX,#-1          //  83 C0 FF
        HLT                  //  F4
*/

reg [2:0] SR1_reg;
reg [2:0] SR2_reg;

reg [1:0] SR1_addressiblity; // 0 = Low 8, 1 = High 8 , 2 = Low 16, 3 = Full 32
reg [1:0] SR2_addressiblity; // 0 = Low 8, 1 = High 8 , 2 = Low 16, 3 = Full 32

// TODO do prefix addressing mode here
reg [1:0] SR1_select; // 0 = SR1, 1 = EIP
reg [1:0] DR_select; // 0 = SR1, 1 = EIP

reg [1:0] SR2_mux;
reg SR1_mux;

reg rm_mode; // 0 = memory, 1 = register

always @(*) begin
    // MOV+ case
    if (opcode0[7:4] == 'hb) begin
        SR1_reg = opcode0[3:0] >= 8 ? opcode0[3:0] - 8 : opcode0[3:0];
    end else begin
        case (opcode0)
            'h01, 'h09, 'h89: begin // r/m32 <- r/m32 + r32
                SR1_reg = rm;
                SR2_reg = reg_opcode;
                DR_select = 0;
                SR1_select = 0;
            end
            'h03, 'h0b, 'h8b: begin // r32 <- r32 + r/m32
                SR1_reg = reg_opcode;
                SR2_reg = rm;
                DR_select = 0;
                SR1_select = 0;
            end
            'h81: begin // r/m32 <- r/m32 + imm32
                SR1_reg = rm;
                SR2_reg = 'bzzz;
                SR2_mux = SR2_MUX_imm32;
                DR_select = 0;
                SR1_select = 0;
            end
            'h83: begin // r/m32 <- r/m32 + imm8
                SR1_reg = rm;
                SR2_reg = 'bzzz;
                SR2_mux = SR2_MUX_imm8;
                DR_select = 0;
                SR1_select = 0;
            end
            'hd1: begin // SAR by 1
                SR1_reg = rm;
                SR2_reg = 'bzzz;
                SR2_mux = SR2_MUX_alu_R;
                DR_select = 0;
                SR1_select = 0;
            end
            'hd3: begin // SAR by CL
                SR1_reg = rm;
                SR2_reg = 'b001;
                SR2_mux = SR2_MUX_sr2;
                DR_select = 0;
                SR1_select = 0;
                SR2_addressiblity = 0; // low 8 bits
            end
            'hc1: begin // SAR by imm8
                SR1_reg = rm;
                SR2_reg = 'bzzz;
                SR2_mux = SR2_MUX_imm8;
                DR_select = 0;
                SR1_select = 0;
            end
            'heb : begin
                SR1_reg = 'bzzz;
                SR2_reg = 'bzzz;
                DR_select = 1;
                SR1_select = 1;
            end
            'he9 : begin
                SR1_reg = 'bzzz;
                SR2_reg = 'bzzz;
                DR_select = 1;
                SR1_select = 1;
            end
            'hff : begin
                SR1_reg = 'bzzz;
                SR2_reg = 'bzzz;
                DR_select = 1;
                SR1_select = 1;
            end
            'hea : begin
                SR1_reg = 'bzzz;
                SR2_reg = 'bzzz;
                DR_select = 1;
                SR1_select = 1;
            end
            default: 
        endcase
    end
end

endmodule


// Longest instructino is up to 15 bytes
// TODO
module decode(
    byte0, byte1, byte2, byte3, byte4
    byte5, byte6, byte7, byte8, byte9
    byte10, byte11, byte12, byte13, byte14
);

input [7:0] byte0, byte1, byte2, byte3, byte4, 
            byte5, byte6, byte7, byte8, byte9, 
            byte10, byte11, byte12, byte13, byte14;

reg [3:0] instruction_size;

reg [7:0] opcode;
reg [7:0] modrm;

reg [7:0] sib; // No SIB byte yet.

reg [31:0] imm32;
reg [31:0] disp32;

reg [7:0] imm8;
reg [7:0] disp8;

// Assuming no prefix
always @(*) begin
    case (byte0)
        'h01, 'h03: begin // ADD r/m32, r32 + ADD r32, r/m32
            instruction_size = 2;
            opcode = byte0;
        end 
        'h81, 'h83: begin // ALU op based on modrm.opcode
            
        end
        'h09: begin

        end 
        'h0b: begin
            
        end
        'h89: begin // r/m32 <- r/m32 + r32
            
        end
        'h8b: begin // r32 <- r32 + r/m32
            
        end
        'hd1: begin // SAR by 1

        end
        'hd3: begin // SAR by CL

        end
        'hc1: begin // SAR by imm8

        end
        'heb : begin

        end
        'he9 : begin

        end
        'hff : begin

        end
        'hea : begin

        end
        default: 
    endcase
end
endmodule