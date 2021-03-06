// Modified by Princeton University on June 9th, 2015
// ========== Copyright Header Begin ==========================================
// 
// OpenSPARC T1 Processor File: sparc_ifu_incr46.v
// Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
// DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
// 
// The above named program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License version 2 as published by the Free Software Foundation.
// 
// The above named program is distributed in the hope that it will be 
// useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// General Public License for more details.
// 
// You should have received a copy of the GNU General Public
// License along with this work; if not, write to the Free Software
// Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
// 
// ========== Copyright Header End ============================================
////////////////////////////////////////////////////////////////////////
/*
//  Description:	
//  Contains the pc incrementer.
*/

module sparc_ifu_incr46(a, a_inc, ofl);
   input  [45:0]  a;
   output [45:0]  a_inc;
   output 	  ofl;
   
   reg [45:0] 	  a_inc;
   reg 		  ofl;
   
   always @ (a)
     begin
	      a_inc = a + (46'b1);
	      ofl = (~a[45]) & a_inc[45];
     end
   
   
   
endmodule // sparc_ifu_incr46


