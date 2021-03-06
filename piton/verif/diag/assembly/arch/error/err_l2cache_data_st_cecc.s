// Modified by Princeton University on June 9th, 2015
/*
* ========== Copyright Header Begin ==========================================
* 
* OpenSPARC T1 Processor File: err_l2cache_data_st_cecc.s
* Copyright (c) 2006 Sun Microsystems, Inc.  All Rights Reserved.
* DO NOT ALTER OR REMOVE COPYRIGHT NOTICES.
* 
* The above named program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License version 2 as published by the Free Software Foundation.
* 
* The above named program is distributed in the hope that it will be 
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
* 
* You should have received a copy of the GNU General Public
* License along with this work; if not, write to the Free Software
* Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA.
* 
* ========== Copyright Header End ============================================
*/

#define MAIN_PAGE_HV_ALSO

#include "boot.s"

.text
.global main

#include "err_defines.h"

#define  L2_ENTRY_PA      0x311590000
#define  L2_BANK_ADDR     0x0
#define  TEST_DATA        0x81c3e008
#define  L2_ES_W1C_VALUE  0xc03ffff800000000

main:

  clr   %o7

#ifdef  RUN_TH1
  mov   0x1, %o7
#endif
#ifdef  RUN_TH2
  mov   0x2, %o7
#endif
#ifdef  RUN_TH3
  mov   0x3, %o7
#endif

  ta    %icc, T_RD_THID
  cmp   %o1, %o7
  bne   test_pass
  nop

  ! Boot code does not provide TLB translation for IO address space
  ta    T_CHANGE_HPRIV

  setx  L2_ENTRY_PA, %l0, %g1
  add   %g1, L2_BANK_ADDR, %g1
  setx  TEST_DATA, %l0, %g3
  setx  L2_ES_W1C_VALUE, %l0, %g4

  ! Store test data into memory
  st    %g3, [%g1]

  ! Now access L2 control and status registers
disable_l1:
  ldxa  [%g0] ASI_LSU_CONTROL, %l0
  ! Remove the lower 2 bits (I-Cache and D-Cache enables)
  andn  %l0, 0x3, %l0
  stxa  %l0, [%g0] ASI_LSU_CONTROL

disable_l2:
  setx  L2CS_PA1, %l1, %l0
  mov   0x1, %l2
  stx   %l2, [%l0+L2_BANK_ADDR]

  ! Write 1 to clear L2 Error status registers
  setx  L2ES_PA1, %l3, %l4
  add   %l4, L2_BANK_ADDR, %l4

clear_l2_ESR:
  stx   %g4, [%l4]
  nop

  ! read back and verify
  ldx   [%l4], %l3
  brnz  %l3, test_fail
  nop

  ! disable correctable error reporting (Boot code sets L2 CEEN)
clear_l2_EER:
  setx  L2EE_PA0, %l0, %l1
  add   %l1, L2_BANK_ADDR, %l1
  mov   0x0, %l0
  stx   %l0, [%l1]

  ! Generate L2 VD Diag read address
  ! Addressing: [39:32] See PRM, [22] 1 for V/D, [17:8] set, [7:6] bank, [2:0] = 0
  setx  0x3ffc0, %l0, %l2       ! Mask for extracting [17:6]
  and   %g1, %l2, %l7

  mov   0xa7, %l0
  sllx  %l0, 32, %l0            ! Bits [39:32]
  or    %l7, %l0, %l7

  mov   0x1, %l0
  sllx  %l0, 22, %l0            ! Bit [22]
  or    %l7, %l0, %l7
 
read_l2_VD_diag:
  ldx   [%l7], %l6

  ! Now find out which way it is being stored
  setx  0xffffff, %l0, %l2      ! Mask for [23:0]
  and   %l6, %l2, %l6
  srlx  %l6, 12, %l6            ! Valid bits at [23:12]

  clr   %g2                     ! %g2 will store the "way"

  ! Direct comparison - avoid loops to save run time
  cmp   %l6, 0x1
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x2
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x4
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x8
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x10
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x20
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x40
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x80
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x100
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x200
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x400
  be    way_found
  nop

  inc   %g2
  cmp   %l6, 0x800
  bne   test_fail
  nop

way_found:
  ! Read L2 Data Diag - %g2 has the "way"
  ! Addressing: [39:32] See PRM, [22] odd/even word, [21:18] way, [17:8] set, [7:6] bank, [5:3] D-word, [2:0] = 0
  setx  0x3fff8, %l0, %l2       ! Mask for extracting [17:3]
  and   %g1, %l2, %g5

  sllx  %g2, 18, %l0            ! Position Way
  or    %g5, %l0, %g5

  mov   0xa3, %l0
  sllx  %l0, 32, %l0            ! Bits [39:32]
  or    %g5, %l0, %g5           ! %g5 has L2 Data Diag addressing

read_l2_data_diag:
  ldx   [%g5], %g6

  ! Flip one bit from the data field
  xor   %g6, 0x80, %g6          ! save on %g6 for future reference
write_back_with_error:
  stx   %g6, [%g5]

enable_l2:
  setx  L2CS_PA0, %l1, %l0
  stx   %g0, [%l0+L2_BANK_ADDR]

enable_l1:
  ldxa  [%g0] ASI_LSU_CONTROL, %l0
  or    %l0, 0x3, %l0
  stxa  %l0, [%g0] ASI_LSU_CONTROL

  ! Compute expected value of L2 error status register
  mov   0x1, %l1
  sllx  %l1, L2ES_LDAC, %l0
  sllx  %l1, L2ES_VEC, %l3       ! VEC (any valid CE) not in PRM, but set by RTL
  or    %l0, %l3, %l0
  sllx  %l1, L2ES_RW, %l3        ! RW bit is set for a write (store)
  or    %l0, %l3, %l0
  mov   0x43, %l1                ! 7-bit Syndrome (for single bit error in data field)
  sllx  %l1, 21, %l3             ! Syndrome for [127:96] at [27:21]
  or    %l0, %l3, %l0
  sllx  %o7, L2ES_TID, %l3       ! ID of thread that encountered error
  or    %l0, %l3, %l0            ! %l0 has expected value

error_address:
  ! This should cause L2 LDAC (bit 53)
  ! A partial store to byte 1 -- note that error was injected on Byte 3 (be careful with Endianess)
  stb   %g0, [%g1+1]
  
  setx  L2ES_PA0, %l2, %l3
  add   %l3, L2_BANK_ADDR, %l3
check_l2_ESR:
  ldx   [%l3], %l4

  cmp   %l4, %l0
  bne   %xcc, test_fail
  nop

  setx  L2EA_PA0, %l2, %l3
  add   %l3, L2_BANK_ADDR, %l3
check_l2_EAR:
  ldx   [%l3], %l4

  ! Error address is the physical address of the cache line (PA[5:0] 0)
  andn  %g1, 0x3f, %l1
  cmp   %l4, %l1
  bne   %xcc, test_fail
  nop

  ! Data should be corrected on L2 itself (with the new partially stored data)
  xor   %g6, 0x80, %g6          ! Flip the error bit back
  mov   0xff, %l1
  sllx  %l1, 23, %l1            ! 16 + 7 (Byte position + ECC)
  andn  %g6, %l1, %g6           ! Byte changed due to the partial store 

read_l2_data_diag_again:
  ldx   [%g5], %l6
  cmp   %l6, %g6
  bne   %xcc, test_fail
  nop

  ba    test_pass
  nop

#include "err_subroutines.s"

/*******************************************************
 * Exit code
 *******************************************************/

test_pass:
ta  T_GOOD_TRAP

test_fail:
ta  T_BAD_TRAP

