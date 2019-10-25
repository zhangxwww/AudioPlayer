.386
.model flat,stdcall
option casemap:none

WinMain 			proto :DWORD,:DWORD,:DWORD,:DWORD			;主窗口过程
MessageBoxA			proto :DWORD,:DWORD,:DWORD,:DWORD			;用于构建MessageBox
MessageBox 			equ <MessageBoxA> 							;用于显示错误消息								
BrowseFolder		equ <SHBrowseForFolder>						;用于打开文件夹对话框
BrowseFile			equ <GetOpenFileNameA>						;用于打开文件对话框
promptError			proto 										;错误提示
SelectFile			proto										;用于打开文件对话框并存储文件名字符串

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
ClassName 		BYTE "SimpleWinClass",0
AppName  		BYTE "Audio Player",0
ButtonClassName BYTE "button",0
errorwinTittle 	BYTE "Error",0
errorMsg 		BYTE "Error emerges",0

ButtonOpenText 	BYTE "Open",0
ButtonPlayText 	BYTE "Play",0
ButtonPauseText BYTE "Pause", 0
ButtonStopText  BYTE "Stop", 0
EditClassName 	BYTE "edit",0

szFilter		BYTE "Media Files", 0, "*.mp4;*.mp3;*.wav;*.m4a", 0
szFileNameOpen	BYTE 512 DUP(0)
AudioOn			BYTE 0
AudioLoaded		BYTE 0

.data?
hInstance 		HINSTANCE ?

ButtonOpen 	HWND ?
ButtonPlay 	HWND ?
ButtonStop  HWND ?
hwndEdit 	HWND ?
buffer 		BYTE  512 dup(?)	;输入表达式缓冲区
result 		BYTE  512 dup(?)	;结果存储区域

.const

EditID equ 10

ButtonOpenID 	equ 11
ButtonPlayID	equ 12
ButtonStopID	equ 13

IDM_CLEAR 		equ 1
IDM_EXIT 		equ 2
IDM_APPEND 		equ 3
IDM_BROWSE		equ 4
IDM_PLAY		equ 5
IDM_PAUSE		equ 6
IDM_STOP		equ 7

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

	.ELSEIF uMsg == WM_COMMAND
		mov eax, wParam
		.IF lParam == 0
			;指令处理区域
			.IF ax == IDM_BROWSE
				invoke StopAudio
				invoke SelectFile
				invoke SetWindowText, hwndEdit, ADDR szFileNameOpen
				invoke SetWindowText, ButtonPlay, ADDR ButtonPauseText
				invoke LoadAudio, ADDR szFileNameOpen
				invoke PlayAudio
				mov	AudioOn, 1
				mov AudioLoaded, 1

				;invoke BrowseFolder, ADDR folderpath
			.ELSEIF ax == IDM_PLAY
				.IF AudioOn == 0
					.IF AudioLoaded == 0
						invoke PlayAudio
					.ELSE
						invoke ResumeAudio
					.ENDIF
					invoke SetWindowText, ButtonPlay, ADDR ButtonPauseText
					mov AudioOn, 1
				.ENDIF
			.ELSEIF ax == IDM_PAUSE
				invoke PauseAudio
				invoke SetWindowText, ButtonPlay, ADDR ButtonPlayText
				mov AudioOn, 0
			.ELSEIF ax == IDM_STOP
				invoke StopAudio
				invoke SetWindowText, ButtonPlay, ADDR ButtonPlayText
				mov AudioOn, 0
				mov AudioLoaded, 0
			.ELSE
				invoke DestroyWindow,hWnd
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

end start