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
   output b;

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
wire 

endmodule

module and_nand (a, b, o);
   input a, b;
   output o;

   wire inter;

   nand2$ n1(inter, a, b);
   not_nand(inter, o);
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

   
   
endmodule

// Slices of ALU
//-----------------------------------------------------
module AND_ALU_slice (a, b, out);
   input [15:0] a, b;
   output [15:0] out;


   genvar i;
   generate
      for (i = 0 i < 16; i = i + 1) begin
         and_nand an_i(a[i], b[i], out[i]);
      end
   endgenerate
endmodule

module NOT_ALU_slice (b, out);
   input [15:0] b;
   output [15:0] out;

   genvar i;
   generate
      for (i = 0 i < 16; i = i + 1) begin
         not_nand nn_i(b[i], out[i]);
      end
   endgenerate
endmodule

module ADD_SAT_slice (a, b, s, out);
   input [15:0] a, b;
   input [1:0] s;    
   output [15:0] out;

   wire [16:0] carry;
   wire ol, oh;

   genvar i;

   // lower 8 FA
   full_adder f_0(a[0], b[0], 0, s[0], out[0], c[1]);
   generate
      for (i = 1 i < 8; i = i + 1) begin
         full_adder f_i(a[i], b[i], cin[i], out[i], c[i + 1]);
      end
   endgenerate

   wire select_and, carry_upper;
   and_nand a(s[0], s[1], select_and);
   MUX2 mx1(c[8], 0, select_and, carry_upper);

   // upper 8 FA
   full_adder f_8(a[8], b[8], carry_upper, s[8], out[8], c[9]);
   generate
      for (i = 9 i < 16; i = i + 1) begin
         full_adder f_i(a[i], b[i], cin[i], out[i], c[i + 1]);
      end
   endgenerate

   // overflow bits
   xor_nand x1(c[7], c[8], ol),
            x2(c[15], c[16], oh);




   
endmodule




// Structural for ALU
module ALU (a, b, s, out);
input [15:0] a, b; // 16-bit inputs
input [1:0] s;     // 2-bit select  
output [15:0] out; // 16-bit outputs

// AND == 00, NOT == 01, ADD == 10, SAT == 11

endmodule