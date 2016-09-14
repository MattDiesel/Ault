
#include-once
#include <Math.au3>
#include <Array.au3>

#include "Defs.au3"
#include "Token.au3"
#include "Installation.au3"


Global Enum Step *2 _
        $AL_FLAG_AUTOLINECONT = 1, _
        $AL_FLAG_NORESOLVEKEYWORD, _
        $AL_FLAG_AUTOINCLUDE, _
        $__AL_FLAG_LINECONT

Global Enum $AL_LEXI_FILENAME = 0, _
        $AL_LEXI_DATA, _
        $AL_LEXI_FLAGS, _
        $AL_LEXI_ABS, _
        $AL_LEXI_LINE, _
        $AL_LEXI_COL, _
        $AL_LEXI_PARENT, _
        $AL_LEXI_INCLONCE, _
        $__AL_LEXI_COUNT

Global Enum $AL_ST_START = -1, _
        $AL_ST_NONE, _
        $AL_ST_INT, _
        $AL_ST_FLOAT, _
        $AL_ST_FLOATE, _
        $AL_ST_FLOATES, _
        $AL_ST_ZERO, _
        $AL_ST_HEX, _
        $AL_ST_STRINGS, _
        $AL_ST_STRINGD, _
        $AL_ST_MACRO, _
        $AL_ST_VARIABLE, _
        $AL_ST_COMMENT, _
        $AL_ST_COMMENTMULTI, _
        $AL_ST_COMMENTMULTINL, _
        $AL_ST_COMMENTMULTIEND, _
        $AL_ST_PREPROC, _
        $AL_ST_PREPROCLINE, _
        $AL_ST_INCLUDELINE, _
        $AL_ST_LINECONT, _
        $AL_ST_PREPROCLINE_IGNORE, _
        $AL_ST_KEYWORD



; Test assertions:
; _AuLex_LexTestAssert("", $AL_TOK_EOF, "")
; _AuLex_LexTestAssert(@CRLF, $AL_TOK_EOL, @CRLF)
; _AuLex_LexTestAssert(@LF, $AL_TOK_EOL, @LF)
; _AuLex_LexTestAssert(@CR, $AL_TOK_EOL, @CR)
; _AuLex_LexTestAssert("123", $AL_TOK_NUMBER, "123")
; _AuLex_LexTestAssert("123.456", $AL_TOK_NUMBER, "123.456")
; _AuLex_LexTestAssert("123e4", $AL_TOK_NUMBER, "123e4")
; _AuLex_LexTestAssert("123e-4", $AL_TOK_NUMBER, "123e-4")
; _AuLex_LexTestAssert("123.456e4", $AL_TOK_NUMBER, "123.456e4")
; _AuLex_LexTestAssert("123.456e-4", $AL_TOK_NUMBER, "123.456e-4")
; _AuLex_LexTestAssert("0111", $AL_TOK_NUMBER, "0111")
; _AuLex_LexTestAssert("0xABCDEF", $AL_TOK_NUMBER, "0xABCDEF")
; _AuLex_LexTestAssert("'This is a test'", $AL_TOK_STR, "'This is a test'")
; _AuLex_LexTestAssert("'This is '' a test'", $AL_TOK_STR, "'This is '' a test'")
; _AuLex_LexTestAssert("""This is a test""", $AL_TOK_STR, """This is a test""")
; _AuLex_LexTestAssert("""This is """" a test""", $AL_TOK_STR, """This is """" a test""")
; _AuLex_LexTestAssert("@Testing", $AL_TOK_MACRO, "@Testing")
; _AuLex_LexTestAssert("$Testing", $AL_TOK_VARIABLE, "$Testing")
; _AuLex_LexTestAssert("; This is a comment", $AL_TOK_COMMENT, "; This is a comment")
; _AuLex_LexTestAssert("#include <Test>", $AL_TOK_PREPROC, "#include <Test>")
; _AuLex_LexTestAssert("#cs" & @CRLF & "Testing comment" & @CRLF & "#This won't match" & @CRLF & "#ce", $AL_TOK_COMMENT)
; _AuLex_LexTestAssert("(", $AL_TOK_OPAR)
; _AuLex_LexTestAssert(")", $AL_TOK_EPAR)
; _AuLex_LexTestAssert("[", $AL_TOK_OBRACK)
; _AuLex_LexTestAssert("]", $AL_TOK_EBRACK)
; _AuLex_LexTestAssert("*", $AL_TOK_OP)
; _AuLex_LexTestAssert("*=", $AL_TOK_ASSIGN)
; _AuLex_LexTestAssert("<=", $AL_TOK_OP)
; _AuLex_LexTestAssert("<>", $AL_TOK_OP)
; _AuLex_LexTestAssert("^", $AL_TOK_OP)
; _AuLex_LexTestAssert(".", $AL_TOK_OP)
; _AuLex_LexTestAssert("?", $AL_TOK_OP)
; _AuLex_LexTestAssert(":, $AL_TOK_OP)
; _AuLex_LexTestAssert("_Test", $AL_TOK_WORD)
; _AuLex_LexTestAssert("Test", $AL_TOK_WORD)
; _AuLex_LexTestAssert("Local", $AL_TOK_KEYWORD)
; _AuLex_LexTestAssert("StringInStr", $AL_TOK_FUNC)
; _AuLex_LexTestAssert("_" & @CRLF & " _Test", $AL_TOK_LINECONT, "_", 0)
; _AuLex_LexTestAssert("_" & @CRLF & " _Test", $AL_TOK_WORD, "_Test", $AL_FLAG_AUTOLINECONT)
; _AuLex_LexTestAssert("_ ; Testing Comment" & @CRLF & " _Test", $AL_TOK_COMMENT, "; Testing Comment", $AL_FLAG_AUTOLINECONT)

; Func _AuLex_LexTestAssert($sString, $iExpType, $sExpectData = Default, $iFlags = 0)
;     Local Static $iIndex = 0
;     $iIndex += 1

;     If $sExpectData = Default Then $sExpectData = $sString
;     Local $l = _Ault_CreateLexerFromString("Test", $sString, $iFlags)
;     Local $aTok = _Ault_LexerStep($l)
;     If @error Then
;         Local $t[$_AL_TOKI_COUNT] = ["ERROR", @error]
;         $aTok = $t
;     EndIf

;     If $iExpType <> $aTok[$AL_TOKI_TYPE] Or $aTok[$AL_TOKI_DATA] <> $sExpectData Then
;         ConsoleWrite("Assertion " & $iIndex & " Failed! " & @error & @LF & @TAB & _
;                 "Input: {" & $sString & "} (" & StringToBinary($sString) & ")" & @LF & @TAB & _
;                 "Token Type: " & $aTok[$AL_TOKI_TYPE] & "  (" & $iExpType & ")" & @LF & @TAB & _
;                 "Token Data: {" & $aTok[$AL_TOKI_DATA] & "} (" & StringToBinary($aTok[$AL_TOKI_DATA]) & ")" & @LF)
;     EndIf
; EndFunc   ;==>_AuLex_LexTestAssert



; Example: Process this file:

; Local $l = _Ault_CreateLexer("Test.au3", $AL_FLAG_AUTOLINECONT)
; Local $sData, $iType
; Do
;     $aTok = _Ault_LexerStep($l)
;     If @error Then
;         ConsoleWrite("Error: " & @error & @LF)
;         ExitLoop
;     EndIf
;     ConsoleWrite(StringFormat("%-4.4i: %s\n", $aTok[$AL_TOKI_TYPE], $aTok[$AL_TOKI_DATA]))
; Until $aTok[$AL_TOKI_TYPE] = $AL_TOK_EOF



Func _Ault_CreateLexer($sFile, $iFlags)
    Local $sData = FileRead($sFile)
    If @error Then Return SetError(1, 0, 0) ; File couldn't be read.

    Return _Ault_CreateLexerFromString($sFile, $sData, $iFlags)
EndFunc   ;==>_Ault_CreateLexer

; Starts a lexer for a data string.
Func _Ault_CreateLexerFromString($sName, $sData, $iFlags)
    Local $lexRet[$__AL_LEXI_COUNT]

    $lexRet[$AL_LEXI_FILENAME] = $sName
    $lexRet[$AL_LEXI_DATA] = $sData & @CRLF
    $lexRet[$AL_LEXI_FLAGS] = $iFlags

    $lexRet[$AL_LEXI_ABS] = 1
    $lexRet[$AL_LEXI_LINE] = 1
    $lexRet[$AL_LEXI_COL] = 1

    $lexRet[$AL_LEXI_PARENT] = 0
    $lexRet[$AL_LEXI_INCLONCE] = ";"

    Return $lexRet
EndFunc   ;==>_Ault_CreateLexerFromString

; Returns the next token (as a string)
; The token type (an $AL_TOK_ constant) is returned in @extended
Func _Ault_LexerStep(ByRef $lex)
    Local $iState = $AL_ST_START
    Local $c, $c2, $anchor

    Local $tokRet[$_AL_TOKI_COUNT] = [0, "", -1, -1, -1]

    If Not IsArray($lex) Then
        ConsoleWrite("What you giving me here?" & @LF)
        Return SetError(@ScriptLineNumber, 0, $tokRet)
    EndIf

    While 1
        $c = __AuLex_NextChar($lex)

        Switch $iState
            Case $AL_ST_START
                Select
                    Case $c = ""
                        If IsArray($lex[$AL_LEXI_PARENT]) Then
                            Local $sFileEnding = $lex[$AL_LEXI_FILENAME]
                            Local $sInclOnce = $lex[$AL_LEXI_INCLONCE]
                            $lex = $lex[$AL_LEXI_PARENT]
                            $lex[$AL_LEXI_INCLONCE] &= StringTrimLeft($sInclOnce, 1)

                            Return __AuTok_Make($AL_TOK_EOF, $sFileEnding, $lex[$AL_LEXI_ABS], $lex[$AL_LEXI_LINE], $lex[$AL_LEXI_COL])
                        EndIf

                        Return __AuTok_Make($AL_TOK_EOF, "", $lex[$AL_LEXI_ABS], $lex[$AL_LEXI_LINE], $lex[$AL_LEXI_COL])
                    Case __AuLex_StrIsNewLine($c)
                        If BitAND($lex[$AL_LEXI_FLAGS], $__AL_FLAG_LINECONT) Then
                            $lex[$AL_LEXI_FLAGS] = BitXOR($lex[$AL_LEXI_FLAGS], $__AL_FLAG_LINECONT)
                        Else
                            Return __AuTok_Make($AL_TOK_EOL, $c, $lex[$AL_LEXI_ABS] - StringLen($c), $lex[$AL_LEXI_LINE] - 1, -1)
                        EndIf
                    Case Not StringIsSpace($c)
                        ; Save token position
                        $tokRet[$AL_TOKI_ABS] = $lex[$AL_LEXI_ABS] - 1
                        $tokRet[$AL_TOKI_LINE] = $lex[$AL_LEXI_LINE]
                        $tokRet[$AL_TOKI_COL] = $lex[$AL_LEXI_COL] - 1

                        $iState = $AL_ST_NONE
                        __AuLex_PrevChar($lex)
                EndSelect
            Case $AL_ST_NONE
                Select
                    Case $c = '0'
                        $iState = $AL_ST_ZERO
                    Case $c = "'"
                        $iState = $AL_ST_STRINGS
                    Case $c = '"'
                        $iState = $AL_ST_STRINGD
                    Case $c = "@"
                        $iState = $AL_ST_MACRO
                    Case $c = "$"
                        $iState = $AL_ST_VARIABLE
                    Case $c = ";"
                        $iState = $AL_ST_COMMENT
                    Case $c = "#"
                        $iState = $AL_ST_PREPROC
                    Case $c = "("
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OPAR
                        ExitLoop
                    Case $c = ")"
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_EPAR
                        ExitLoop
                    Case $c = "["
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OBRACK
                        ExitLoop
                    Case $c = "]"
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_EBRACK
                        ExitLoop
                    Case $c = ","
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_COMMA
                        ExitLoop
                    Case StringInStr("*/+-&", $c)
                        If __AuLex_PeekChar($lex) = "=" Then
                            __AuLex_NextChar($lex)
                            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_ASSIGN
                        Else
                            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
                        EndIf

                        ExitLoop
                    Case StringInStr("=>", $c)
                        If __AuLex_PeekChar($lex) = "=" Then
                            __AuLex_NextChar($lex)
                        EndIf

                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
                        ExitLoop
                    Case $c = "<"
                        If StringInStr("=>", __AuLex_PeekChar($lex)) Then
                            __AuLex_NextChar($lex)
                        EndIf

                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
                        ExitLoop
                    Case $c = "^"
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
                        ExitLoop
                    Case $c = "."
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
                        ExitLoop
                    Case $c = "?" Or $c = ":"
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
                        ExitLoop
                    Case $c = "_"
                        $c2 = __AuLex_PeekChar($lex)

                        If StringIsAlNum($c2) Or $c2 = "_" Then
                            $iState = $AL_ST_KEYWORD
                        ElseIf BitAND($lex[$AL_LEXI_FLAGS], $AL_FLAG_AUTOLINECONT) Then
                            $iState = $AL_ST_LINECONT
                        Else
                            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_LINECONT
                            ExitLoop
                        EndIf
                    Case StringIsDigit($c)
                        $iState = $AL_ST_INT
                    Case StringIsAlpha($c)
                        $iState = $AL_ST_KEYWORD
                    Case Else
                        ; ERROR: Invalid character
                        Return SetError(@ScriptLineNumber, 0, _
                                _Error_CreateLex("Invalid character '" & $c & "'", $lex))
                EndSelect
            Case $AL_ST_INT
                If $c = '.' Then
                    $iState = $AL_ST_FLOAT
                ElseIf $c = 'e' Then
                    $iState = $AL_ST_FLOATE
                ElseIf Not StringIsDigit($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_NUMBER

                    ExitLoop
                EndIf
            Case $AL_ST_FLOAT
                If $c = 'e' Then
                    $iState = $AL_ST_FLOATE
                ElseIf Not StringIsDigit($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_NUMBER

                    ExitLoop
                EndIf
            Case $AL_ST_FLOATE
                If $c = '+' Or $c = '-' Or StringIsDigit($c) Then
                    $iState = $AL_ST_FLOATES
                Else
                    __AuLex_PrevChar($lex)

                    ; NB: Next token will be 'e' which is most likely an error.
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_NUMBER

                    ExitLoop
                EndIf
            Case $AL_ST_FLOATES
                If Not StringIsDigit($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_NUMBER

                    ExitLoop
                EndIf
            Case $AL_ST_ZERO
                If StringInStr("Xx", $c) Then
                    $iState = $AL_ST_HEX
                ElseIf $c = '.' Then
                    $iState = $AL_ST_FLOAT
                ElseIf StringIsDigit($c) Then
                    $iState = $AL_ST_INT
                Else
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_NUMBER

                    ExitLoop
                EndIf
            Case $AL_ST_HEX
                If Not StringIsXDigit($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_NUMBER

                    ExitLoop
                EndIf
            Case $AL_ST_STRINGS
                If $c = "'" Then
                    $c2 = __AuLex_PeekChar($lex)

                    If $c2 <> "'" Then
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_STR

                        ExitLoop
                    Else
                        __AuLex_NextChar($lex)
                    EndIf
                ElseIf $c = "" Or $c = @CRLF Then
                    ; ERROR: String not terminated
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_CreateLex("String not terminated", $lex))
                EndIf
            Case $AL_ST_STRINGD
                If $c = '"' Then
                    $c2 = __AuLex_PeekChar($lex)

                    If $c2 <> '"' Then
                        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_STR

                        ExitLoop
                    Else
                        __AuLex_NextChar($lex)
                    EndIf
                ElseIf $c = "" Or $c = @CRLF Then
                    ; ERROR: String not terminated
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            Case $AL_ST_MACRO
                If $c <> "_" And Not StringIsAlNum($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_MACRO
                    ExitLoop
                EndIf
            Case $AL_ST_VARIABLE
                If $c <> "_" And Not StringIsAlNum($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_VARIABLE
                    ExitLoop
                EndIf
            Case $AL_ST_COMMENT
                If $c = "" Or __AuLex_StrIsNewLine($c) Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_COMMENT
                    ExitLoop
                EndIf
            Case $AL_ST_COMMENTMULTI
                If __AuLex_StrIsNewLine($c) Then
                    $iState = $AL_ST_COMMENTMULTINL
                ElseIf $c = "" Then
                    ; ERROR: Multiline comment not terminated
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_CreateLex("Multiline comment not terminated", $lex))
                EndIf
            Case $AL_ST_COMMENTMULTINL
                If $c = "#" Then
                    $iState = $AL_ST_COMMENTMULTIEND
                    $anchor = $lex[$AL_LEXI_ABS]
                ElseIf $c = "" Then
                    ; ERROR: Multiline comment not terminated
                    Return SetError(@ScriptLineNumber, 0, 0)
                ElseIf __AuLex_StrIsNewLine($c) Then
                    $iState = $AL_ST_COMMENTMULTINL
                Else
                    $iState = $AL_ST_COMMENTMULTI
                EndIf
            Case $AL_ST_COMMENTMULTIEND
                If StringIsSpace($c) Or $c = "" Then
                    Switch StringStripWS(StringMid($lex[$AL_LEXI_DATA], $anchor, $lex[$AL_LEXI_ABS] - $anchor), 2)
                        Case "ce", "comments-end"
                            __AuLex_PrevChar($lex)
                            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_COMMENT
                            ExitLoop
                        Case Else
                            If __AuLex_StrIsNewLine($c) Then
                                $iState = $AL_ST_COMMENTMULTINL
                            Else
                                $iState = $AL_ST_COMMENTMULTI
                            EndIf
                    EndSwitch
                EndIf
            Case $AL_ST_PREPROC
                If StringIsSpace($c) Or $c = "" Then
                    Switch StringStripWS(StringMid($lex[$AL_LEXI_DATA], $tokRet[$AL_TOKI_ABS], $lex[$AL_LEXI_ABS] - $tokRet[$AL_TOKI_ABS]), 2)
                        Case "#cs", "#comments-start"
                            $iState = $AL_ST_COMMENTMULTI
                        Case "#include"
                            If Not BitAND($lex[$AL_LEXI_FLAGS], $AL_FLAG_AUTOINCLUDE) Then ContinueCase
                            $iState = $AL_ST_INCLUDELINE
                        Case "#include-once"
                            If Not BitAND($lex[$AL_LEXI_FLAGS], $AL_FLAG_AUTOINCLUDE) Then ContinueCase

                            Local $l = $lex, $fFound = False
                            Do
                                If StringInStr($l[$AL_LEXI_INCLONCE], ";" & $lex[$AL_LEXI_FILENAME] & ";") Then
                                    $fFound = True
                                    ExitLoop
                                EndIf
                                $l = $l[$AL_LEXI_PARENT]
                            Until Not IsArray($l)

                            ; Add to list if not already there.
                            If Not $fFound Then
                                $lex[$AL_LEXI_INCLONCE] &= $lex[$AL_LEXI_FILENAME] & ";"
                            EndIf

                            If __AuLex_StrIsNewLine($c) Then
                                $iState = $AL_ST_START
                            Else
                                $iState = $AL_ST_PREPROCLINE_IGNORE
                            EndIf
                        Case Else
                            If __AuLex_StrIsNewLine($c) Then
                                ; __AuLex_PrevChar($lex)
                                $tokRet[$AL_TOKI_TYPE] = $AL_TOK_PREPROC
                                ExitLoop
                            Else
                                $iState = $AL_ST_PREPROCLINE
                            EndIf
                    EndSwitch
                EndIf
            Case $AL_ST_PREPROCLINE
                If __AuLex_StrIsNewLine($c) Or $c = "" Then
                    ; __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_PREPROC
                    ExitLoop
                EndIf
            Case $AL_ST_PREPROCLINE_IGNORE
                If __AuLex_StrIsNewLine($c) Or $c = "" Then
                    $iState = $AL_ST_START
                EndIf
            Case $AL_ST_INCLUDELINE
                If __AuLex_StrIsNewLine($c) Or $c = "" Then
                    $tokRet[$AL_TOKI_DATA] = StringMid($lex[$AL_LEXI_DATA], _
                            $tokRet[$AL_TOKI_ABS], $lex[$AL_LEXI_ABS] - $tokRet[$AL_TOKI_ABS])

                    $c2 = StringStripWS(StringTrimLeft(StringStripWS($tokRet[$AL_TOKI_DATA], 3), StringLen("#include")), 3)

                    Switch StringLeft($c2, 1)
                        Case '"'
                            If StringRight($c2, 1) <> '"' Then
                                ; ERROR: Incorrect include line
                                Return SetError(@ScriptLineNumber, 0, _
                                        _Error_Create("Badly formatted include line", 0, 0, $lex, $tokRet))
                            EndIf

                            $c2 = StringTrimLeft(StringTrimRight($c2, 1), 1)

                            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_INCLUDE
                            $tokRet[$AL_TOKI_DATA] = $c2

                            ; Resolve file path
                            $c2 = _AutoIt_ResolveInclude($lex[$AL_LEXI_FILENAME], $c2, True)
                            If @error Then
                                ; Include file not found
                                Return SetError(@ScriptLineNumber, 0, _
                                        _Error_Create("File not found", 0, 0, $lex, $tokRet))
                            EndIf
                            $tokRet[$AL_TOKI_DATA] = $c2

                            ; Check #include-once
                            Local $l = $lex, $fFound = False
                            Do
                                If StringInStr($l[$AL_LEXI_INCLONCE], ";" & $c2 & ";") Then
                                    $fFound = True
                                    ExitLoop
                                EndIf
                                $l = $l[$AL_LEXI_PARENT]
                            Until Not IsArray($l)

                            ; Parse new include if not already included.
                            If Not $fFound Then
                                Local $lexNew = _Ault_CreateLexer($c2, $lex[$AL_LEXI_FLAGS])
                                If @error Then
                                    ; Error creating new lexer
                                    Return SetError(@error, 0, $lexNew)
                                EndIf

                                $lexNew[$AL_LEXI_PARENT] = $lex
                                $lex = $lexNew

                                ; Return include line
                                __AuLex_PrevChar($lex)
                                Return $tokRet
                            EndIf

                            $iState = $AL_ST_PREPROCLINE_IGNORE
                        Case '<'
                            If StringRight($c2, 1) <> '>' Then
                                ; ERROR: Incorrect include line
                                Return SetError(@ScriptLineNumber, 0, _
                                        _Error_Create("Badly formatted include line", 0, 0, $lex, $tokRet))
                            EndIf

                            $c2 = StringTrimLeft(StringTrimRight($c2, 1), 1)

                            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_INCLUDE
                            $tokRet[$AL_TOKI_DATA] = $c2

                            ; Resolve file path
                            $c2 = _AutoIt_ResolveInclude($lex[$AL_LEXI_FILENAME], $c2, False)
                            If @error Then
                                ; Include file not found
                                Return SetError(@ScriptLineNumber, 0, _
                                        _Error_Create("File not found", 0, 0, $lex, $tokRet))
                            EndIf
                            $tokRet[$AL_TOKI_DATA] = $c2

                            ; Check #include-once
                            Local $l = $lex, $fFound = False
                            Do
                                If StringInStr($l[$AL_LEXI_INCLONCE], ";" & $c2 & ";") Then
                                    $fFound = True
                                    ExitLoop
                                EndIf
                                $l = $l[$AL_LEXI_PARENT]
                            Until Not IsArray($l)

                            ; Parse new include if not already included.
                            If Not $fFound Then
                                Local $lexNew = _Ault_CreateLexer($c2, $lex[$AL_LEXI_FLAGS])
                                If @error Then
                                    ; Error creating new lexer
                                    Return SetError(@error, 0, $lexNew)
                                EndIf

                                $lexNew[$AL_LEXI_PARENT] = $lex
                                $lex = $lexNew

                                ; Return include line
                                __AuLex_PrevChar($lex)
                                Return $tokRet
                            EndIf

                            $iState = $AL_ST_PREPROCLINE_IGNORE
                        Case Else
                            ; ERROR: Incorrect include line
                            Return SetError(@ScriptLineNumber, 0, _
                                    _Error_Create("Badly formatted include line", 0, 0, $lex, $tokRet))
                    EndSwitch
                EndIf
            Case $AL_ST_LINECONT
                If $c = ";" Then
                    $tokRet[$AL_TOKI_ABS] = $lex[$AL_LEXI_ABS] - 1
                    $tokRet[$AL_TOKI_LINE] = $lex[$AL_LEXI_LINE]
                    $tokRet[$AL_TOKI_COL] = $lex[$AL_LEXI_COL] - 1

                    $iState = $AL_ST_COMMENT
                    $lex[$AL_LEXI_FLAGS] = BitOR($lex[$AL_LEXI_FLAGS], $__AL_FLAG_LINECONT)
                ElseIf __AuLex_StrIsNewLine($c) Then
                    $iState = $AL_ST_START
                ElseIf $c = "" Then
                    ; Error: No line after a continuation
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_Create("No line after a continuation", 0, 0, $lex, $tokRet))
                ElseIf Not StringIsSpace($c) Then
                    ; ERROR: Something after a line continuation
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_Create("Extra characters on line", 0, 0, $lex, $tokRet))
                EndIf
            Case $AL_ST_KEYWORD
                If Not (StringIsAlNum($c) Or $c = "_") Then
                    __AuLex_PrevChar($lex)
                    $tokRet[$AL_TOKI_TYPE] = $AL_TOK_WORD
                    ExitLoop
                EndIf
            Case Else
                ; Serious issue with the lexer.
                Return SetError(@ScriptLineNumber, 0, _
                        _Error_CreateLex("Lexer logic error", $lex))
        EndSwitch
    WEnd

    $tokRet[$AL_TOKI_DATA] = StringMid($lex[$AL_LEXI_DATA], _
            $tokRet[$AL_TOKI_ABS], $lex[$AL_LEXI_ABS] - $tokRet[$AL_TOKI_ABS])

    $tokRet[$AL_TOKI_DATA] = StringStripWS($tokRet[$AL_TOKI_DATA], 3)

    If $tokRet[$AL_TOKI_DATA] = "Or" Or $tokRet[$AL_TOKI_DATA] = "And" Then
        $tokRet[$AL_TOKI_TYPE] = $AL_TOK_OP
    ElseIf $tokRet[$AL_TOKI_TYPE] = $AL_TOK_WORD And _
            Not BitAND($lex[$AL_LEXI_FLAGS], $AL_FLAG_NORESOLVEKEYWORD) Then
        If _Ault_IsKeyword($tokRet[$AL_TOKI_DATA]) Then
            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD
        ElseIf _Ault_IsStandardFunc($tokRet[$AL_TOKI_DATA]) Then
            $tokRet[$AL_TOKI_TYPE] = $AL_TOK_FUNC
        EndIf
    EndIf

    Return $tokRet
EndFunc   ;==>_Ault_LexerStep


; Returns the next character and increments the counters.
Func __AuLex_NextChar(ByRef $lex)
    Local $ret = __AuLex_PeekChar($lex)
    If $ret = "" Then Return ""

    $lex[$AL_LEXI_ABS] += StringLen($ret)

    If __AuLex_StrIsNewLine($ret) Then
        $lex[$AL_LEXI_LINE] += 1
        $lex[$AL_LEXI_COL] = 1
    Else
        $lex[$AL_LEXI_COL] += StringLen($ret)
    EndIf

    Return $ret
EndFunc   ;==>__AuLex_NextChar

Func __AuLex_PrevChar(ByRef $lex)
    If $lex[$AL_LEXI_ABS] >= StringLen($lex[$AL_LEXI_DATA]) Then Return "" ; Don't step back from EOF

    Local $ret = StringMid($lex[$AL_LEXI_DATA], $lex[$AL_LEXI_ABS] - 1, 1)

    If $ret = @LF Then
        Local $r2 = StringMid($lex[$AL_LEXI_DATA], $lex[$AL_LEXI_ABS] - 2, 1)

        If $r2 = @CR Then $ret = @CRLF
    EndIf

    $lex[$AL_LEXI_ABS] -= StringLen($ret)

    If __AuLex_StrIsNewLine($ret) Then
        $lex[$AL_LEXI_LINE] -= 1
        $lex[$AL_LEXI_COL] = $lex[$AL_LEXI_ABS] - _
                _Max(StringInStr($lex[$AL_LEXI_DATA], @LF, 2, -1, $lex[$AL_LEXI_ABS], $lex[$AL_LEXI_ABS]), _
                StringInStr($lex[$AL_LEXI_DATA], @CR, 2, -1, $lex[$AL_LEXI_ABS], $lex[$AL_LEXI_ABS]))
    Else
        $lex[$AL_LEXI_COL] -= StringLen($ret)
    EndIf

    Return $ret
EndFunc   ;==>__AuLex_PrevChar

; Returns the next character without incrementing any of the counters.
Func __AuLex_PeekChar(ByRef $lex)
    Local $ret = StringMid($lex[$AL_LEXI_DATA], $lex[$AL_LEXI_ABS], 1)

    If $ret = @CR Then
        Local $r2 = StringMid($lex[$AL_LEXI_DATA], $lex[$AL_LEXI_ABS] + 1, 1)

        If $r2 = @LF Then $ret = @CRLF
    EndIf

    Return $ret
EndFunc   ;==>__AuLex_PeekChar

Func __AuLex_StrIsNewLine($c)
    Return StringInStr(@CRLF, $c)
EndFunc   ;==>__AuLex_StrIsNewLine
