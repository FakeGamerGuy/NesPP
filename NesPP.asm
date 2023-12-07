.segment "HEADER"
  ; .byte "NES", $1A      ; iNES header identifier
  .byte $4E, $45, $53, $1A
  .byte 2               ; 2x 16KB PRG code
  .byte 1               ; 1x  8KB CHR data
  .byte $01, $00        ; mapper 0, vertical mirroring

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

JSR drawtext

resetscroll:
    LDA $2002
    LDA #$00
    STA $2005
    STA $2005

enable_rendering:
  lda #%10000000	; Enable NMI
  sta $2000
  lda #%00011000	; Enable Sprites
  sta $2001
  
forever:
  jmp forever

nmi:
;  ldx #$00 	; Set SPR-RAM address to 0
;  stx $2003
;@loop:	lda hello, x 	; Load the hello message into SPR-RAM
;  sta $2004
;  inx
;  cpx #$1c
;  bne @loop


  rti

drawtext:
    LDA $2002
    LDA #$20
    STA $2006
    LDA #$41
    STA $2006
    LDX #$00
textloop:
    LDA kommsussortod,x
    CMP #$10
    BMI controlcharacter
    STA $2007
    INX
    JMP textloop
endtext:
    RTS

controlcharacter:
    CMP #$00
    
    RTS

kommsussortod:
    .byte "i wish"
    .byte $01
    .byte "that i could turn back time"
    .byte $00

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