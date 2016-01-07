
#include-once

; Token types
Global Enum $AL_TOK_EOF = 0, _ ; End of File
        $AL_TOK_EOL, _ ; End of Line
        $AL_TOK_OP, _ ; Operator.
        $AL_TOK_ASSIGN, _ ; Operator.
        $AL_TOK_KEYWORD, _ ; Keyword. E.g. 'Func', 'Local' etc. (not used if $AL_FLAG_NORESOLVEKEYWORD is set)
        $AL_TOK_FUNC, _ ; Standard function (not used if $AL_FLAG_NORESOLVEKEYWORD is set)
        $AL_TOK_WORD, _ ; Word (but not keyword or standard function)
        $AL_TOK_OPAR, _ ; (
        $AL_TOK_EPAR, _ ; )
        $AL_TOK_OBRACK, _ ; [
        $AL_TOK_EBRACK, _ ; ]
        $AL_TOK_COMMA, _ ; ,
        $AL_TOK_STR, _ ; " ... "
        $AL_TOK_NUMBER, _ ; Integer, float, hex etc.
        $AL_TOK_MACRO, _ ; @...
        $AL_TOK_VARIABLE, _ ; $...
        $AL_TOK_PREPROC, _; Preprocessor statement. NB returns whole line and does no processing apart from #cs and #ce
        $AL_TOK_COMMENT, _ ; Comment. Includes multiline.
        $AL_TOK_LINECONT, _ ; Line continuation _ (only used if $AL_FLAG_AUTOLINECONT not set)
        $AL_TOK_INCLUDE, _ ; Include statement
        $_AL_TOK_COUNT

; For conversion from token type number to name
Global Const $_AL_TOK_NAMES[$_AL_TOK_COUNT] = [ _
        "EOF", _
        "EOL", _
        "Operator", _
        "Assignment", _
        "Keyword", _
        "Function", _
        "Word", _
        "(", _
        ")", _
        "[", _
        "]", _
        ",", _
        "String", _
        "Number", _
        "Macro", _
        "Variable", _
        "Pre-processor Statement", _
        "Comment", _
        "Line Continuation", _
        "Include"]

; Constants for accessing a Token array
Global Enum _
        $AL_TOKI_TYPE = 0, _
        $AL_TOKI_DATA, _
        $AL_TOKI_ABS, _
        $AL_TOKI_LINE, _
        $AL_TOKI_COL, _
        $_AL_TOKI_COUNT

Func __AuTok_TypeToStr($iTok)
    If $iTok >= $_AL_TOK_COUNT Or $iTok < 0 Then Return "Token???"
    Return $_AL_TOK_NAMES[$iTok]
EndFunc


Func __AuTok_Make($iType = 0, $sData = "", $iAbs = -1, $iLine = -1, $iCol = -1)
    Local $tokRet[$_AL_TOKI_COUNT] = [$iType, $sData, $iAbs, $iLine, $iCol]
    Return $tokRet
EndFunc
