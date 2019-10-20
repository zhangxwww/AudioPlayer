.386
.model flat,stdcall
.stack 4096
ExitProcess PROTO, dwExitCode:DWORD

include Irvine.inc
include winmm.inc
includelib winmm.lib

;PlaySound PROTO,
;        pszSound:PTR BYTE, 
;        hmod:DWORD, 
;        fdwSound:DWORD

.data
;deviceConnect BYTE "DeviceConnect",0

;SND_SYNC      DWORD 00000000h
;SND_ASYNC     DWORD 00000001h
;SND_NODEFAULT DWORD 00000002h
;SND_MEMORY    DWORD 00000004h
;SND_LOOP      DWORD 00000008h
;SND_NOSTOP    DWORD 00000010h

;SND_NOWAIT    DWORD 00002000h
;SND_ALIAS     DWORD 00010000h
;SND_ALIAS_ID  DWORD 00110000h
;SND_FILENAME  DWORD 00020000h
;SND_RESOURCE  DWORD 00040004h

;SND_SENTRY    DWORD 00080000h
;SND_RING      DWORD 00100000h
;SND_SYSTEM    DWORD 00200000h

file BYTE ".\\seavastskyempty.wav",0

;NULL DWORD 0h

.code
main PROC
	;xor eax, eax
	;or eax, SND_FILENAME
	;or eax, SND_ASYNC
	;or eax, SND_LOOP
    ;INVOKE PlaySound, OFFSET file, NULL, eax

	call ExitProcess
main ENDP
END main