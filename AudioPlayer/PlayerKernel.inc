Init PROTO
LoadAudio PROTO audioNameAddr:DWORD
PlayAudio PROTO
PauseAudio PROTO
ResumeAudio PROTO
StopAudio PROTO
GetCurrentPosition PROTO returnAddr:DWORD, bufsize:DWORD
SetCurrentPosition PROTO pos:DWORD
GetTotalLength PROTO returnAddr:DWORD, bufsize:DWORD
GetVolume PROTO returnAddr:DWORD, bufsize:DWORD
SetVolume PROTO vol:DWORD
CloseAudio PROTO
