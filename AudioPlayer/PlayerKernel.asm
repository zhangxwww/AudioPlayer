.386
.model flat,stdcall
.stack 4096

include winmm.inc
include Irvine32.inc

include PlayerKernel.inc

includelib winmm.lib
includelib masm32.lib
includelib Irvine32.lib

dw2a PROTO :DWORD, :DWORD

.data
command_s      BYTE 64 DUP(0)
buffer_s       BYTE 64 DUP(0)

openSeq_s      BYTE "open sequencer", 0
loadprefix_s   BYTE "open ", 0
loadsuffix_s   BYTE " alias audio", 0
setFmt_s       BYTE "Set audio time format ms", 0
playAudio_s    BYTE "play audio", 0
pauseAudio_s   BYTE "pause audio", 0
resumeAudio_s  BYTE "resume audio", 0
stopAudio_s    BYTE "stop audio", 0
closeAudio_s   BYTE "close audio", 0
curPosition_s  BYTE "status audio position", 0
totalLength_s  BYTE "status audio length", 0
getVolume_s    BYTE "status audio volume", 0
chgVlmPrefix_s BYTE "setaudio audio volume to ", 0
chgVlmSuffix_s BYTE 0
setPosPrefix_s BYTE "seek audio to ", 0
setPosSuffix_s BYTE 0

.code
Str_concat PROC USES esi edi eax targetAddress:DWORD, sourceAddress:DWORD 
	mov esi, targetAddress
	lodsb
	.while al > 0
		lodsb
	.endw
	dec esi
	mov edi, esi
	mov esi, sourceAddress
	.repeat
		lodsb
		stosb
	.until al == 0
	ret
Str_concat ENDP

Run_cmd PROC cmdAddr:DWORD
	invoke mciSendString, cmdAddr, 0, 0, 0
	ret
Run_cmd ENDP

Run_cmd_return PROC cmdAddr:DWORD, returnAddr:DWORD, len:DWORD
	invoke mciSendString, cmdAddr, returnAddr, len, 0
	ret
Run_cmd_return ENDP

Init PROC 
	invoke Run_cmd, addr openSeq_s
	ret
Init ENDP

LoadAudio PROC audioNameAddr:DWORD
	invoke Str_copy, addr loadprefix_s, addr command_s
	invoke Str_concat, addr command_s, audioNameAddr
	invoke Str_concat, addr command_s, addr loadsuffix_s
	invoke Run_cmd, addr command_s
	invoke Run_cmd, addr setFmt_s
	ret
LoadAudio ENDP

PlayAudio PROC
	invoke Run_cmd, addr playAudio_s
	ret
PlayAudio ENDP

PauseAudio PROC
	invoke Run_cmd, addr pauseAudio_s
	ret
PauseAudio ENDP

ResumeAudio PROC
	invoke Run_cmd, addr resumeAudio_s
	ret
ResumeAudio ENDP

StopAudio PROC
	invoke Run_cmd, addr stopAudio_s
	ret
StopAudio ENDP
		
GetCurrentPosition PROC returnAddr:DWORD, bufsize:DWORD
	invoke Run_cmd_return, addr curPosition_s, returnAddr, bufsize
	ret
GetCurrentPosition ENDP

SetCurrentPosition PROC pos:DWORD
	invoke dw2a, pos, addr buffer_s
	invoke Str_copy, addr setPosPrefix_s, addr command_s
	invoke Str_concat, addr command_s, addr buffer_s
	invoke Str_concat, addr command_s, addr setPosSuffix_s
	invoke Run_cmd, addr command_s
	invoke PlayAudio
	ret
SetCurrentPosition ENDP

GetTotalLength PROC returnAddr:DWORD, bufsize:DWORD
	invoke Run_cmd_return, addr totalLength_s, returnAddr, bufsize
	ret
GetTotalLength ENDP

GetVolume PROC returnAddr:DWORD, bufsize:DWORD
	invoke Run_cmd_return, addr getVolume_s, returnAddr, bufsize
	ret
GetVolume ENDP

SetVolume PROC vol:DWORD
	invoke dw2a, vol, addr buffer_s
	invoke Str_copy, addr chgVlmPrefix_s, addr command_s
	invoke Str_concat, addr command_s, addr buffer_s
	invoke Str_concat, addr command_s, addr chgVlmSuffix_s
	invoke Run_cmd, addr command_s
	ret
SetVolume ENDP

CloseAudio PROC
	invoke Run_cmd, addr closeAudio_s
	ret
CloseAudio ENDP

END