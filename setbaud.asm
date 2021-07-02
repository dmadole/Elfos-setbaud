; This software is copyright 2021 by David S. Madole.
; You have permission to use, modify, copy, and distribute
; this software so long as this copyright notice is retained.
; This software may not be used in commercial applications
; without express written permission from the author.
;
; The author grants a license to Michael H. Riley to use this
; code for any purpose he sees fit, including commercial use,
; and without any need to include the above notice.


           ; Include kernal API entry points

           include bios.inc
           include kernel.inc

           ; Define non-published API elements

d_type     equ     0444h

           ; Executable program header

           org     2000h - 6
           dw      start
           dw      end-start
           dw      start

start:     org     2000h
           br      main

           ; Build information

           db      7+80h              ; month
           db      1                  ; day
           dw      2021               ; year
           dw      1                  ; build
           db      'Written by David S. Madole',0

           ; Main code starts here

main:      ldi     20000.1            ; Default clock speed is 4000 KHz
           phi     rc                 ; times 5 to give baud rate factor,
           ldi     20000.0            ; which is clock in Hertz divded by 8
           plo     rc                 ; then divided by 25

skipspc1:  lda     ra                 ; skip any whitespace
           lbz     showhelp
           smi     '!'
           lbnf    skipspc1

           smi     '-'-'!'            ; if next character is not a dash,
           lbnz    getbaud            ; then no option

           lda     ra                 ; if option is not 'k' then it is
           smi     'k'                ; not valid
           lbnz    showhelp

skipspc2:  lda     ra                 ; skip any whitespace
           lbz     showhelp
           smi     '!'
           lbnf    skipspc2

           dec     ra                 ; back up to non-whitespace character

           ghi     ra                 ; move input pointer to rf
           phi     rf
           glo     ra
           plo     rf

           sep     scall              ; parse input number
           dw      f_atoi
           lbdf    showhelp           ; if not a number then abort

           ghi     rf                 ; save updated pointer to just past
           phi     ra                 ; number back into ra
           glo     rf
           plo     ra

           ldi     0                  ; multiply clock in khz by 5
           phi     rf
           ldi     5
           plo     rf

           sep     scall              ; do multiply
           dw      f_mul16

           ghi     rc                 ; if more than a word, then out of
           lbnz    notvalid           ; range and not valid
           glo     rc
           lbnz    notvalid

           ghi     rb
           phi     rc
           glo     rb
           plo     rc

skipspc3:  lda     ra                 ; skip any whitespace
           lbz     showhelp
           smi     '!'
           lbnf    skipspc3

getbaud:   dec     ra                 ; back up to non-whitespace character

           ghi     ra                 ; move input pointer to rf
           phi     rf
           glo     ra
           plo     rf

           sep     scall              ; parse input number
           dw      f_atoi
           lbdf    showhelp           ; if not a number then abort

           ghi     re                 ; check if hardware uart is in use
           ani     0feh               ;  if so, set through bios call
           lbz     setuart

           smi     0feh               ; check if non-serial console in use
           lbz     noserial           ;  if so, not legal

           ghi     rd                 ; transfer baud rate to rf to be
           phi     rf                 ;  divisor for f_div16
           glo     rd
           plo     rf

           ldi     0                  ; divide baud rate by 25 to scale
           phi     rd                 ;  values to be managable in 16 bits
           ldi     25
           plo     rd

           sep     scall              ; divide baud rate by 25
           dw      f_div16

           ghi     rb                 ; move quotient to divisor
           phi     rd
           glo     rb
           plo     rd

           ghi     rc                 ; get scaled clock rate into dividend
           phi     rf
           glo     rc
           plo     rf

           sep     scall              ; divide scaled clock rate by
           dw      f_div16            ;  scaled baud rate

           ; Decide which UART is being used

           ldi     high d_type        ; check where o_type points
           phi     rf
           ldi     low d_type
           plo     rf

           inc     rf                 ; skip lbr instruction

           ldn     rf                 ; if routine is not in bios then
           smi     0f8h               ;  assume nitro is in use
           lbnf    setnitro


           ; Convert and compress the resulting value for BIOS

setbios:   glo     rb                 ; subtract fixed overhead of 32
           smi     32                 ;  move into dividend
           plo     rf
           ghi     rb
           smbi    0
           phi     rf

           lbnf    notvalid           ; if negative then not valid

           ldi     0                  ; set divisor to 8 cycles per count
           phi     rd
           ldi     8
           plo     rd

           sep     scall              ; divide cycles by 8
           dw      f_div16

           ghi     rb                 ; if greater than 255 not valid
           lbnz    notvalid

           glo     rb                 ; pack into proper format, shift into
           shl                        ;  bits 1-7 and set bit 0 for echo
           ori     1
           lbdf    notvalid           ; if overflowed then not valid

           phi     re                 ; set into baud rate register
           sep     sret               ;  and return


           ; Convert and compress the resulting value for nitro

setnitro:  glo     rb                 ; subtract fixed overhead of 24
           smi     24                 ;  cycles from calculated delay
           plo     rb
           ghi     rb
           smbi    0
           phi     rb

           lbz     goodbaud           ; if rate is 0-255 then its good

           inc     rb                 ; if value is -1 then that's valid also
           ghi     rb                 ;  but roll it to zero; this adjustment
           lbnz    notvalid           ;  is for 9600 baud on 1.8 Mhz clock

goodbaud:  ldi     63                 ; pre-load this value that we will
           plo     re                 ;  need in the calculations later

           glo     rb                 ; subtract 63 from time, if less than
           smi     63                 ;  this, then keep the result as-is
           lbnf    timekeep

timediv3:  smi     3                  ; otherwise, divide the excess part
           inc     re                 ;  by three, adding to the 63 we saved
           lbdf    timediv3           ;  earlier so results are 64-126

           glo     re                 ; get result of division plus 63
           phi     rb                 ;  and save over raw measurement

timekeep:  ghi     rb                 ; get final result and shift left one
           shl                        ;  bit to make room for echo flag, then
           adi     2+1                ;  add 1 to baud rate and set echo flag
           phi     re                 ;  then store formatted result

           sep     sret

           ; Set UART via BIOS

setuart:   ldi     high baudtbl       ; get index to table of baud rates
           phi     rf
           ldi     low baudtbl
           plo     rf

           ldi     0                  ; count table entries as we compare
           plo     re

           sex     rf                 ; subtract table values in loop,
           lbr     search             ;  jump into loop

jump1:     inc     rf                 ; advance to next table entry
jump2:     inc     rf
           inc     re                 ; count another entry checked

search:    ldn     rf                 ; zero msb means end of table
           lbz     notvalid

           ghi     rd                 ; compare msb of rate
           sm
           lbnz    jump1

           inc     rf

           glo     rd                 ; compare lsb of rate
           sm
           lbnz    jump2

           glo     re                 ; add 8 data bits no parity
           ori     30h

           sep     scall              ; set baud rate of uart
           dw      f_usetbd
           lbdf    notvalid           ; if setting failed

           sep     sret


baudtbl:   dw      300                ; list of bios supported baud rates
           dw      1200               ;  in order of index value
           dw      2400
           dw      4800
           dw      9600
           dw      19200
           dw      38400
           dw      0

           ; Baudrate is not valid or out of range

notvalid:  sep     scall
           dw      o_inmsg
           db      'ERROR: Baud rate is not valid',13,10,0
           sep     sret

           ; Display usage if there is a syntax problem

showhelp:  sep     scall
           dw      o_inmsg
           db      'USAGE: setbaud [-k clockkhz] baudrate',13,10,0
           sep     sret

           ; Can't set the baud rate if not a serial port

noserial:  sep     scall
           dw      o_inmsg
           db      'ERROR: Console is not serial port',13,10,0
           sep     sret


end:       ; That's all folks!

