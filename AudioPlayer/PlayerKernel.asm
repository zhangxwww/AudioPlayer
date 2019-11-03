.386
.model flat,stdcall
.stack 4096

include Irvine32.inc
includelib Irvine32.lib
include \masm32\include\winmm.inc

include PlayerKernel.inc

includelib \masm32\lib\winmm.lib
includelib \masm32\lib\masm32.lib

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

LRCBufferSize equ 20000

LRC_buffer     BYTE LRCBufferSize DUP(0)

atodw				proto :DWORD								
StringToInt			equ <atodw>

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
	mov	edx, audioNameAddr
	call WriteString
	call Crlf
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
	;mov edx, returnAddr
	;call WriteString
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


parseLRC proc uses ebx ecx edx esi edi szLRCFileName:DWORD, timeIntArrayAddr:DWORD, lyricsReturnAddr:DWORD, maxCount:DWORD
	local lastBytePosition:DWORD ; �洢����ļ����ݵĻ����������һ���ֽڵ��ڴ�λ��
	local minute:WORD ; �洢����ʱ��ʱ�ķ���һλ������
	local second:WORD ; �洢����ʱ��ʱ����һλ������
	local millisecond:WORD ; �洢����ʱ��ʱ�ĺ���һλ������
	local time:DWORD ; �洢ʱ���������ֵ�������λΪms��
	local TimeStartPos:DWORD ; �洢����ʱ��ʱ'['��λ��
	local TimeEndPos:DWORD ; �洢����ʱ��ʱ']'��λ��
	local szLRCFileHandle:HANDLE
	local Count:DWORD ; �����ĸ������
	local nextLyricPtr:DWORD ; ָ��lyricsReturnAddr�洢��һ���ֽڵ�ָ��
	;���ļ��ͳ�ʼ��
	mov eax, lyricsReturnAddr
	mov nextLyricPtr, eax
	mov Count, 0
	mov lyricsReturnAddr, 0
	mov edx, szLRCFileName
	call OpenInputFile
	mov szLRCFileHandle, eax
	;����ļ��Ƿ���ȷ��
	cmp eax, INVALID_HANDLE_VALUE
	je quit
	;�ļ����ݶ��뻺����
	mov edx, OFFSET LRC_buffer
	mov ecx, LRCBufferSize
	call ReadFromFile
	jnc check_buffer_size
	je quit ; �ļ���ȡ�����˳�
	;��黺�����Ƿ��㹻��
	check_buffer_size:
		cmp eax, LRCBUfferSize
		jb buf_size_ok
		jmp quit

	buf_size_ok:
		mov LRC_buffer[eax], 0 ; ����ս�����

	
	mov ebx, OFFSET LRC_buffer

	ParseLoop: ; ѭ����ʼǰ��ebxָ�����ѭ���п�ʼ�������ڴ�λ��
		; Find next '[' and store its position in TimeStartPos
		FindNextLeftBracket:
			inc ebx
			cmp ebx, lastBytePosition
			ja quit
			mov eax, [ebx]
			cmp eax, '['
			jne FindNextLeftBracket
		mov TimeStartPos, ebx
		; Find next ']' and store its position in TimeEndPos
		mov ecx, ebx
		FindNextRightBracket:
			inc ecx
			cmp ecx, lastBytePosition
			ja quit
			mov eax, [ebx]
			cmp eax, ']'
			jne FindNextRightBracket
		mov TimeEndPos, ecx
		; Convert "[mm:ss.ms]"-formatted time to the corresponding value in ms and store the result in timeReturnAddr

		mov esi, TimeStartPos
		FindColon:  ; store the position of colon in esi
			inc esi
			cmp esi, lastBytePosition
			ja quit
			mov eax, [esi]
			cmp eax, ':'
			jne FindColon
		mov byte ptr [esi], 0
		invoke StringToInt, ebx
		mov minute, ax
		mov eax, 3600
		mul minute
		shl edx, 16
		and eax, 0FFFFh
		add eax, edx
		mov time, 0
		add time, eax ; change local variable time according to minute

		mov esi, TimeStartPos
		FindDot:
			inc esi
			cmp esi, lastBytePosition
			ja quit
			mov eax, [esi]
			cmp eax, '.'
			jne FindDot
		mov byte ptr [esi], 0
		invoke StringToInt, ebx
		mov second, ax
		mov eax, 60
		mul minute
		shl edx, 16
		and eax, 0FFFFh
		add eax, edx
		add time, eax ; change local variable time according to minute

		inc esi
		invoke StringToInt, ebx
		mov millisecond, ax
		mov eax, 60
		mul millisecond
		shl edx, 16
		and eax, 0FFFFh
		add eax, edx
		add time, eax ; change local variable time according to minute

		;�޸�count��timeIntArrayAddr
		mov ecx, count
		cmp ecx, maxCount
		jae quit
		mov eax, count
		inc eax
		mov count, eax
		mov esi, timeIntArrayAddr
		mov ecx, count
		setTime:
			add esi, 4
			loop setTime
		sub esi, 4
		mov ecx, time
		mov DWORD ptr [esi], ecx

		;�������
		mov esi, TimeEndPos
		inc esi
		mov edi, nextLyricPtr
		L9:
			mov eax, [esi]
			cmp eax, 0
			je L10
			cmp eax, '['
			je L10
			cmp eax, '\r'
			je L10
			cmp eax, '\n'
			je L10
			mov [edi], eax
			inc esi
			inc edi
			jmp L9
		L10:
			mov ecx, 0
			mov [edi], ecx
			inc edi
			mov nextLyricPtr, edi
			mov ebx, esi

		jmp ParseLoop

	quit:
		mov eax, szLRCFileHandle
		call CloseFile
		mov eax, count
		ret
parseLRC endp

END