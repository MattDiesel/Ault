

#include <Array.au3>
#include "ault\Parser.au3"
#include "ault\AST.au3"
#include "ault\ASTUtils.au3"
#include "ault\Deparser.au3"
#include "ault\ErrorHandler.au3"



; Local $l = _Ault_CreateLexer("ExampleScript.au3", $AL_FLAG_AUTOLINECONT + $AL_FLAG_AUTOINCLUDE)
; Local $sData, $iType
; Do
;     $aTok = _Ault_LexerStep($l)
;     If @error Then
;         ConsoleWrite("Error: " & @error & @LF)
;         ExitLoop
;     EndIf
;     ConsoleWrite(StringFormat("%s: %s\n", __AuTok_TypeToStr($aTok[$AL_TOKI_TYPE]), $aTok[$AL_TOKI_DATA]))
; Until $aTok[$AL_TOKI_TYPE] = $AL_TOK_EOF


; Local $a = _Ault_ParseFile("C:\Program Files (x86)\AutoIt3\Beta\Include\WinAPI.au3")
Local $a = _Ault_ParseFile("ExampleScript.au3", $AL_FLAG_AUTOINCLUDE + $AL_FLAG_AUTOLINECONT)
; Local $a = _Ault_ParseFile("ault\Parser.au3", $AL_FLAG_AUTOINCLUDE + $AL_FLAG_AUTOLINECONT)

If @error Then
    _ArrayDisplay($a)
    _Ault_ErrorBox($a)
Else
    _Ault_ViewAST($a)
    MsgBox(0, "Test", _Ault_Deparse($a))
EndIf

