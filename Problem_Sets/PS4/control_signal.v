`timescale 1 ns / 100 ps

`define SR1_MUX_sr1   0
`define SR1_MUX_alu_r 1

`define SR2_MUX_sr2   0
`define SR2_MUX_imm8  1
`define SR2_MUX_imm32 2
`define SR2_MUX_alu_r 3

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
`define GATE_MDR  6

`define LD_NONE  'b000000
`define LD_REG   'b000001
`define LD_EIP   'b000010
`define LD_ALU_R 'b000100
`define LD_MDR   'b001000
`define LD_MAR   'b010000

`define DONT_CARE 'hz

module TOP;
	reg clk = 1;
    reg [7:0] state, opcode, modrm;

    wire [31:0] sr1_d, sr2_d;
    wire [2:0] sr1_out, sr2_out, dr_out;
    wire [4:0] gate_signals;
    wire [5:0] load_signals;
    wire [1:0] eip_adder_mux;
    wire [1:0] eip_in_mux;
    wire [1:0] aluk;

	reg [31:0] disp32, imm32;
	reg [7:0] disp8, imm8;

    wire gate_alu, gate_sr1, gate_sr2, gate_eip, gate_agen, gate_mdr;

    gate_signals_decoder gate_decode(gate_signals, gate_alu, gate_sr1, gate_sr2, gate_eip, gate_agen, gate_mdr);

    wire load_reg, load_eip, load_alu_r, load_mdr, load_mar;

    wire [31:0] MEM_BUS;

    wire [1:0] sr2_mux, alu_r_mux;
    wire sr1_mux;

   	initial
	begin
        // testing: MOV EAX,0x12340000   //  B8 00 00 34 12
        opcode <= 8'hB8;
        modrm <= 8'hzz;
        imm32 <= 32'h12340000;

        state <= 12;

        #200

        // testing: MOV ECX,0x12340000   //  B9 00 00 34 12
        opcode <= 8'hB9;
        modrm <= 8'hzz;
        imm32 <= 32'h00001234;

        state <= 12;

        #200

        imm32 <= 32'hzzzzzzzz;

        // testing: ADD EBX, [EBP + disp32]          //  01 C8
        opcode <= 8'h03;
        modrm <= 8'h9D;
        disp32 <= 32'h00ff00ff;

        state <= 1;
        #200
        state <= 2;
        #600
        state <= 3;
        #200
        state <= 4;
        #200

        // testing: ADD [EBP + disp32], EBX          //  01 C8
        opcode <= 8'h01;
        modrm <= 8'h9D;
        disp32 <= 32'h00ff00ff;

        state <= 1;
        #200
        state <= 2;
        #600
        state <= 3;
        #200
        state <= 5;
        #200
        state <= 6;
        #600

        // testing: ADD [EAX,ECX          //  01 C8
        opcode <= 8'h01;
        modrm <= 8'hC8;

        state <= 8;

        #200

		// testing: ADD EBX, 0x12340000   // 83 C0 FF
        opcode <= 8'h83;
        modrm <= 8'hC0;
        imm8 <= -8'h1;

        state <= 8;

        #200
        
        imm8 <= -8'hzz;
		// testing: jmp, 0x05 (rel32)   // E9 05 00 00 00 
        opcode <= 8'he9;
        modrm <= 8'hzz;
        imm32 <= 32'h00000005;

        state <= 16;
	end
   
   	// Run simulation for 15 ns.  
   	initial #10000 $finish;
	
   	// Dump all waveforms to d_latch.dump.vpd
   	initial
	begin
		//$dumpfile ("d_latch.dump");
		//$dumpvars (0, TOP);
		$vcdplusfile("control_signal.dump.vpd");
		$vcdpluson(0, TOP); 
	end // initial begin


    
    

    datapathCS dp_controls(state, opcode, modrm, clk,
                           aluk, sr1_out, sr2_out, dr_out, sr1_mux, sr2_mux,
                           eip_adder_mux, eip_in_mux,
                           gate_signals, load_signals);


   	// bus_gate test(test_gate, test_gate_d, MEM_BUS);
   	agex_datapath agex (clk, modrm, disp32, imm32,
						
                        eip_adder_mux, eip_in_mux, gate_eip,

						load_eip,
						
                        sr1_d, sr2_d,
						
                        gate_agen,

						alu_r_mux, sr1_mux, sr2_mux,
                        
                        aluk,

						load_alu_r,

						gate_alu,
						MEM_BUS
						);

    register_structure reg_struct (
                                   gate_sr1, gate_sr2,
                                   dr_out, sr1_out, sr2_out,
                                   load_reg,
                                   sr1_d, sr2_d, 
                                   MEM_BUS, clk
                                  );

	always
		#50 clk = ~clk;
   
endmodule

module gate_signals_decoder (gate_signal, 
gate_alu, gate_sr1, gate_sr2, gate_eip, gate_agen, gate_mdr);
input [4:0] gate_signal;
output reg gate_alu, gate_sr1, gate_sr2, gate_eip, gate_agen, gate_mdr;

always @* begin
    gate_alu <= 0;
    gate_sr1 <= 0;
    gate_sr2 <= 0;
    gate_eip <= 0;
    gate_agen <= 0;
    gate_mdr <= 0;
    case (gate_signal)
        `GATE_ALU : gate_alu <= 1;
        `GATE_SR1 : gate_sr1 <= 1;
        `GATE_SR2 : gate_sr2 <= 1;
        `GATE_EIP : gate_eip <= 1;
        `GATE_AGEN : gate_agen <= 1;
        `GATE_MDR : gate_mdr <= 1;
    endcase
end    
endmodule


module load_signals_isolater (load_signals, 
load_reg, load_eip, load_alu_r, load_mdr, load_mar);
input [5:0] load_signals;
output load_reg, load_eip, load_alu_r, load_mdr, load_mar;

assign load_reg = load_signals[0];
assign load_eip = load_signals[1];
assign load_alu_r = load_signals[2];
assign load_mdr = load_signals[3];
assign load_mar = load_signals[4];
endmodule

module alu_signal(opcode, opcode_reg, aluk);
    input [7:0] opcode;
    input [2:0] opcode_reg; 
    output reg [1:0] aluk;

    always @* begin 
        case (opcode)
            'h81, 'h83: aluk = {1'b0, opcode_reg[0]};
            'h01, 'h03: aluk = 2'b00; 
            'h09, 'h0b: aluk = 2'b01; 
            'hd1, 'hd3, 'hc1: aluk = 2'b11;
            default: aluk = 2'b00;
        endcase
    end
endmodule

module datapathCS (state, opcode, modrm, clk,
aluk, sr1_out, sr2_out, dr_out, sr1_mux_out, sr2_mux_out,
eip_adder_mux, eip_in_mux,
gate_signals, load_signals
);

input [7:0] state, opcode, modrm;
input clk;

wire [1:0] mod;
wire [2:0] opcode_reg, rm;
assign mod = modrm[7:6];
assign opcode_reg = modrm[5:3];
assign rm = modrm[2:0];

output [2:0] sr1_out, sr2_out, dr_out;
output [1:0] sr2_mux_out;
output sr1_mux_out;

wire [2:0] sr1_out_temp, sr2_out_temp, dr_out_temp;
wire [1:0] sr2_mux_out_temp;
wire sr1_mux_out_temp;


assign sr1_out = sr1_out_temp;
assign sr2_out = sr2_out_temp;
assign sr2_out = sr2_out_temp;
assign sr1_mux_out = sr1_mux_out_temp;
assign sr2_mux_out = sr2_mux_out_temp;

addressingModeCS agen(opcode, 8'hzz, 8'hzz, modrm, sr1_out_temp, sr2_out_temp, dr_out_temp, sr1_mux_out_temp, sr2_mux_out_temp);

output reg [4:0] gate_signals;

output reg [5:0] load_signals;

output reg [1:0] eip_adder_mux;
output reg [1:0] eip_in_mux;

output [1:0] aluk;
alu_signal alu_sig(opcode, opcode_reg, aluk);

reg [1:0] SR2_MUX;

always @* begin
    case (state)
        'd1 : begin
            gate_signals <= `GATE_AGEN;
            load_signals <= `LD_MAR;
            eip_in_mux <= `DONT_CARE;
            eip_adder_mux <= `DONT_CARE;
        end
        'd3 : begin
            gate_signals <= `GATE_MDR;
            load_signals <= `LD_ALU_R;
            eip_in_mux <= `DONT_CARE;
            eip_adder_mux <= `DONT_CARE;
        end
        'd4: begin
            gate_signals <= `GATE_ALU;
            load_signals <= `LD_REG;
        end
        'd5: begin
            gate_signals <= `GATE_ALU;
            load_signals <= `LD_MDR;
        end
        'd8 : begin // ADD dr <- sr1 + sr2
            // if (opcode == 'h83)
            SR2_MUX <= `SR2_MUX_imm32;
            gate_signals <= `GATE_ALU;
            load_signals <= `LD_REG;
            eip_in_mux <= `DONT_CARE;
            eip_adder_mux <= `DONT_CARE;
        end
        'd12 : begin // MOV dr <- imm32
            SR2_MUX <= `SR2_MUX_imm32;
            gate_signals <= `GATE_SR2;
            load_signals <= `LD_REG;
            eip_in_mux <= `DONT_CARE;
            eip_adder_mux <= `DONT_CARE;
        end
        'd16 : begin // JMP eip + rel32
            gate_signals <= `GATE_NONE;
            load_signals <= `LD_EIP;
            eip_in_mux <= `EIP_IN_MUX_adder;
            eip_adder_mux <= `EIP_ADDER_MUX_disp32;
        end
        default: begin
            load_signals <= `LD_NONE;
            gate_signals <= `GATE_NONE;
            eip_in_mux <= `DONT_CARE;
            eip_adder_mux <= `DONT_CARE;
        end
    endcase
end

endmodule


module addressingModeCS (
  opcode0, opcode1, opcode2, modrm, 
  sr1_out, sr2_out, dr_out,
  sr1_mux_out, sr2_mux_out
);
    
// 1, 2, 3 byte opcode
input [7:0] opcode0, opcode1, opcode2;
output [2:0] sr1_out, sr2_out, dr_out;
output [1:0] sr2_mux_out;
output sr1_mux_out;

// MODRM byte
input [7:0] modrm;
// MODRM sub-fields
wire [1:0] mod;
wire [2:0] opcode_reg, rm;

assign mod = modrm[7:6];
assign opcode_reg = modrm[5:3];
assign rm = modrm[2:0];

// Implement for relavent test
// Register Order: EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI

reg [2:0] SR1_reg;
reg [2:0] SR2_reg;


reg [1:0] SR1_addressiblity; // 0 = Low 8, 1 = High 8 , 2 = Low 16, 3 = Full 32
reg [1:0] SR2_addressiblity; // 0 = Low 8, 1 = High 8 , 2 = Low 16, 3 = Full 32

// TODO do prefix addressing mode here
reg [1:0] SR1_select; // 0 = SR1, 1 = EIP
reg [1:0] DR_select; // 0 = SR1, 1 = EIP

assign sr1_out = SR1_reg;
assign sr2_out = SR2_reg;
assign dr_out = SR1_reg;

reg SR1_mux;
reg [1:0] SR2_mux;

assign sr1_mux_out = SR1_mux;
assign sr2_mux_out = SR2_mux;

always @(*) begin
    // MOV+ case
    if (opcode0[7:4] == 'hb) begin
        SR1_reg <= opcode0[3:0] >= 8 ? opcode0[3:0] - 8 : opcode0[3:0];
        SR2_reg <= 'bzzz;
        DR_select <= 0;
        SR1_select <= 0;
        SR1_mux <= `SR1_MUX_sr1; 
        SR2_mux <= `SR2_MUX_imm32;
    end else begin
        case (opcode0)
            'h01, 'h09, 'h89: begin // r/m32 <- r/m32 + r32
                SR1_reg <= rm;
                SR2_reg <= opcode_reg;
                DR_select <= 0;
                SR1_select <= 0;
                SR1_mux <= (mod == 2'b11) ? `SR1_MUX_sr1 :`SR1_MUX_alu_r;
                SR2_mux <= `SR2_MUX_sr2;
            end
            'h03, 'h0b, 'h8b: begin // r32 <- r32 + r/m32
                SR1_reg <= opcode_reg;
                SR2_reg <= rm;
                DR_select <= 0;
                SR1_select <= 0;
                SR1_mux <= `SR1_MUX_sr1;
                SR2_mux <= (mod == 2'b11) ? `SR2_MUX_sr2 :`SR2_MUX_alu_r;
            end
            'h81: begin // r/m32 <- r/m32 + imm32
                SR1_reg <= rm;
                SR2_reg <= 'bzzz;
                SR2_mux <= `SR2_MUX_imm32;
                DR_select <= 0;
                SR1_select <= 0;
                SR1_mux <= (mod == 2'b11) ? `SR1_MUX_sr1 :`SR1_MUX_alu_r;
                SR2_mux <= `SR2_MUX_imm32;
            end
            'h83: begin // r/m32 <- r/m32 + imm8
                SR1_reg <= rm;
                SR2_reg <= 'bzzz;
                SR2_mux <= `SR2_MUX_imm8;
                DR_select <= 0;
                SR1_select <= 0;
                SR1_mux <= (mod == 2'b11) ? `SR1_MUX_sr1 :`SR1_MUX_alu_r;
                SR2_mux <= `SR2_MUX_imm8;
            end
            'hd1: begin // SAR by 1
                SR1_reg <= rm;
                SR2_reg <= 'bzzz;
                SR2_mux <= `SR2_MUX_alu_r;
                DR_select <= 0;
                SR1_select <= 0;
            end
            'hd3: begin // SAR by CL
                SR1_reg <= rm;
                SR2_reg <= 'b001;
                SR2_mux <= `SR2_MUX_sr2;
                DR_select <= 0;
                SR1_select <= 0;
                SR2_addressiblity <= 0; // low 8 bits
            end
            'hc1: begin // SAR by imm8
                SR1_reg <= rm;
                SR2_reg <= 'bzzz;
                SR2_mux <= `SR2_MUX_imm8;
                DR_select <= 0;
                SR1_select <= 0;
            end
            'heb : begin
                SR1_reg <= 'bzzz;
                SR2_reg <= 'bzzz;
                DR_select <= 1;
                SR1_select <= 1;
            end
            'he9 : begin
                SR1_reg <= 'bzzz;
                SR2_reg <= 'bzzz;
                DR_select <= 1;
                SR1_select <= 1;
            end
            'hff : begin
                SR1_reg <= 'bzzz;
                SR2_reg <= 'bzzz;
                DR_select <= 1;
                SR1_select <= 1;
            end
            'hea : begin
                SR1_reg <= 'bzzz;
                SR2_reg <= 'bzzz;
                DR_select <= 1;
                SR1_select <= 1;
            end
            default: begin

            end
        endcase     
    end
end

endmodule
