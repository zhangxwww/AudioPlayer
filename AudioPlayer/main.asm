.386
.model flat,stdcall
.stack 4096
ExitProcess PROTO, dwExitCode:DWORD

include Irvine32.inc

include PlayerKernel.inc

includelib Irvine32.lib

.data

position     BYTE 64 DUP(0)
totalLen     BYTE 64 DUP(0)
volume       BYTE 64 DUP(0)

audioName    BYTE ".\\seavastskyempty.m4a", 0

quit         BYTE 0

.code
main PROC
	call Init
listen:
	call ReadChar
	.if     al == 6ch ; 'l' pressed, load audio
		invoke LoadAudio, addr audioName
	.elseif al == 73h ; 's' pressed, start playing
		invoke PlayAudio
	.elseif al == 70h ; 'p' pressed, pause
		invoke PauseAudio
	.elseif al == 72h ; 'r' pressed, resume
		invoke ResumeAudio
	.elseif al == 74h ; 't' pressed, stop
		invoke StopAudio
	.elseif al == 63h ; 'c' pressed, current position
		invoke GetCurrentPosition, addr position, length position
		mov edx, offset position
		call WriteString
		call Crlf
	.elseif al == 6ah ; 'j' pressed, jump to 
		push eax
		call ReadInt
		invoke SetCurrentPosition, eax 
		pop eax
	.elseif al == 6fh ; 'o' pressed, total length
		invoke GetTotalLength, addr totalLen, length totalLen
		mov edx, offset totalLen
		call WriteString
		call Crlf
	.elseif al == 67h ; 'g' pressed, get volume
		invoke GetVolume, addr volume, length volume
		mov edx, offset volume
		call WriteString
		call Crlf
		pop eax
	.elseif al == 76h ; 'v' pressed, change volume
		push eax
		call ReadInt
		invoke SetVolume, eax
		pop eax
	.elseif al == 71h ; 'q' pressed, quit
		invoke CloseAudio
		mov quit, 1
	.endif

	mov al, quit
	.if al == 0
		jmp listen
	.endif

	call ExitProcess
main ENDP

END main