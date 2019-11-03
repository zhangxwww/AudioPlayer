.386
.model flat,stdcall
option casemap:none

WinMain 			proto :DWORD, :DWORD, :DWORD, :DWORD		;主窗口过程
MessageBoxA			proto :DWORD, :DWORD, :DWORD, :DWORD		;用于构建MessageBox
MessageBox 			equ <MessageBox> 							;用于显示错误消息								
BrowseFolder		equ <SHBrowseForFolder>						;用于打开文件夹对话框
BrowseFile			equ <GetOpenFileName>						;用于打开文件对话框
promptError			proto 										;错误提示
SelectFile			proto										;用于打开文件对话框并存储文件名字符串
GetPosFromPerc		proto perc:DWORD							;用于从百分比获取播放进度
GetVolumeFromPerc   proto perc:DWORD
GetPercFromPos		proto pos:DWORD								;用于从进度获取百分比
GetLyricFromPos		proto pos:DWORD, res:DWORD					;用于根据毫秒播放进度获取当前歌词
GotoPrevSong        proto :DWORD                                ;播放上一首歌曲
GotoNextSong        proto :DWORD                                ;播放下一首歌曲
PlayAnotherSong     proto :DWORD,:DWORD                         ;播放另一首歌曲
RepaintPlayList     proto		                                ;绘制播放列表
convertTimeToString proto :DWORD, :DWORD                        ;将ms格式的DWORD类型的时间转换成m:s格式的时间
copystring          proto :DWORD,:DWORD                         ;将edx内存储的数字转换成字符串
atodw				proto :DWORD								
StringToInt			equ <atodw>
dwtoa               proto :DWORD, :DWORD
IntToString         equ <dwtoa>
WriteString			proto
WriteInt			proto
Crlf				proto
include 	\masm32\include\windows.inc
include 	\masm32\include\user32.inc
include 	\masm32\include\kernel32.inc
include		\masm32\include\shell32.inc
include		\masm32\include\comdlg32.inc
include		\masm32\include\comctl32.inc
include		\masm32\include\gdi32.inc
include		\masm32\include\advapi32.inc
include		\masm32\include\netapi32.inc
include		\masm32\include\ws2_32.inc
include		\masm32\include\winmm.inc
include		PlayerKernel.inc

includelib 	\masm32\lib\user32.lib
includelib 	\masm32\lib\kernel32.lib
includelib	\masm32\lib\shell32.lib
includelib  \masm32\lib\comdlg32.lib
includelib	\masm32\lib\comctl32.lib
includelib	\masm32\lib\gdi32.lib
includelib	\masm32\lib\advapi32.lib
includelib	\masm32\lib\netapi32.lib
includelib	\masm32\lib\ws2_32.lib
includelib	\masm32\lib\winmm.lib
;includelib  Irvine32.lib

.data
ClassName 			BYTE "SimpleWinClass", 0
AppName  			BYTE "Audio Player", 0
ButtonClassName 	BYTE "button", 0
EditClassName 		BYTE "edit", 0
ListBoxClassName    BYTE "listbox", 0
TrackbarClassName 	BYTE "msctls_trackbar32", 0


errorwinTittle 		BYTE "Error", 0
errorMsg 			BYTE "Error emerges", 0

ButtonOpenText 		BYTE "Open", 0
ButtonPlayText 		BYTE "Play", 0
ButtonPauseText		BYTE "Pause", 0
ButtonStopText		BYTE "Stop", 0
ButtonVolumeText	BYTE "Vol", 0
ButtonModeText0     BYTE "LOOP", 0
ButtonModeText1     BYTE "RANDOM", 0
ButtonNextsongText  BYTE "Next song", 0
ButtonPrevsongText  BYTE "Prev song", 0
LoadFailureTitle    BYTE "Warning", 0
LoadFailureText     BYTE "Failed to load the selected audio file!", 0
nullLyricText 		BYTE "No lyrics found."
maxFileNum          equ 5
maxFileNameLength   equ 512
maxLyricLength		equ 128
maxLyricNum			equ 512

szFilter			BYTE "Media Files", 0, "*.mp3;*.wav;*.m4a", 0
szFileNameList		BYTE maxFileNum*maxFileNameLength DUP(0) ; 存储列表中的歌曲对应的FileName的数组，最多存maxFileNum个FileName，每个的长度最大为maxFileNameLength
szFileNameOpen		BYTE maxFileNameLength DUP(0)
lyricName			BYTE maxFileNameLength DUP(0)
szFileNameToDisplay BYTE maxFileNameLength DUP(0)
szFileNum           DWORD 0 								 	;列表中的歌曲数(最大为maxFileNum)
szFilePos           DWORD 0 									;正在播放列表的哪一首(若列表中有歌曲，该值最小为1)
AudioOn				DWORD 0
AudioLoaded			DWORD 0
position_s     		BYTE 64 DUP(0)
volume_s			BYTE 64 DUP(0)
totalLen_s     		BYTE 64 DUP(0)
totalLen			DWORD 0
CurrentTime_s       BYTE 64 DUP(0) 								;以m:s格式显示的当前已播放的时间
TotalTime_s         BYTE 64 DUP(0) 								;以m:s格式显示的歌曲总时长
timezero_s          BYTE "0:0", 0
position			DWORD 0
volume				DWORD 0
CurrentVolShow  	DWORD 0
mode                DWORD 0 									;存储音乐播放模式，0为循环播放，1为随机播放
lyric_time			DWORD maxLyricNum DUP(0) 					;存储LRC格式歌词中的毫秒时间点
lyric_content		BYTE  maxLyricLength*maxLyricNum DUP(0)  	;存储LRC格式歌词中的所有歌词字符串
current_lyric		BYTE  maxLyricLength DUP(0)					;存储当前歌词
total_lyric_num		DWORD 0										;歌词的数量
DEBUG           DWORD 1

.data?
hInstance 		HINSTANCE ?

ButtonOpen 		HWND ?
ButtonPlay 		HWND ?
ButtonStop		HWND ?
ButtonNextsong  HWND ?
ButtonPrevsong  HWND ?
ButtonVolume	HWND ?
ButtonMode      HWND ?
hwndEdit 		HWND ?
TotalTime       HWND ?
CurrentTime     HWND ?
Trackbar		HWND ?
Soundbar		HWND ?
PlayList        HWND ?
LyricList		HWND ?

buffer 		BYTE  512 dup(?)	;缓冲区

.const

EditID 			equ 1
ButtonOpenID 	equ 2
ButtonPlayID	equ 3
ButtonStopID	equ 4
TrackbarID		equ 6
SoundbarID      equ 5
ButtonVolumeID  equ 6
ButtonModeID    equ 7
ButtonPrevsongID equ 8
ButtonNextsongID equ 9
TotalTimeID     equ 10
CurrentTimeID   equ 11
LyricListID 	equ 12

totalVolume		equ 1000

IDM_CLEAR 		equ 21
IDM_EXIT 		equ 22
IDM_APPEND 		equ 23
IDM_BROWSE		equ 24
IDM_PLAY		equ 25
IDM_PAUSE		equ 26
IDM_STOP		equ 27
IDM_PROG		equ 28
IDM_UPDATE		equ 29
IDM_VOLUME      equ 30
IDM_SHOWVOL 	equ 31
IDM_CHANGEMODE  equ 32
IDM_PREVSONG    equ 33
IDM_NEXTSONG    equ 34

PlayTimerID		equ 51
PlayListID      equ 52
ElapsedTime		equ 1000

PlayAnotherSong_and_DoNothing equ 0
PlayAnotherSong_and_AddToList equ 1   

.code
start:
	invoke GetModuleHandle, NULL
	mov    hInstance,eax
	invoke WinMain, hInstance,NULL,NULL, SW_SHOWDEFAULT
	invoke ExitProcess,eax

WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
	local wc:WNDCLASSEX
	local msg:MSG
	local hwnd:HWND
	mov   wc.cbSize,SIZEOF WNDCLASSEX
	mov   wc.style, CS_HREDRAW or CS_VREDRAW
	mov   wc.lpfnWndProc, OFFSET WndProc
	mov   wc.cbClsExtra,NULL
	mov   wc.cbWndExtra,NULL
	push  hInst
	pop   wc.hInstance
	mov   wc.hbrBackground,COLOR_BTNFACE+1
	mov   wc.lpszClassName,OFFSET ClassName
	invoke LoadIcon,NULL,IDI_APPLICATION
	mov   wc.hIcon,eax
	mov   wc.hIconSm,eax
	invoke LoadCursor,NULL,IDC_ARROW
	mov   wc.hCursor,eax
	invoke RegisterClassEx, ADDR wc
	;创建主窗口
	invoke CreateWindowEx,WS_EX_CLIENTEDGE,ADDR ClassName,ADDR AppName,\
           WS_OVERLAPPEDWINDOW,CW_USEDEFAULT,\
           CW_USEDEFAULT,400,600,NULL,NULL,\
           hInstance,NULL
	mov   hwnd,eax
	invoke ShowWindow, hwnd,SW_SHOWNORMAL
	invoke UpdateWindow, hwnd

	;消息处理循环
	.WHILE TRUE
                invoke GetMessage, ADDR msg,NULL,0,0
                .BREAK .IF (!eax)
                invoke TranslateMessage, ADDR msg
                invoke DispatchMessage, ADDR msg
	.ENDW
	mov     eax,msg.wParam
	ret
WinMain endp

promptError proc
	pushad
	invoke MessageBox,NULL,ADDR errorMsg,ADDR errorwinTittle,MB_OK
	popad
	ret
promptError	endp

WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	.IF uMsg==WM_DESTROY
		invoke PostQuitMessage,NULL
	;创建窗口时的初始化动作
	.ELSEIF uMsg==WM_CREATE
		;添加当前播放的歌曲文本框
		invoke Init
		invoke CreateWindowEx,WS_EX_CLIENTEDGE, ADDR EditClassName,NULL,\
                        WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT or\
                        ES_AUTOHSCROLL,\
                        30,30,300,30,hWnd,EditID,hInstance,NULL
		mov  hwndEdit, eax
		invoke SetFocus, hwndEdit
		;添加播放时间信息文本框
		invoke CreateWindowEx, NULL, ADDR EditClassName, NULL, \
						WS_CHILD or WS_VISIBLE or WS_BORDER or ES_CENTER, \
						220, 70, 50, 25, hWnd, CurrentTimeID, hInstance, NULL
		mov CurrentTime, eax
		invoke CreateWindowEx, NULL, ADDR EditClassName, NULL, \
						WS_CHILD or WS_VISIBLE or WS_BORDER or ES_CENTER, \
						280, 70, 50, 25, hWnd, TotalTimeID, hInstance, NULL
		mov TotalTime, eax
		;添加按钮
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonOpenText,\
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        30,110,80,30,hWnd,ButtonOpenID,hInstance,NULL
		mov  ButtonOpen, eax
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonPlayText,\
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        120,110,80,30,hWnd,ButtonPlayID,hInstance,NULL
		mov  ButtonPlay, eax
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonStopText,\
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        210,110,80,30,hWnd,ButtonStopID,hInstance,NULL
		mov  ButtonStop, eax
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonVolumeText,\
                        WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON,\
                        325,110,50,30,hWnd,ButtonVolumeID,hInstance,NULL
		mov  ButtonVolume, eax
		invoke CreateWindowEx, NULL, ADDR ButtonClassName, ADDR ButtonModeText0, \
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        30,150,80,30,hWnd,ButtonModeID,hInstance,NULL
		mov  ButtonMode, eax	
		invoke CreateWindowEx, NULL, ADDR ButtonClassName, ADDR ButtonPrevsongText, \
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        120,150,80,30,hWnd,ButtonPrevsongID,hInstance,NULL
		mov  ButtonPrevsong, eax
		invoke CreateWindowEx, NULL, ADDR ButtonClassName, ADDR ButtonNextsongText, \
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        210,150,80,30,hWnd,ButtonNextsongID,hInstance,NULL
		mov  ButtonNextsong, eax
		;添加歌词列表和播放列表
		invoke CreateWindowEx,WS_EX_CLIENTEDGE, ADDR EditClassName,NULL,\
                        WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT or\
                        ES_AUTOHSCROLL,\
                        20,400,300,60,hWnd,LyricListID,hInstance,NULL
		mov LyricList, eax
		invoke CreateWindowEx, NULL, ADDR ListBoxClassName, NULL, \
						WS_CHILD or WS_VISIBLE or WS_BORDER or WS_VSCROLL or LBS_NOTIFY or WS_HSCROLL,\
                        20,190,300,200,hWnd,PlayListID,hInstance,NULL
		mov PlayList, eax
		;添加进度条
		invoke CreateWindowEx,NULL, ADDR TrackbarClassName,NULL,\
                        WS_CHILD or WS_VISIBLE or TBS_NOTICKS or TBS_TRANSPARENTBKGND,\
                        30,70,180,30,hWnd,TrackbarID,hInstance,NULL
		mov  Trackbar, eax
		;添加音量控制条
		invoke CreateWindowEx, NULL, ADDR TrackbarClassName, NULL, \
						WS_CHILD or WS_VISIBLE or TBS_NOTICKS or TBS_VERT or TBS_TRANSPARENTBKGND,\
                        345,30,30,80,hWnd,SoundbarID,hInstance,NULL
		mov  Soundbar, eax
		;初始化音量控制条位置、是否可见
		pushad
		invoke SendMessage, Soundbar, TBM_SETPOS, TRUE, 0
		popad
		invoke ShowWindow, Soundbar, SW_HIDE
		;变量初始化
		mov volume, 1000
	.ELSEIF uMsg == WM_TIMER
		invoke SendMessage, hWnd, WM_COMMAND, IDM_UPDATE, NULL
	.ELSEIF uMsg == WM_HSCROLL
		mov	eax, wParam
		.IF ax == TB_ENDTRACK
			push eax
			invoke SendMessage, Trackbar, TBM_GETPOS, 0, 0
			invoke SendMessage, hWnd, WM_COMMAND, IDM_PROG, eax
			pop eax
		.ENDIF
	.ELSEIF uMsg == WM_VSCROLL
		mov eax, wParam
		.IF ax == TB_ENDTRACK
			push eax
			invoke SendMessage, Soundbar, TBM_GETPOS, 0, 0
			invoke SendMessage, hWnd, WM_COMMAND,IDM_VOLUME, eax 
			pop eax
		.ENDIF
	.ELSEIF uMsg == WM_COMMAND
		mov eax, wParam
		.IF ax == IDM_BROWSE
			invoke StopAudio
			invoke SelectFile
			.IF szFileNameOpen != NULL
				invoke PlayAnotherSong, PlayAnotherSong_and_AddToList, hWnd
			.ENDIF
		.ELSEIF ax == IDM_PLAY
			.IF AudioOn == 0 && AudioLoaded == 1
				.IF AudioLoaded == 0
					invoke PlayAudio
					invoke SetTimer, hWnd, PlayTimerID, ElapsedTime, NULL
				.ELSE
					invoke ResumeAudio
					invoke SetTimer, hWnd, PlayTimerID, ElapsedTime, NULL
				.ENDIF
				invoke SetWindowText, ButtonPlay, ADDR ButtonPauseText
				mov AudioOn, 1
			.ENDIF
		.ELSEIF ax == IDM_PAUSE
			.IF AudioLoaded == 1 && AudioOn == 1
				invoke PauseAudio
				invoke KillTimer, hWnd, PlayTimerID
				invoke SetWindowText, ButtonPlay, ADDR ButtonPlayText
				mov AudioOn, 0
			.ENDIF
		.ELSEIF ax == IDM_STOP
			.IF AudioLoaded == 1 && AudioOn == 1
				invoke KillTimer, hWnd, PlayTimerID
				invoke SendMessage, Trackbar, TBM_SETPOS, TRUE, 0
			.ENDIF
			invoke CloseAudio
			invoke SetWindowText, ButtonPlay, ADDR ButtonPlayText
			invoke SetWindowText, hwndEdit, NULL
			invoke SetWindowText, TotalTime, NULL
			invoke SetWindowText, CurrentTime, NULL
			mov	szFileNameOpen, NULL
			mov AudioOn, 0
			mov AudioLoaded, 0
		.ELSEIF ax == IDM_PROG
			.IF AudioLoaded == 1
				invoke GetPosFromPerc, lParam
				mov  ebx, eax
				invoke SetCurrentPosition, ebx 
				invoke GetCurrentPosition, ADDR position_s, LENGTH position_s
				invoke StringToInt, ADDR position_s
				.IF AudioOn == 0
					invoke PauseAudio
				.ENDIF
			.ENDIF
		.ELSEIF ax == IDM_VOLUME
			invoke 	GetVolumeFromPerc, lParam
			mov 	ebx, eax
			mov  	volume, ebx
			invoke 	SetVolume, ebx
		.ELSEIF ax == IDM_UPDATE
			.IF AudioLoaded == 1
				;获取进度
				invoke GetCurrentPosition, ADDR position_s, LENGTH position_s
				invoke StringToInt, ADDR position_s
				mov    position, eax
				;更新当前时间
				invoke convertTimeToString, position, ADDR CurrentTime_s
				invoke SetWindowText, CurrentTime, ADDR CurrentTime_s
				;更新歌词
				.IF total_lyric_num != 0
					invoke GetLyricFromPos, position, ADDR current_lyric
					invoke SetWindowText, LyricList, ADDR current_lyric
				.ENDIF
				;设置进度条
				mov edx, position
				invoke GetPercFromPos, edx
				invoke SendMessage, Trackbar, TBM_SETPOS, TRUE, eax
				;自动切歌
				mov ebx, position
				cmp ebx, totalLen
				jne quit_update
				invoke GotoNextSong, hWnd
				quit_update:
			.ENDIF
				
		.ELSEIF ax == IDM_SHOWVOL
			.IF CurrentVolShow == 0
				invoke ShowWindow, Soundbar, SW_SHOW
				invoke GetVolume, ADDR volume_s, LENGTH volume_s
				invoke StringToInt, ADDR volume_s
				mov	   volume, eax
				mov	   CurrentVolShow, 1
			.ELSE
				invoke ShowWindow, Soundbar, SW_HIDE
				mov	   CurrentVolShow, 0
			.ENDIF
		.ELSEIF ax == IDM_PREVSONG
			invoke GotoPrevSong, hWnd
		.ELSEIF ax == IDM_NEXTSONG
			invoke GotoNextSong, hWnd
		.ELSEIF ax == IDM_CHANGEMODE
			.IF mode == 0
				mov mode, 1
				invoke SetWindowText, ButtonMode, ADDR ButtonModeText1
			.ELSEIF mode == 1
				mov mode, 0
				invoke SetWindowText, ButtonMode, ADDR ButtonModeText0
			.ENDIF
		.ELSE
			;按钮函数和播放列表回调区域
			.IF ax == ButtonOpenID
				shr eax,16
				.IF ax==BN_CLICKED
					invoke SendMessage, hWnd, WM_COMMAND, IDM_BROWSE, 0
				.ENDIF
			.ELSEIF ax == ButtonPlayID
				shr eax,16
				.IF ax==BN_CLICKED
					.IF AudioOn == 0
						invoke SendMessage, hWnd, WM_COMMAND, IDM_PLAY, 0
					.ELSE
						invoke SendMessage, hWnd, WM_COMMAND, IDM_PAUSE, 0
					.ENDIF
				.ENDIF
			.ELSEIF ax == ButtonStopID
				shr eax,16
				.IF ax==BN_CLICKED
					invoke SendMessage, hWnd, WM_COMMAND, IDM_STOP, 0
				.ENDIF
			.ELSEIF ax == ButtonVolumeID
				shr eax,16
				.IF ax==BN_CLICKED
					invoke SendMessage, hWnd, WM_COMMAND, IDM_SHOWVOL, 0
				.ENDIF
			.ELSEIF ax == ButtonModeID
				shr eax, 16
				.IF ax==BN_CLICKED
					invoke SendMessage, hWnd, WM_COMMAND, IDM_CHANGEMODE, 0
				.ENDIF
			.ELSEIF ax == ButtonPrevsongID
				shr eax, 16
				.IF ax==BN_CLICKED
					invoke SendMessage, hWnd, WM_COMMAND, IDM_PREVSONG, 0
				.ENDIF
			.ELSEIF ax == ButtonNextsongID
				shr eax, 16
				.IF ax==BN_CLICKED
					invoke SendMessage, hWnd, WM_COMMAND, IDM_NEXTSONG, 0
				.ENDIF
			.ELSEIF ax == PlayListID
				shr eax, 16
				.IF DEBUG == 1
					push eax
					mov eax, LBN_DBLCLK
					pop eax
				.ENDIF
				.IF ax == LBN_DBLCLK
					invoke SendMessage, PlayList, LB_GETCURSEL, 0, 0
					inc eax
					mov szFilePos, eax
					invoke PlayAnotherSong, PlayAnotherSong_and_DoNothing, hWnd
				.ENDIF
			.ENDIF
		.ENDIF
	.ELSE
		invoke DefWindowProc,hWnd,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret
WndProc endp

SelectFile proc uses eax
	local 	@path:OPENFILENAME
	invoke	RtlZeroMemory, ADDR @path, SIZEOF @path
	mov		@path.lStructSize, SIZEOF @path
	invoke	GetModuleHandle, NULL
	mov		@path.hInstance, eax
	mov		@path.lpstrFilter, OFFSET szFilter
	mov		@path.lpstrFile, OFFSET szFileNameOpen
	mov     @path.nMaxFile, 128
	mov     @path.Flags, OFN_FILEMUSTEXIST or OFN_HIDEREADONLY
	invoke  BrowseFile, ADDR @path
	ret
SelectFile endp

GetPosFromPerc proc uses ebx edx perc:DWORD
	mov  eax, totalLen
	mul  perc
	mov  ebx, 100
	div  ebx
	ret
GetPosFromPerc endp

GetVolumeFromPerc proc uses ebx ecx edx perc:DWORD
	mov  eax, totalVolume
	mov  ecx, 100
	sub  ecx, perc
	mul  ecx
	mov  ebx, 100
	div  ebx
	ret
GetVolumeFromPerc endp

GetPercFromPos proc uses ebx edx pos:DWORD
	mov  eax, pos
	mov  ebx, 100
	mul  ebx
	div  totalLen
	ret
GetPercFromPos endp

GotoPrevSong proc uses ecx hWnd:DWORD
	.IF szFileNum !=0
		; 修改szFilePos
		.IF szFilePos == 1
			mov eax, szFileNum
			mov szFilePos, eax
		.ELSE
			mov ecx, szFilePos
			dec ecx
			mov szFilePos, ecx
		.ENDIF
		
		;播放上一首
		pushad
		invoke PlayAnotherSong, PlayAnotherSong_and_DoNothing, hWnd
		popad
	.ENDIF
	ret
GotoPrevSong endp

GotoNextSong proc uses ecx hWnd:DWORD
	.IF szFileNum != 0
		;修改szFilePos
		mov ecx, szFilePos
		cmp ecx, szFileNum
		jne L6
		mov szFilePos, 1
		jmp L7
		L6:
			mov ecx, szFilePos
			inc ecx
			mov szFilePos, ecx
		L7:
		;播放下一首
		pushad
		invoke PlayAnotherSong, PlayAnotherSong_and_DoNothing, hWnd
		popad
	.ENDIF
	ret
GotoNextSong endp

RepaintPlayList proc uses ecx edx edi
	;先清空播放列表
	mov eax, 1
	.WHILE eax != LB_ERR
		invoke SendMessage, PlayList, LB_DELETESTRING, 0, 0
	.ENDW
	;再重绘播放列表
	mov ecx, 0
	mov edx, OFFSET szFileNameList
	sub edx, maxFileNameLength
	L7:
		add edx, maxFileNameLength
		mov edi, OFFSET szFileNameToDisplay
		invoke copystring, edx, edi
		pushad
		invoke SendMessage, PlayList, LB_ADDSTRING, 0, OFFSET szFileNameToDisplay
		popad
		inc ecx
		cmp ecx, szFileNum
		jb L7
	ret
RepaintPlayList endp

PlayAnotherSong proc uses ecx edx ebx callback:DWORD, hWnd: DWORD
	; 若callback为PlayAnotherSong_and_DoNothing，表面调用该函数前szFileName尚未修改到正确的值，此时该函数需要根据szFilePos修改所有需要修改的东西
	; 若callback为PlayAnotherSong_and_AddToList，表面调用该函数前szFileName是正确的，但需要在加载音频成功后将其添加到播放列表的末尾（修改列表字符串和szFilePos、szFileNum）

	.IF callback == PlayAnotherSong_and_DoNothing
		;修改szFileNameOpen
		mov ecx, szFilePos
		mov edx, OFFSET szFileNameList
		sub edx, maxFileNameLength
		L4:
			add edx, maxFileNameLength
			loop L4
		invoke copystring, edx, ADDR szFileNameOpen
	.ENDIF
	;关闭之前的音频
	invoke KillTimer, hWnd, PlayTimerID
	invoke CloseAudio

	;设置文字与加载音频
	invoke SetWindowText, hwndEdit, ADDR szFileNameOpen
	invoke SetWindowText, ButtonPlay, ADDR ButtonPauseText
	invoke LoadAudio, ADDR szFileNameOpen
	.IF eax != 0 ; 处理音频加载失败的情况
		invoke MessageBox, hWnd, ADDR LoadFailureText, ADDR LoadFailureTitle, MB_OK
		jmp quit
	.ENDIF
	;构造lrc结尾的同名歌词文件名
	invoke copystring, ADDR szFileNameOpen, ADDR lyricName
	push eax
	push ebx
	push ecx
	push edx
	mov  ebx, OFFSET lyricName
	mov  ecx, [ebx]
	.WHILE ecx != 0
		inc ebx
		mov ecx, [ebx]
	.ENDW
	sub ebx, 3
	mov edx, 'l'
	mov [ebx], edx
	inc ebx
	mov edx, 'r'
	mov [ebx], edx
	inc ebx
	mov edx, 'c'
	mov [ebx], edx
	;获取歌词
	invoke SetWindowText, LyricList, OFFSET nullLyricText
	mov edx, OFFSET lyricName
	call WriteString
	invoke parseLRC, ADDR lyricName, ADDR lyric_time, ADDR lyric_content, maxLyricNum
	mov total_lyric_num, eax
	pop edx
	pop ecx
	pop ebx
	pop eax
	;获取总长度
	invoke GetTotalLength, ADDR totalLen_s, LENGTH totalLen_s
	invoke StringToInt, ADDR totalLen_s
	mov	   totalLen, eax
	invoke convertTimeToString, totalLen, ADDR totalLen_s
	invoke SetWindowText, TotalTime, ADDR totalLen_s
	invoke SetWindowText, CurrentTime, ADDR timezero_s
	;设置音量
	invoke SetVolume, volume
	;播放音频
	invoke PlayAudio
	mov	AudioOn, 1
	mov AudioLoaded, 1
	;开启计时器 
	invoke SetTimer, hWnd, PlayTimerID, ElapsedTime, NULL

	; 处理callback
	.IF callback == PlayAnotherSong_and_AddToList
		;修改播放列表信息
		.IF szFileNum == maxFileNum
			mov ecx, maxFileNum - 1
			mov ebx, OFFSET szFileNameList
			mov edx, ebx ; address of destination
			add ebx, maxFileNameLength ; address of source
			L1:
				invoke copystring, ebx, edx
				add ebx, maxFileNameLength
				add edx, maxFileNameLength
				loop L1
			invoke copystring, ADDR szFileNameOpen, edx
			mov szFilePos, maxFileNum
		.ELSE
			mov ecx, szFileNum
			mov ebx, OFFSET szFileNameList
			cmp ecx, 0
			je L3
			L2:
				add ebx, maxFileNameLength
				loop L2
			L3:
				invoke copystring, addr szFileNameOpen, ebx
				mov ecx, szFileNum
				inc ecx
				mov szFileNum, ecx
				mov szFilePos, ecx
		.ENDIF
	.ENDIF

	quit:
		invoke RepaintPlayList
		ret
PlayAnotherSong endp

copystring proc uses esi edi source:DWORD, dest:DWORD
	mov esi, source
	mov edi, dest
	Lx:
		mov al, [esi]
		mov [edi], al
		inc esi
		inc edi
		cmp byte ptr [esi], 0
		jne Lx
	mov byte ptr [edi], 0
	ret
copystring endp

GetLyricFromPos proc uses eax ebx ecx esi pos:DWORD, res:DWORD
	mov ebx, OFFSET lyric_content
	mov esi, OFFSET lyric_time
	mov ecx, 0
	mov eax, 0
	mov edx, total_lyric_num
	shl edx, 2
	invoke copystring, res, ebx
	.WHILE ecx <= edx && eax < pos
		mov eax, [esi]
		add esi, 4
		add ecx, 4
	.ENDW
	sub ecx, 8
	shr ecx, 2
	mov eax, ecx
	mov esi, maxLyricLength
	mul esi
	add ebx, eax
	invoke copystring, ebx, res
	mov edx, res
	ret
GetLyricFromPos endp

convertTimeToString proc uses edx ecx ebx time:DWORD, time_s:DWORD 
	mov edx, 0FFFF0000h
	and edx, time
	ror edx, 16
	mov eax, 0FFFFh
	and eax, time
	mov ebx, 1000
	div bx ; 此时ax内存储了时长（单位为秒）
	mov ebx, 60
	div bl   ;此时AL内存储了时长的分钟数，ah内存储了时长的秒数，时长的格式为m:s
	mov edx, 0FFh
	and edx, eax
	pushad
	invoke IntToString, edx, time_s
	popad
	mov edx, 0FFh
	ror eax, 8
	and edx, eax
	mov ecx, time_s
	dec ecx
	FindNull:
		inc ecx
		cmp byte ptr [ecx], 0
		jne FindNull
	mov byte ptr [ecx], ':'
	inc ecx
	pushad
	invoke IntToString, edx, ecx
	popad
	mov ecx, time_s
	dec ecx
	FindNull2:
		inc ecx
		cmp byte ptr [ecx], 0
		jne FindNull2
	mov byte ptr [ecx], 0
	ret
convertTimeToString endp


end start