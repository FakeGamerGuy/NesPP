.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005
PPUADDR = $2006
PPUDATA = $2007
DELAYSET = $00
DELAYCOUNTER = $01
BOXH = $02
BOXL = $03
TEXTH = $04
TEXTL = $05

.segment "VECTORS"
  ;; When an NMI happens (once per frame if enabled) the label nmi:
  .addr nmi
  ;; When the processor first turns on or is reset, it will jump to the label reset:
  .addr reset
  ;; External interrupt IRQ (unused)
  .addr 0

; "nes" linker config requires a STARTUP section, even if it's empty
.segment "STARTUP"

; Main code segment for the program
.segment "CODE"

reset:
  sei		; disable IRQs
  cld		; disable decimal mode
  ldx #$40
  stx $4017	; disable APU frame IRQ
  ldx #$ff 	; Set up stack
  txs		;  .
  inx		; now X = 0
  stx $2000	; disable NMI
  stx $2001 	; disable rendering
  stx $4010 	; disable DMC IRQs

;; first wait for vblank to make sure PPU is ready
vblankwait1:
  bit $2002
  bpl vblankwait1

clear_memory:
  lda #$00
  sta $0000, x
  sta $0100, x
  sta $0200, x
  sta $0300, x
  sta $0400, x
  sta $0500, x
  sta $0600, x
  sta $0700, x
  inx
  bne clear_memory

;; second wait for vblank, PPU is ready after this
vblankwait2:
  bit $2002
  bpl vblankwait2

main:
load_palettes:
  lda $2002
  lda #$3f
  sta $2006
  lda #$00
  sta $2006
  ldx #$00
@loop:
  lda palettes, x
  sta $2007
  inx
  cpx #$20
  bne @loop

clearbackground:
    LDA $2002   ; Reset PPU latch
    LDA #$20    ; Store $2000 to PPUADDR
    STA $2006
    LDA #$00
    STA $2006
    LDA #$03
    LDY #$04
@loopy:
    LDX #$00
@loopx:
    STA $2007
    DEX
    BNE @loopx
    DEY
    BNE @loopy

resetscroll:
    LDA $2002
    LDA #$00
    STA $2005
    STA $2005

    JSR enablerendering

    JSR drawbox
    JSR drawtext

forever:
  jmp forever

nmi:
    LDA PPUSTATUS
    LDA #$00
    STA PPUSCROLL
    STA PPUSCROLL
  rti

disablerendering:
    LDA #$00
    STA PPUCTRL
    STA PPUMASK
    RTS

enablerendering:
    lda #%10000000	; Enable NMI
    sta $2000
    lda #%00011000	; Enable Sprites, background
    sta $2001
    RTS

drawtext:
    JSR disablerendering
    LDA PPUSTATUS
    LDA #$22
    STA TEXTH
    STA PPUADDR
    LDA #$62
    STA TEXTL
    STA PPUADDR   ; Text origin is $2263
    LDX #$00
textloop:
    LDA fly_me_to_the_moon,x

; Control characters are $00-$03, but $00-$0F are being reserved.
; To check if the next character is text or a control character,
; we need to compare the character (loaded in A) to $10.
; The lowest value for a printed character should be $20.
; $10 - $20 = ($-10). This should set the N flag. We should be able
; to use BMI to jump if N is set (if a control character is detected).

    CMP #$10
    BMI control_character   ; For now, exiting the loop when we get to $01 should
                  ; prove functionality.

print_letter:
    STA PPUDATA
    INX
    JMP textloop
endtext:
    JSR enablerendering
    RTS
control_character:
    CMP #$00      ; Exit the text printing loop
    BEQ endtext
    CMP #$0A      ; Start printing on the next line
    LDA TEXTL
    CLC
    ADC #$20
    STA TEXTL
    LDA PPUSTATUS
    LDA TEXTH
    STA PPUADDR
    LDA TEXTL
    STA PPUADDR
    INX
    JMP textloop
textdelay:
    LDA DELAYSET
    STA DELAYCOUNTER
delayloop:
    bit $2002
    bpl delayloop
    DEC DELAYCOUNTER
    BNE delayloop
    RTS

drawbox:
    JSR disablerendering
; Set top-left box coordinates    
    LDA PPUSTATUS
    LDA #$22
    STA BOXH
    STA PPUADDR
    LDA #$21
    STA BOXL
    STA PPUADDR
    LDA #$77
    STA PPUDATA
; Draw top row
    LDA #$78
    LDX #$1D
@top_loop:  
    STA PPUDATA
    DEX
    BNE @top_loop
    LDA #$79
    STA PPUDATA
; Draw middle rows
; Increment the box origin by $20 (down 1 row)
    LDY #$08
@middle_height:
    JSR box_new_row
    LDA PPUSTATUS
    LDA BOXH
    STA PPUADDR
    LDA BOXL
    STA PPUADDR
    LDA #$7A
    STA PPUDATA
    LDA #$03
    LDX #$1D
  @middle_loop:
    STA PPUDATA
    DEX
    BNE @middle_loop
    LDA #$7C
    STA PPUDATA
    DEY
    BNE @middle_height
; Draw bottom row
    JSR box_new_row
    LDA PPUSTATUS
    LDA BOXH
    STA PPUADDR
    LDA BOXL
    STA PPUADDR
    LDA #$7D
    STA PPUDATA
    LDA #$7E
    LDX #$1D
@bottom_loop:  
    STA PPUDATA
    DEX
    BNE @bottom_loop
    LDA #$7F
    STA PPUDATA
    JSR enablerendering
    RTS

box_new_row:
    LDA BOXL
    CLC
    ADC #$20
    STA BOXL
    LDA BOXH
    ADC #$00
    STA BOXH
    RTS

kommsussortod:
    .byte "i wish", $01
    .byte "that i could turn back time", $01
    .byte "cos now the guilt is all mine", $01
    .byte "can't live without", $01
    .byte "the trust from those you love", $00

fly_me_to_the_moon:
    .incbin "test_text.txt"

hello:
  .byte $00, $00, $00, $00 	; Why do I need these here?
  .byte $00, $00, $00, $00
  .byte $6c, $00, $00, $6c
  .byte $6c, $01, $00, $76
  .byte $6c, $02, $00, $80
  .byte $6c, $02, $00, $8A
  .byte $6c, $03, $00, $94

palettes:
  ; Background Palette
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

  ; Sprite Palette
  .byte $0f, $20, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00
  .byte $0f, $00, $00, $00

; Character memory
.segment "CHARS"
    .incbin "LightsOut-newButtons.chr", $00, $1000