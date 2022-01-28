module TOP;

   reg [15:0] a, b;
   reg [1:0] s;
   wire [15:0] out;
   
   initial
   begin
      a = 16'h0f0f;
      b = 16'hf0f0;
      s = 2'b00;

      #5

      a = 16'hcccc;
      b = 16'h6666;
      s = 2'b00;

      #5

      a = 16'h0f0f;
      b = 16'hcc77;
      s = 2'b01;

      #5

      a = 16'h1234;
      b = 16'haaaa;
      s = 2'b10;

      #5

      a = 16'h1282;
      b = 16'h1282;
      s = 2'b11;
   end
   
   // Run simulation for 15 ns.  
   initial #100 $finish;
   
   // Dump all waveforms to d_latch.dump.vpd
   initial
   begin
      //$dumpfile ("d_latch.dump");
      //$dumpvars (0, TOP);
      $vcdplusfile("PS1b.dump.vpd");
      $vcdpluson(0, TOP); 
   end // initial begin
   
   // always @(posedge d)
   //    $strobe ("at time %0d, wen = %b", $time, we);
   
   ALU alu(a, b, s, out);
   
endmodule

//-----------------------------------------------------

// GATED D LATCH

//-----------------------------------------------------
// Functionality:
// pass d when wen is 1
// hold d when wen is 0
//
module d_latch (d, q, qbar, wen);
   input d, wen;
   output q, qbar;
   
   wire   dbar, r, s;
   
   inv1$ inv1 (dbar, d);
   nand2$ nand1 (s, d, wen),
          nand2 (r, dbar, wen),
   
          nand3 (q, s, qbar),
          nand4 (qbar, r, q);
   
endmodule

// Components
//-----------------------------------------------------
// note: nand2$ params (ouput, input, input)

module not_nand (a, o);
   input a;
   output o;

   nand2$ n1(o, a, a);
endmodule

module xor_nand (a, b, o);
   input a, b;
   output o;

   wire a_bar, b_bar, inter1, inter2;

   not_nand nn1(a, a_bar), nn2(b, b_bar);
   nand2$   n1(inter1, a_bar, b), 
            n2(inter1, b_bar, a),
            n3(o, inter1, inter2);
endmodule

module and_nand (a, b, o);
   input a, b;
   output o;

   wire inter;

   nand2$ n1(inter, a, b);
   not_nand nn1(inter, o);
endmodule

// Structural for full adder
module full_adder (a, b, cin, s, cout);
   input a, b, cin;
   output s, cout;

   wire inter_s;
   xor_nand    x1(a, b, inter_s), 
               x2(inter_s, cin, s);


   wire n_ab, n_ac, n_bc;
   nand2$   n1(n_ab, a, b),
            n2(n_ac, a, c),
            n3(n_bc, b, c);

   // 3 input OR structure
   wire inter1, inter2;
   nand2$   n4(inter1, n_ab, n_ac);
   not_nand nn1(inter1, inter2);
   nand2$   n5(cout, inter2, n_bc);
   
endmodule

module MUX2 (i0, i1, s, o);
   input i0, i1, s;
   output o;

   wire sbar, inter1, inter2;

   not_nand nn1(s, sbar);

   nand2$   n1(inter1, i0, sbar),
            n2(inter2, i1, s),
            n3(o, inter1, inter2);
endmodule

module MUX4_16 (i0, i1, i2, i3, s, o);
   input [15:0] i0, i1, i2, i3;
   input [1:0] s;
   output [15:0] o;

   wire [3:0] select_line;
   wire s0bar, s1bar;
   not_nand nn1(s[0], s1bar), 
            nn2(s[1], s2bar);

   and_nand select1(s1bar, s0bar, select_line[0]),
            select2(s1bar, s[0], select_line[1]),
            select3(s[1], s0bar, select_line[2]),
            select4(s[1], s[0], select_line[3]);

   wire [15:0] inter1, inter2, inter3, inter4, inter5, inter6, inter7, inter8;

   genvar i;

   generate
      for (i = 0; i < 16; i = i + 1) begin : gen1
         nand2$   n0_i(inter1[i], i0[i], select_line[0]),
                  n1_i(inter2[i], i1[i], select_line[1]),
                  n2_i(inter3[i], i2[i], select_line[2]),
                  n3_i(inter4[i], i3[i], select_line[3]);
      end

      for (i = 0; i < 16; i = i + 1) begin : gen2
         nand2$   n4_i(inter5[i], inter1[i], inter2[i]),
                  n5_i(inter6[i], inter3[i], inter4[i]);
      end

      for (i = 0; i < 16; i = i + 1) begin : gen3
         not_nand nn1_i(inter5[i], inter7[i]), 
                  nn2_i(inter6[i], inter8[i]);
      end

      for (i = 0; i < 16; i = i + 1) begin : gen4
         nand2$   n6_i(o[i], inter7[i], inter8[i]);
      end
   endgenerate
endmodule

module MUX4_8 (i0, i1, i2, i3, s, o);
   input [7:0] i0, i1, i2, i3;
   input [1:0] s;
   output [7:0] o;

   wire [3:0] select_line;
   wire s0bar, s1bar;
   not_nand nn1(s[0], s1bar), 
            nn2(s[1], s2bar);

   and_nand select1(s1bar, s0bar, select_line[0]),
            select2(s1bar, s[0], select_line[1]),
            select3(s[1], s0bar, select_line[2]),
            select4(s[1], s[0], select_line[3]);

   wire [7:0] inter1, inter2, inter3, inter4, inter5, inter6, inter7, inter8;

   genvar i;

   generate
      for (i = 0; i < 8; i = i + 1) begin : gen1
         nand2$   n0_i(inter1[i], i0[i], select_line[0]),
                  n1_i(inter2[i], i1[i], select_line[1]),
                  n2_i(inter3[i], i2[i], select_line[2]),
                  n3_i(inter4[i], i3[i], select_line[3]);
      end

      for (i = 0; i < 8; i = i + 1) begin : gen2
         nand2$   n4_i(inter5[i], inter1[i], inter2[i]),
                  n5_i(inter6[i], inter3[i], inter4[i]);
      end

      for (i = 0; i < 8; i = i + 1) begin : gen3
         not_nand nn1_i(inter5[i], inter7[i]), 
                  nn2_i(inter6[i], inter8[i]);
      end

      for (i = 0; i < 8; i = i + 1) begin : gen4
         nand2$   n6_i(o[i], inter7[i], inter8[i]);
      end
   endgenerate
endmodule

// Slices of ALU
//-----------------------------------------------------
module AND_ALU_slice (a, b, out);
   input [15:0] a, b;
   output [15:0] out;


   genvar i;
   generate
      for (i = 0; i < 16; i = i + 1) begin : gen1
         and_nand an_i(a[i], b[i], out[i]);
      end
   endgenerate
endmodule

module NOT_ALU_slice (b, out);
   input [15:0] b;
   output [15:0] out;

   genvar i;
   generate
      for (i = 0; i < 16; i = i + 1) begin : gen1
         not_nand nn_i(b[i], out[i]);
      end
   endgenerate
endmodule

module ADD_SAT_slice (a, b, s, out);
   input [15:0] a, b;
   input [1:0] s;    
   output [15:0] out;

   wire [15:0] output_line;
   wire [15:0] sum;
   wire [16:0] carry;
   wire ol, oh;

   assign out = output_line;

   genvar i;

   // lower 8 FA
   full_adder f_0(a[0], b[0], 0, sum[0], c[1]);
   generate
      for (i = 1; i < 8; i = i + 1) begin : gen1
         full_adder f_i(a[i], b[i], cin[i], sum[i], c[i + 1]);
      end
   endgenerate

   wire select_and, carry_upper;
   and_nand an1(s[0], s[1], select_and);
   MUX2 mx1(c[8], 0, select_and, carry_upper);

   // upper 8 FA
   full_adder f_8(a[8], b[8], carry_upper, sum[8], c[9]);
   generate
      for (i = 9; i < 16; i = i + 1) begin : gen2
         full_adder f_i(a[i], b[i], cin[i], sum[i], c[i + 1]);
      end
   endgenerate

   // overflow bits
   xor_nand x1(c[7], c[8], ol),
            x2(c[15], c[16], oh);

   wire smallest, largest;
   assign largest = 8'h7f;
   assign smallest = 8'h80;
   MUX4_8   mx4_8_1(sum[7:0], sum[7:0], smallest, largest, {ol, a[7]}, output_line[7:0]),
            mx4_8_2(sum[15:8], sum[15:8], smallest, largest, {oh, a[15]}, output_line[15:8]);
endmodule




// Structural for ALU
module ALU (a, b, s, out);
   input [15:0] a, b; // 16-bit inputs
   input [1:0] s;     // 2-bit select  
   output [15:0] out; // 16-bit outputs

   // AND == 00, NOT == 01, ADD == 10, SAT == 11
   wire [15:0] and_line, not_line, add_sat_line;

   // AND_ALU_slice and_slice(a, b, out);
   // NOT_ALU_slice not_slice(b, out);
   ADD_SAT_slice add_sat_slice(a, b, s, out);

   // MUX4_16 mx4_16_1(and_line, not_line, add_sat_line, add_sat_line, s, out);
endmodule