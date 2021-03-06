; 
; Copyright (c) 2019 Andreas Zschunke
; 
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
; 
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
; 
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
; 

#include "config.inc"

.text
.global __data_start
.global __data_load_start
.global __data_load_end
.global main
main:
  ; configure IOs
  sbi WE_PORT,WE_P
  sbi WE_DDR,WE_P
  sbi LED_DDR,LED_P
  sbi RW_PORT,RW_P
  sbi RESTORE_PORT,RESTORE_P
  sbi RESET_PORT,RESET_P
  sbi OE_PORT,OE_P

#ifdef M20
  ; check for sel13 connection (check for fuse if reset is disabled)
  ldi zl,3
  ldi zh,0
  ldi rTmp,(1<<SPMEN)|(1<<BLBSET)
  out SPMCSR,rTmp
  lpm
  ldi rTmp,0
  sbrs r0,7
  ldi rTmp,1
  mov rSel13Old,rTmp
#endif

  ; set constant registers
  ldi rLookup,lo8(lookup)
  ldi rSel1418Mask,SEL14_18_MASK
  clr r00
  ldi rTmp,0xff
  mov rFF,rTmp

  ; set select slot
  ldi zh,hi8(eeDefaultSlot)
  ldi zl,lo8(eeDefaultSlot)

  ; select default
  rcall readEeprom
  andi rTmp,0x3f
  mov rSelect,rTmp
  rcall setSelect

  ; initialize sync
#ifdef DOT
  rcall syncInit
#endif

  ; reset prev and rRestoreSelect
  ldi rTmp,0xff
  mov rPrev,rTmp
  mov rRestoreSelect,rTmp

  ; configure timer0, overflow at 625Hz
#ifdef M20
  ldi rTmp,124
#endif
#ifdef DOT
  ldi rTmp,49
#endif
  out OCR0A,rTmp
  ldi rTmp,2<<WGM00
  out TCCR0A,rTmp
  ldi rTmp,4<<CS00
  out TCCR0B,rTmp

#ifdef M20
  ; configure timer2
  ldi rTmp,75
  sts OCR2A,rTmp
  ldi rTmp,85+5
  sts OCR2B,rTmp
  ldi rTmp,1<<CS20
  sts TCCR2B,rTmp
#endif

  ; copy lookup table from flash into ram
  ldi rTmp4,lo8(__data_load_end)
  ldi rTmp5,hi8(__data_load_end)
  ldi zl,lo8(__data_load_start)
  ldi zh,hi8(__data_load_start)
  ldi xl,lo8(__data_start)
  ldi xh,hi8(__data_start)
copyLoop:
    lpm rTmp,Z+
    st X+,rTmp
    cp zl,rTmp4
    cpc zh,rTmp5
    brne copyLoop

  ; reset rLed
  ldi rLed,8
  rcall setLed

  ; enable restore key interrupt
  ldi rTmp,2<<ISC00
  sts EICRA,rTmp
  sbi EIMSK,INT0

  ; enable reset interrupt
  ldi rTmp,1<<RESET_INT
  sts RESET_INTMSK,rTmp
  ldi rTmp,1<<RESET_IE
  sts PCICR,rTmp

mainBegin:
  cli
  ; clear pending interrupts
  sbi EIFR,INTF0
  sbi PCIFR,RESET_IE
  
  ldi rTmp,hi8(__stack)
  out SPH,rTmp
  ldi rTmp,lo8(__stack)
  out SPL,rTmp
  sei

  rjmp mainLoop

