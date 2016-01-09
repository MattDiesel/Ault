
#include-once
#include "Lexer.au3"
#include "Token.au3"


Global Enum $AULT_ERRI_MSG = 0, _
        $AULT_ERRI_AST, _
        $AULT_ERRI_BRANCH, _
        $AULT_ERRI_LEXER, _
        $AULT_ERRI_TOKEN, _
        $AULT_ERRI_SOURCE, _
        $AULT_ERRI_CODELINE, _
        $AULT_ERRI_CODELINE_COL, _
        $AULT_ERRI_FILE, _
        $AULT_ERRI_LINE, _
        $AULT_ERRI_COL, _
        $_AULT_ERRI_COUNT


Func _Error_Create($sMessage, $aSt, $iBranch, $lexer, $tk, $iLineNumber = @ScriptLineNumber)
    Local $errRet[$_AULT_ERRI_COUNT]

    $errRet[$AULT_ERRI_MSG] = $sMessage
    $errRet[$AULT_ERRI_AST] = $aSt
    $errRet[$AULT_ERRI_BRANCH] = $iBranch
    $errRet[$AULT_ERRI_LEXER] = $lexer
    $errRet[$AULT_ERRI_TOKEN] = $tk
    $errRet[$AULT_ERRI_CODELINE] = __Error_GetLine($lexer, $tk[$AL_TOKI_ABS], $tk[$AL_TOKI_LINE], $tk[$AL_TOKI_COL])
    $errRet[$AULT_ERRI_CODELINE_COL] = @extended
    $errRet[$AULT_ERRI_SOURCE] = $iLineNumber
    $errRet[$AULT_ERRI_FILE] = $lexer[$AL_LEXI_FILENAME]
    $errRet[$AULT_ERRI_LINE] = $tk[$AL_TOKI_LINE]
    $errRet[$AULT_ERRI_COL] = $tk[$AL_TOKI_COL]

    Return $errRet
EndFunc   ;==>_Error_Create

Func _Error_CreateLex($sMessage, $lex, $iLineNumber = @ScriptLineNumber)
    Local $errRet[$_AULT_ERRI_COUNT]

    $errRet[$AULT_ERRI_MSG] = $sMessage
    $errRet[$AULT_ERRI_AST] = 0
    $errRet[$AULT_ERRI_BRANCH] = 0
    $errRet[$AULT_ERRI_LEXER] = $lex
    $errRet[$AULT_ERRI_TOKEN] = 0
    $errRet[$AULT_ERRI_CODELINE] = __Error_GetLine($lex, $lex[$AL_LEXI_ABS]-1, $lex[$AL_LEXI_LINE], $lex[$AL_LEXI_COL]-1)
    $errRet[$AULT_ERRI_CODELINE_COL] = @extended
    $errRet[$AULT_ERRI_SOURCE] = $iLineNumber
    $errRet[$AULT_ERRI_FILE] = $lex[$AL_LEXI_FILENAME]
    $errRet[$AULT_ERRI_LINE] = $lex[$AL_LEXI_LINE]
    $errRet[$AULT_ERRI_COL] = $lex[$AL_LEXI_COL]

    Return $errRet
EndFunc

Func __Error_GetLine(ByRef Const $lexer, $abs, $line, $col)

    Local $iStart = $abs - $col
    Local $iEnd = StringInStr($lexer[$AL_LEXI_DATA], @CR, 2, 1, $abs, 4096)

    If $iEnd = 0 Then ; Test for LF as well
        $iEnd = StringInStr($lexer[$AL_LEXI_DATA], @LF, 2, 1, $abs, 4096)

        If $iEnd = 0 Then
            ; Use EOF instead
            $iEnd = StringLen($lexer[$AL_LEXI_DATA])
        EndIf
    EndIf

    Local $iMaxLine = 256

    ; Remove whitespace from the start of the line.
    Local $sLine = StringMid($lexer[$AL_LEXI_DATA], $iStart, $iEnd - $iStart)
    $sLine = StringStripWS($sLine, 1)
    $iStart = $iEnd - StringLen($sLine)


    If $iEnd - $iStart > $iMaxLine Then ; Limit line length to keep it readable

        If $abs - $iStart < $iMaxLine Then
            $iEnd = $iStart + $iMaxLine

            If $iEnd > StringLen($lexer[$AL_LEXI_DATA]) Then
                $iEnd = StringLen($lexer[$AL_LEXI_DATA])
            EndIf
        ElseIf $iEnd - $abs < $iMaxLine Then
            $iStart = $iEnd - $iMaxLine

            If $iStart < 0 Then $iStart = 0
        Else
            $iStart = $abs - Int($iMaxLine / 2)
            $iEnd = $abs + Int($iMaxLine / 2)
        EndIf
    EndIf

    Return SetExtended($abs - $iStart, StringMid($lexer[$AL_LEXI_DATA], $iStart, $iEnd - $iStart))
EndFunc   ;==>__Error_GetLine

Func _Ault_ErrorMsg($err)

    If Not IsArray($err) Then Return "Unknown Error."

    Return StringFormat("""%s"" (%d:%d) : ==> %s:" & @LF & "%s" & @LF & "%s^ ERROR", _
            $err[$AULT_ERRI_FILE], $err[$AULT_ERRI_LINE], $err[$AULT_ERRI_COL], _
            $err[$AULT_ERRI_MSG], _
            $err[$AULT_ERRI_CODELINE], _
            StringLeft($err[$AULT_ERRI_CODELINE], $err[$AULT_ERRI_CODELINE_COL]))

EndFunc   ;==>_Ault_ErrorMsg

Func _Ault_ErrorBox($err)
    MsgBox(16, "Error", _Ault_ErrorMsg($err))
EndFunc
