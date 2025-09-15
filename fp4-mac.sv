/*
MIT License

Copyright (c) 2020 Debtanu Mukherjee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

module fmultiplier(clk, rst, a, b, z);

input clk, rst;
input [3:0] a, b;
output reg [3:0] z;

reg [2:0] counter; //3 bit counter for pipeline states

reg a_m, b_m, z_m; //1 M bit
reg [1:0] a_e, b_e, z_e; //2 E bits
reg a_s, b_s, z_s; //1 S bit

reg [4:0] product; //product of mantissas and GRS bits

reg guard_bit, round_bit, sticky;

always @(posedge clk or rst) begin // 3 bit counter for pipeline states
	if(rst)
		counter <= 0;
	else
		counter <= counter + 1;
end


always @(counter) begin
	if(counter == 3'b001) begin
		    a_m <= a[0];
	        b_m <= b[0];
	        a_e <= a[2:1]
        	b_e <= b[2:1];
	        a_s <= a[3];
        	b_s <= b[3];
        end
end


always @(counter) begin
	if(counter == 3'b010) begin
		if ((a_e == 3 && a_m != 0) || (b_e == 3 && b_m != 0)) begin //NAN 
          		z[3] <= 1;    
          		z[2:1] <= 3;  
          		z[0] <= 1;   
          	end
          	else if (a_e == 3) begin //INF A
          		z[3] <= a_s ^ b_s;
          		z[2:1] <= 3;
          		z[0] <= 0;
          		if (($signed(b_e) == -1) && (b_m == 0)) begin //NAN IF B = 0
            			z[3] <= 1;
            			z[2:1] <= 3;
	        	    	z[0] <= 1;
          		end
          	end
          	else if (b_e == 3) begin //INF B
          		z[3] <= a_s ^ b_s;
          		z[2:1] <= 3;
          		z[0] <= 0;
          		if (($signed(a_e) == -1) && (a_m == 0)) begin //NAN IF A = 0
            			z[3] <= 1;
            			z[2:1] <= 3;
	        	    	z[0] <= 1;
          		end
          	end
	          else if (($signed(a_e) == -1) && (a_m == 0)) begin //0 if A = 0
       		    z[3] <= a_s ^ b_s;
       		    z[2:1] <= 0;
        	 	z[0] <= 0;
        	  end
        	  else if (($signed(b_e) == -1) && (b_m == 0)) begin //0 if B = 0
        	 	 z[3] <= a_s ^ b_s;
        	  	 z[2:1] <= 0;
        	  	 z[0] <= 0;
        	  end
        	  else begin
        	  	if ($signed(a_e) == -1) //DENORMALIZING A
        	    		a_e <= 0;
        	  	else
        	    		a_m <= 1;
            		
        	    	if ($signed(b_e) == -1) //DENORMALIZING B
        	    		b_e <= 0;
        	  	else
        	    		b_m <= 1;
        	  end
        end
end


always @(counter) begin
	if(counter == 3'b011) begin
		if (~a_m) begin //NORMALIZE A
	        	a_m <= a_m << 1;
	       	a_e <= a_e - 1;
	        end
	        if (~b_m) begin //NORMALIZE B
	        	b_m <= b_m << 1;
	       	b_e <= b_e - 1;
	        end
	end
end


always @(counter) begin
	if(counter == 3'b100) begin //GET THE SIGNS XORED and EXPONENTS ADDED and GET THE INTERMEDIATE MANTISSA MULTIPLICATION
		z_s <= a_s ^ b_s;
	        z_e <= a_e + b_e + 1;
        	product <= a_m * b_m * 4;
	end
end


always @(counter) begin
	if(counter == 3'b101) begin
		z_m <= product[4];
       	guard_bit <= product[3];
      		round_bit <= product[2];
      		sticky <= (product[1:0] != 0);
	end
end

always @(counter) begin
	if(counter == 3'b110) begin
		if ($signed(z_e) < 0) begin
        		z_e <= z_e + (0 -$signed(z_e));
    			z_m <= z_m >> (0 -$signed(z_e));
     			guard_bit <= z_m;
       		round_bit <= guard_bit;
       		sticky <= sticky | round_bit;
        	end
		else if (z_m == 0) begin
        		z_e <= z_e - 1;
        		z_m <= z_m << 1;
        		z_m <= guard_bit;
        		guard_bit <= round_bit;
        		round_bit <= 0;
        	end
	        else if (guard_bit && (round_bit | sticky | z_m)) begin
        		z_m <= z_m + 1;
          		if (z_m == 1)
            			z_e <=z_e + 1;
        	end
        end
end

always @(counter) begin
	if(counter == 3'b111) begin
		z[0] <= z_m;
        	z[2:1] <= z_e;
        	z[3] <= z_s;
        	if ($signed(z_e) == 0 && z_m == 0)
          		z[2:1] <= 0;
        	if ($signed(z_e) > 3) begin //IF OVERFLOW RETURN INF
          		z[0] <= 0;
          		z[2:1] <= 3;
          		z[3] <= z_s;
        	end
	end
end


endmodule