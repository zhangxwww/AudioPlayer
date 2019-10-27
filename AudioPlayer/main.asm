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
atodw				PROTO :DWORD								
StringToInt			equ <atodw>

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

.data
ClassName 			BYTE "SimpleWinClass", 0
AppName  			BYTE "Audio Player", 0
ButtonClassName 	BYTE "button", 0
EditClassName 		BYTE "edit", 0
TrackbarClassName 	BYTE "msctls_trackbar32", 0


errorwinTittle 		BYTE "Error", 0
errorMsg 			BYTE "Error emerges", 0

ButtonOpenText 		BYTE "Open", 0
ButtonPlayText 		BYTE "Play", 0
ButtonPauseText		BYTE "Pause", 0
ButtonStopText		BYTE "Stop", 0
ButtonVolumeText	BYTE "Vol", 0

szFilter			BYTE "Media Files", 0, "*.mp3;*.wav", 0
;szFileNameOpen		BYTE 25600 DUP(0) ; 存储列表中的歌曲对应的FileName的数组，最多存50个FileName512，每个的长度最大为512
szFileNameOpen		BYTE 512 DUP(0)
;historyFileCount	BYTE 0 ; 列表中的歌曲数
AudioOn				DWORD 0
AudioLoaded			DWORD 0
position_s     		BYTE 64 DUP(0)
volume_s			BYTE 64 DUP(0)
totalLen_s     		BYTE 64 DUP(0)
totalLen			DWORD 0
position			DWORD 0
volume				DWORD 0
CurrentVolShow  	DWORD 0

.data?
hInstance 		HINSTANCE ?

ButtonOpen 		HWND ?
ButtonPlay 		HWND ?
ButtonStop		HWND ?
ButtonVolume	HWND ?
hwndEdit 		HWND ?
Trackbar		HWND ?
Soundbar		HWND ?

buffer 		BYTE  512 dup(?)	;缓冲区

.const

EditID 			equ 1
ButtonOpenID 	equ 2
ButtonPlayID	equ 3
ButtonStopID	equ 4
TrackbarID		equ 6
SoundbarID      equ 5
ButtonVolumeID  equ 6
totalVolume		equ 1000

IDM_CLEAR 		equ 11
IDM_EXIT 		equ 12
IDM_APPEND 		equ 13
IDM_BROWSE		equ 14
IDM_PLAY		equ 15
IDM_PAUSE		equ 16
IDM_STOP		equ 17
IDM_PROG		equ 18
IDM_UPDATE		equ 19
IDM_VOLUME      equ 20
IDM_SHOWVOL 	equ 21

PlayTimerID		equ 51
ElapsedTime		equ 1000

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
           CW_USEDEFAULT,400,400,NULL,NULL,\
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
	push eax
	push ebx
	push ecx
	push edx
	invoke MessageBox,NULL,ADDR errorMsg,ADDR errorwinTittle,MB_OK
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
promptError	endp

WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
	.IF uMsg==WM_DESTROY
		invoke PostQuitMessage,NULL
	;创建窗口时的初始化动作
	.ELSEIF uMsg==WM_CREATE
		;添加文本框
		invoke Init
		invoke CreateWindowEx,WS_EX_CLIENTEDGE, ADDR EditClassName,NULL,\
                        WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT or\
                        ES_AUTOHSCROLL,\
                        30,30,300,30,hWnd,EditID,hInstance,NULL
		mov  hwndEdit, eax
		invoke SetFocus, hwndEdit
		;添加按钮
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonOpenText,\
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        30,75,80,30,hWnd,ButtonOpenID,hInstance,NULL
		mov  ButtonOpen, eax
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonPlayText,\
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        120,75,80,30,hWnd,ButtonPlayID,hInstance,NULL
		mov  ButtonPlay, eax
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonStopText,\
                        WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON,\
                        210,75,80,30,hWnd,ButtonStopID,hInstance,NULL
		mov  ButtonStop, eax
		invoke CreateWindowEx,NULL, ADDR ButtonClassName,ADDR ButtonVolumeText,\
                        WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON,\
                        325,115,50,30,hWnd,ButtonVolumeID,hInstance,NULL
		mov  ButtonVolume, eax
		;添加进度条
		invoke CreateWindowEx,NULL, ADDR TrackbarClassName,NULL,\
                        WS_CHILD or WS_VISIBLE or TBS_NOTICKS or TBS_TRANSPARENTBKGND,\
                        20,120,300,30,hWnd,TrackbarID,hInstance,NULL
		mov  Trackbar, eax
		;添加音量控制条
		invoke CreateWindowEx, NULL, ADDR TrackbarClassName, NULL, \
						WS_CHILD or WS_VISIBLE or TBS_NOTICKS or TBS_VERT or TBS_TRANSPARENTBKGND,\
                        345,30,30,80,hWnd,SoundbarID,hInstance,NULL
		mov  Soundbar, eax
		;初始化音量控制条位置、是否可见
		invoke SendMessage, Soundbar, TBM_SETPOS, TRUE, 0
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
			push eax
			mov eax, OFFSET volume
			pop eax
			invoke SelectFile
			.IF szFileNameOpen != NULL
				;设置文字
				invoke SetWindowText, hwndEdit, ADDR szFileNameOpen
				invoke SetWindowText, ButtonPlay, ADDR ButtonPauseText
				invoke LoadAudio, ADDR szFileNameOpen
				;获取总长度
				push   eax
				invoke GetTotalLength, ADDR totalLen_s, LENGTH totalLen_s
				invoke StringToInt, ADDR totalLen_s
				mov	   totalLen, eax
				pop    eax
				;设置音量
				invoke SetVolume, volume
				;播放音频
				invoke PlayAudio
				mov	AudioOn, 1
				mov AudioLoaded, 1
				;开启计时器
				invoke SetTimer, hWnd, PlayTimerID, ElapsedTime, NULL
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
			mov	szFileNameOpen, NULL
			mov AudioOn, 0
			mov AudioLoaded, 0
		.ELSEIF ax == IDM_PROG
			.IF AudioLoaded == 1
				push eax
				push ebx
				invoke GetPosFromPerc, lParam
				mov  ebx, eax
				invoke SetCurrentPosition, ebx 
				invoke GetCurrentPosition, ADDR position_s, LENGTH position_s
				invoke StringToInt, ADDR position_s
				.IF AudioOn == 0
					invoke PauseAudio
				.ENDIF
				pop  ebx
				pop  eax
			.ENDIF
		.ELSEIF ax == IDM_VOLUME
			push 	eax
			push 	ebx
			invoke 	GetVolumeFromPerc, lParam
			mov 	ebx, eax
			mov  	volume, ebx
			invoke 	SetVolume, ebx
			pop 	ebx
			pop 	eax
		.ELSEIF ax == IDM_UPDATE
			.IF AudioLoaded == 1
				push eax
				push edx
				invoke GetCurrentPosition, ADDR position_s, LENGTH position_s
				push   eax
				invoke StringToInt, ADDR position_s
				mov    position, eax
				pop    eax
				mov edx, position
				invoke GetPercFromPos, edx
				invoke SendMessage, Trackbar, TBM_SETPOS, TRUE, eax
				pop edx
				pop eax
			.ENDIF
		.ELSEIF ax == IDM_SHOWVOL
			.IF CurrentVolShow == 0
				invoke ShowWindow, Soundbar, SW_SHOW
				push   eax
				invoke GetVolume, ADDR volume_s, LENGTH volume_s
				invoke StringToInt, ADDR volume_s
				mov	   volume, eax
				pop    eax
				mov	   CurrentVolShow, 1
			.ELSE
				invoke ShowWindow, Soundbar, SW_HIDE
				mov	   CurrentVolShow, 0
			.ENDIF
		.ELSE
			;按钮函数回调区域
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
			.ENDIF
		.ENDIF
	.ELSE
		invoke DefWindowProc,hWnd,uMsg,wParam,lParam
		ret
	.ENDIF
	xor    eax,eax
	ret
WndProc endp

SelectFile proc
	local 	@path:OPENFILENAME
	push 	eax
	invoke	RtlZeroMemory, ADDR @path, SIZEOF @path
	mov		@path.lStructSize, SIZEOF @path
	invoke	GetModuleHandle, NULL
	mov		@path.hInstance, eax
	mov		@path.lpstrFilter, OFFSET szFilter
	mov		@path.lpstrFile, OFFSET szFileNameOpen
	mov     @path.nMaxFile, 128
	mov     @path.Flags, OFN_FILEMUSTEXIST or OFN_HIDEREADONLY
	invoke  BrowseFile, ADDR @path
	pop		eax
	ret
SelectFile endp

GetPosFromPerc proc perc:DWORD
	push ebx
	push edx
	mov  eax, totalLen
	mul  perc
	mov  ebx, 100
	div  ebx
	pop  edx
	pop  ebx
	ret
GetPosFromPerc endp

GetVolumeFromPerc proc perc:DWORD
	push ebx
	push ecx
	push edx
	mov  eax, totalVolume
	mov  ecx, 100
	sub  ecx, perc
	mul  ecx
	mov  ebx, 100
	div  ebx
	pop  edx
	pop  edx
	pop  ebx
	ret
GetVolumeFromPerc endp

GetPercFromPos proc pos:DWORD
	push ebx
	push edx
	mov  eax, pos
	mov  ebx, 100
	mul  ebx
	div  totalLen
	pop  edx
	pop  ebx
	ret
GetPercFromPos endp

end start