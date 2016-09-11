

#include-once
#include <Array.au3>
#include "Lexer.au3"
#include "AST.au3"
#include "Token.au3"
#include "ErrorHandler.au3"


Global Enum _
        $AP_OPPREC_NOT = 100, _
        $AP_OPPREC_EXP = 90, _
        $AP_OPPREC_MUL = 80, _
        $AP_OPPREC_ADD = 70, _
        $AP_OPPREC_CAT = 60, _
        $AP_OPPREC_CMP = 50, _
        $AP_OPPREC_AND = 40


Func _Ault_ParseFile($sFile, $lexerFlags = $AL_FLAG_AUTOLINECONT)
    Local $l = _Ault_CreateLexer($sFile, $lexerFlags)
    If @error Then Return SetError(@error, 0, $l)

    Local $ret = _Ault_Parse($l)
    Return SetError(@error, @extended, $ret)
EndFunc   ;==>_Ault_ParseFile

Func _Ault_Parse(ByRef $lexer)
    Local $aSt[100][$_AP_STI_COUNT]
    $aSt[0][0] = 0

    Local $tk[$_AL_TOKI_COUNT]

    $err = __AuParse_GetTok($lexer, $tk)
    If @error Then Return SetError(@error, 0, $err)

    $err = _Ault_ParseChild($lexer, $aSt, $tk)
    If @error Then Return SetError(@error, @extended, $err)

    REturn $aSt
EndFunc

Func _Ault_ParseChild(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkIncl = 0)
    If Not IsArray($lexer) Then
        ConsoleWrite("Dude. That needs to be an array." & @LF)
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Local $iSt, $err

    If IsArray($tkIncl) Then
        $iSt = __AuAST_AddBranchTok($aSt, $tkIncl)
    Else
        $iSt = __AuAST_AddBranch($aSt, $AP_BR_FILE, $lexer[$AL_LEXI_FILENAME])
    EndIf

    Local $i
    While $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOF
        $i = __AuParse_ParseLine($lexer, $aSt, $tk, True)
        If @error Then Return SetError(@error, 0, $i)

        If $i = -1 Then ExitLoop ; Shouldn't happen?

        If $i Then $aSt[$iSt][$AP_STI_LEFT] &= $i & ","
    WEnd
    $aSt[$iSt][$AP_STI_LEFT] = StringTrimRight($aSt[$iSt][$AP_STI_LEFT], 1)

    Return $iSt
EndFunc   ;==>_Ault_Parse



Func __AuParse_ParseExpr(ByRef $lexer, ByRef $aSt, ByRef $tk, $rbp = 0)
    Local $tkPrev = $tk, $err

    $err = __AuParse_GetTok($lexer, $tk)
    If @error Then Return SetError(@error, 0, $err)

    Local $left = __AuParse_ParseExpr_Nud($lexer, $aSt, $tk, $tkPrev)
    If @error Then Return SetError(@error, 0, $left)

    While __AuParse_ParseExpr_Lbp($tk) > $rbp
        $tkPrev = $tk

        $err = __AuParse_GetTok($lexer, $tk)
        If @error Then Return SetError(@error, 0, $err)

        $left = __AuParse_ParseExpr_Led($lexer, $aSt, $tk, $tkPrev, $left)
        If @error Then Return SetError(@error, 0, $left)
    WEnd

    Return $left
EndFunc   ;==>__AuParse_ParseExpr

Func __AuParse_ParseExpr_Nud(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkPrev)
    Local $iStRet, $i, $err

    Select
        Case ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_NUMBER) Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_STR) Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD And $tkPrev[$AL_TOKI_DATA] = "True") Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD And $tkPrev[$AL_TOKI_DATA] = "False") Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD And $tkPrev[$AL_TOKI_DATA] = "Default")

            $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev)

        Case $tkPrev[$AL_TOKI_TYPE] = $AL_TOK_VARIABLE Or _
                $tkPrev[$AL_TOKI_TYPE] = $AL_TOK_MACRO
            $tkOBrack = $tk

            If $tk[$AL_TOKI_TYPE] = $AL_TOK_OPAR Then
                $err = __AuParse_GetTok($lexer, $tk)
                If @error Then Return SetError(@error, 0, $err)

                $iFunc = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
            ElseIf $tk[$AL_TOKI_TYPE] = $AL_TOK_OBRACK Then
                $err = __AuParse_GetTok($lexer, $tk)
                If @error Then Return SetError(@error, 0, $err)

                $i = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $i, $tkOBrack)
                If @error Then Return SetError(@error, 0, $iStRet)
            Else
                $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev)
            EndIf

        Case $tkPrev[$AL_TOKI_TYPE] = $AL_TOK_OPAR
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_GROUP, "", -1, "", _
                    $tkPrev)

            $i = __AuParse_ParseExpr($lexer, $aSt, $tk, 0)
            If @error Then Return SetError(@error, 0, $i)

            If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EPAR Then
                ; Error: Expected closing parentheses.
                Return SetError(@ScriptLineNumber, 0, _
                        _Error_Create("Expected closing parenthesis after expression group.", _
                            $aSt, $iStRet, $lexer, $tk))
            EndIf

            $err = __AuParse_GetTok($lexer, $tk)
            If @error Then Return SetError(@error, 0, $err)

            $aSt[$iStRet][$AP_STI_LEFT] = $i

        Case ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD And $tkPrev[$AL_TOKI_DATA] = "Not") Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_OP And $tkPrev[$AL_TOKI_DATA] = "+") Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_OP And $tkPrev[$AL_TOKI_DATA] = "-")
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_OP, $tkPrev[$AL_TOKI_DATA], -1, 0, _
                    $tkPrev)

            $i = __AuParse_ParseExpr($lexer, $aSt, $tk, $AP_OPPREC_NOT)
            If @error Then Return SetError(@error, 0, $i)

            $aSt[$iStRet][$AP_STI_LEFT] = $i

        Case ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_FUNC) Or ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_WORD)
            $tkOPar = $tk

            If $tk[$AL_TOKI_TYPE] = $AL_TOK_OPAR Then
                $err = __AuParse_GetTok($lexer, $tk)
                If @error Then Return SetError(@error, 0, $err)

                $iFunc = __AuAST_AddBranchTok($aSt, $tkPrev)

                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
                If @error Then Return SetError(@error, 0, $iStRet)
            ElseIf $tk[$AL_TOKI_TYPE] = $AL_TOK_OBRACK Then
                __AuParse_GetTok($lexer, $tk)
                If @error then Return SetError(@error, 0, $err)

                $i = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $i, $tkOBrack)
                If @error then Return SetError(@error, 0, $iStRet)
            Else
                $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev)
            EndIf

        Case Else
            ; Error: Unexpected token.
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Unexpected token at the start of an expression '" & _
                        __AuTok_TypeToStr($tkPrev[$AL_TOKI_TYPE]) & "'", $aSt, $iStRet, $lexer, $tkPrev))
    EndSelect

    Return $iStRet
EndFunc   ;==>__AuParse_ParseExpr_Nud

Func __AuParse_ParseExpr_Led(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkPrev, $left)
    Local $right, $iStRet, $s

    If $tkPrev[$AL_TOKI_TYPE] <> $AL_TOK_OP Then
        ; Error: Expected operator.
        Return SetError(@ScriptLineNumber, 0, _
                _Error_Create("Expected an infix operator.", _
                    $aSt, $iStRet, $lexer, $tk))
    EndIf

    Switch $tkPrev[$AL_TOKI_DATA]
        Case "^", "*", "/", "+", "-", "&", "=", "==", "<", ">", "<=", ">=", "<>", "And", "Or"
            $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev, $left, -1)

            $right = __AuParse_ParseExpr($lexer, $aSt, $tk, __AuParse_ParseExpr_Lbp($tkPrev))
            If @error Then Return SetError(@error, 0, $right)

            $aSt[$iStRet][$AP_STI_RIGHT] = $right
        Case Else
            ; Error: Operator not valid here
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Operator not valid infix.", _
                        $aSt, $iStRet, $lexer, $tk))
    EndSwitch

    Return $iStRet
EndFunc   ;==>__AuParse_ParseExpr_Led

Func __AuParse_ParseExpr_Lbp($tk)
    Local $iLbp = 0

    If $tk[$AL_TOKI_TYPE] = $AL_TOK_OP Then
        Switch $tk[$AL_TOKI_DATA]
            Case "Not"
                $iLbp = $AP_OPPREC_NOT
            Case "^"
                $iLbp = $AP_OPPREC_EXP
            Case "*", "/"
                $iLbp = $AP_OPPREC_MUL
            Case "+", "-"
                $iLbp = $AP_OPPREC_ADD
            Case "&"
                $iLbp = $AP_OPPREC_CAT
            Case "=", "==", "<", ">", "<=", ">=", "<>"
                $iLbp = $AP_OPPREC_CMP
            Case "And", "Or"
                $iLbp = $AP_OPPREC_AND
        EndSwitch
    EndIf

    Return $iLbp
EndFunc   ;==>__AuParse_ParseExpr_Lbp


Func __AuParse_KwordToVarF($sKword)
    Local $i = 0
    Switch $sKword
        Case "Local"
            $i = $AP_VARF_LOCAL
        Case "Global"
            $i = $AP_VARF_Global
        Case "Dim"
            $i = $AP_VARF_DIM
        Case "Const"
            $i = $AP_VARF_CONST
        Case "Static"
            $i = $AP_VARF_CONST
        Case "ByRef"
            $i = $AP_VARF_BYREF
    EndSwitch

    Return $i
EndFunc


Func __AuParse_ParseLine(ByRef $lexer, ByRef $aSt, ByRef $tk, $fTopLevel = False, $fNoEol = False)
    Local $iStRet, $i, $j
    Local $abs, $line, $col
    Local $tkFirst, $s, $err

    $tkFirst = $tk

    ; Ignore empty lines
    If $tk[$AL_TOKI_TYPE] = $AL_TOK_EOL Then
        $err = __AuParse_GetTok($lexer, $tk)
        If @Error Then Return SetError(@error, 0, $err)

        Return 0 ; __AuAST_AddBranchTok($aSt, $tkFirst)
    EndIf

    $err = __AuParse_GetTok($lexer, $tk)
    If @error Then Return SetError(@error, 0, $err)

    Switch $tkFirst[$AL_TOKI_TYPE]
        Case $AL_TOK_INCLUDE
            $iStRet = _Ault_ParseChild($lexer, $aSt, $tk, $tkFirst)
            If @Error Then Return SetError(@error, 0, $iStRet)

            $err = __AuParse_GetTok($lexer, $tk)
            If @error Then Return SetError(@error, 0, $err)

            Return $iStRet

        Case $AL_TOK_PREPROC
            Return __AuAST_AddBranchTok($aSt, $tkFirst)

        Case $AL_TOK_VARIABLE
            $op = $tk
            $iLHS = __AuAST_AddBranchTok($aSt, $tkFirst)

            ; LHS might be an array
            If $tk[$AL_TOKI_TYPE] = $AL_TOK_OBRACK Then ; Array
                $err = __AuParse_GetTok($lexer, $tk)
                If @error Then Return SetError(@error, 0, $err)

                $iLHS = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $iLHS, $op)
                If @error Then Return SetError(@error, 0, $iLHS)

				$op = $tk
            EndIf

            ; Fix for = dual usage
            If $tk[$AL_TOKI_TYPE] = $AL_TOK_OP And $tk[$AL_TOKI_DATA] = "=" Then
                ; = operator is assignment
                $tk[$AL_TOKI_TYPE] = $AL_TOK_ASSIGN
            EndIf

            ; Assignment or function call valid.
            If $tk[$AL_TOKI_TYPE] = $AL_TOK_ASSIGN Then
                $iStRet = __AuAST_AddBranchTok($aSt, $op, $iLHS, -1)

                $err = __AuParse_GetTok($lexer, $tk)
                If @error Then Return SetError(@error, 0, $err)

                $j = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then Return SetError(@error, 0, $j)

                $aSt[$iStRet][$AP_STI_RIGHT] = $j
            ElseIf $tk[$AL_TOKI_TYPE] = $AL_TOK_OPAR Then
                $err = __AuParse_GetTok($lexer, $tk)
                If @error then Return SetError(@error, 0, $err)

                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iLHS)
                If @error Then Return SetError(@error, 0, $iStRet)
            Else
                ; Not a function call or assignment
                Return SetError(@ScriptLineNumber, 0, _
                        _Error_Create("Expected function call or assignment.", _
                            $aSt, $iStRet, $lexer, $tk))
            EndIf

            If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
                ; Error: Extra characters on line
                Return SetError(@ScriptLineNumber, 0, _
                        _Error_Create("Extra characters on line.", _
                            $aSt, $iStRet, $lexer, $tk))
            EndIf

            Return $iStRet

        Case $AL_TOK_WORD, $AL_TOK_FUNC
            If $tk[$AL_TOKI_TYPE] = $AL_TOK_OPAR Then ; Function call
                $err = __AuParse_GetTok($lexer, $tk)
                If @error Then SetError(@error, 0, $err)

                $iFunc = __AuAST_AddBranchTok($aSt, $tkFirst)

                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
                If @error Then Return SetError(@error, 0, $iStRet)

                If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_Create("Extra characters on line.", _
                                $aSt, $iStRet, $lexer, $tk))
                EndIf
            Else
                ; Error: Expected function call
                Return SetError(@ScriptLineNumber, 0, _
                        _Error_Create("Expected a function call.", _
                            $aSt, $iStRet, $lexer, $tk))
            EndIf

        Case $AL_TOK_KEYWORD
            Switch $tkFirst[$AL_TOKI_DATA]
                Case "Func"
                    If Not $fTopLevel Then
                        ; Function definition not valid except at file level.
                        Return SetError(@ScriptLineNumber, 0, _
                                _Error_Create("Function definition not valid except at file level", _
                                    $aSt, $iStRet, $lexer, $tk))
                    EndIf

                    $iStRet = __AuParse_ParseFuncDecl($lexer, $aSt, $tk)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "ContinueCase"
                    $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)
                    $aSt[$iStRet][$AP_STI_BRTYPE] = $AP_BR_STMT

                Case "Return", "ExitLoop", "ContinueLoop", "Exit"
                    $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)
                    $aSt[$iStRet][$AP_STI_BRTYPE] = $AP_BR_STMT

                    ; Statements can take an expression
                    If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
                        $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
                        If @error Then Return SetError(@error, 0, $i)

                        $aSt[$iStRet][$AP_STI_LEFT] = $i
                    EndIf

                Case "Redim"
                    $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)
                    $aSt[$iStRet][$AP_STI_BRTYPE] = $AP_BR_STMT

                    ; Statements can take an expression
                    If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
                        $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
                        If @error Then Return SetError(@error, 0, $i)

                        $aSt[$iStRet][$AP_STI_LEFT] = $i

                        If $aSt[$i][$AP_STI_BRTYPE] <> $AP_BR_LOOKUP Then
                            ; Expecting array redim statement
                            Return SetError(@ScriptLineNumber, 0, _
                                    _Error_Create("ReDim statement requires array expression", _
                                        $aSt, $iStRet, $lexer, $tk))
                        EndIf
                    EndIf

                Case "If"
                    $iStRet = __AuParse_ParseIf($lexer, $aSt, $tk, $tkFirst)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "Do"
                    $iStRet = __AuParse_ParseDo($lexer, $aSt, $tk, $tkFirst)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "While"
                    $iStRet = __AuParse_ParseWhile($lexer, $aSt, $tk, $tkFirst)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "For"
                    $iStRet = __AuParse_ParseFor($lexer, $aSt, $tk, $tkFirst)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "Select"
                    $iStRet = __AuParse_ParseSelect($lexer, $aSt, $tk, $tkFirst)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "Switch"
                    $iStRet = __AuParse_ParseSwitch($lexer, $aSt, $tk, $tkFirst)
                    If @error Then Return SetError(@error, 0, $iStRet)

                Case "Local", "Global", "Dim", "Enum", "Static", "Const"
                    ; Rules are:
                    ; Local, Global, Dim can only appear first
                    ; Same keyword can't appear twice
                    ; Enum must come last.

                    $iStRet = __AuAST_AddBranch($aSt, $AP_BR_DECL, _
                            __AuParse_KwordToVarF($tkFirst[$AL_TOKI_DATA]), "", "", $tkFirst)

                    While $tk[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD
                        Select
                            Case BitAND($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_ENUM)
                                ; Wrong keyword, enum must come last
                                Return SetError(@ScriptLineNumber, 0, _
                                        _Error_Create("Keyword not valid here", _
                                            $aSt, $iStRet, $lexer, $tk))

                            Case Not BitAND($aSt[$iStRet][$AP_STI_VALUE], BitNOT(BitOR($AP_VARF_LOCAL, $AP_VARF_GLOBAL, $AP_VARF_DIM))) _
                                    And BitAND($aSt[$iStRet][$AP_STI_VALUE], BitOR($AP_VARF_LOCAL, $AP_VARF_GLOBAL, $AP_VARF_DIM))
                                ; Local, Global or Dim

                                If $tk[$AL_TOKI_DATA] = "Static" Then
                                    $aSt[$iStRet][$AP_STI_VALUE] = BitOR($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_STATIC)
                                ElseIf $tk[$AL_TOKI_DATA] = "Const" Then
                                    $aSt[$iStRet][$AP_STI_VALUE] = BitOR($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_CONST)
                                ElseIf $tk[$AL_TOKI_DATA] = "Enum" Then
                                    $aSt[$iStRet][$AP_STI_VALUE] = BitOR($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_ENUM)
                                Else
                                    ; Wrong keyword
                                    Return SetError(@ScriptLineNumber, 0, _
                                            _Error_Create("Keyword not valid here", _
                                                $aSt, $iStRet, $lexer, $tk))
                                EndIf

                            Case BitAND($aSt[$iStRet][$AP_STI_VALUE], BitOR($AP_VARF_STATIC, $AP_VARF_CONST))
                                If $tk[$AL_TOKI_DATA] = "Enum" Then
                                    $aSt[$iStRet][$AP_STI_VALUE] = BitOR($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_ENUM)
                                ElseIf $tk[$AL_TOKI_DATA] = "Static" Then
                                    If BitAND($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_STATIC) then
                                        ; Static keyword duplicated.
                                        Return SetError(@ScriptLineNumber, 0, _
                                                _Error_Create("Static keyword duplicated", _
                                                    $aSt, $iStRet, $lexer, $tk))
                                    Else
                                        $aSt[$iStRet][$AP_STI_VALUE] = BitOR($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_STATIC)
                                    EndIf
                                ElseIf $tk[$AL_TOKI_DATA] = "Const" Then
                                    If BitAND($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_CONST) then
                                        ; Static keyword duplicated.
                                        Return SetError(@ScriptLineNumber, 0, _
                                                _Error_Create("Const keyword duplicated", _
                                                    $aSt, $iStRet, $lexer, $tk))
                                    Else
                                        $aSt[$iStRet][$AP_STI_VALUE] = BitOR($aSt[$iStRet][$AP_STI_VALUE], $AP_VARF_CONST)
                                    EndIf
                                Else
                                    ; Wrong keyword
                                    Return SetError(@ScriptLineNumber, 0, _
                                            _Error_Create("Keyword not valid here", _
                                                $aSt, $iStRet, $lexer, $tk))
                                EndIf

                            Case Else
                                ; Parser logic error
                                Return SetError(@ScriptLineNumber, 0, _
                                        _Error_Create("Parser logic error", _
                                            $aSt, $iStRet, $lexer, $tk))
                        EndSelect

                        $err = __AuParse_GetTok($lexer, $tk)
                        If @error Then Return SetError(@error, 0, $err)
                    WEnd

                    ; Parse variable list
                    If BitAND($i, $AP_VARF_ENUM) Then
                        $aSt[$iStRet][$AP_STI_BRTYPE] = $AP_BR_ENUMDEF ; Correct the type
                        $iStRet = __AuParse_ParseEnumDecls($lexer, $aSt, $tk, $iStRet)
                        If @error Then Return SEtError(@error, 0, $iStRet)
                    Else
                        $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $iStRet)
                        If @error Then Return SEtError(@error, 0, $iStRet)
                    EndIf

                Case Else
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_Create("Keyword '" & $tkFirst[$AL_TOKI_DATA] & "' not valid at the start of a line.", _
                                $aSt, $iStRet, $lexer, $tkFirst))
            EndSwitch

        Case Else
            ; Unexpected Token
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Unexpected token starting a line '" & __AuTok_TypeToStr($tk[$AL_TOKI_TYPE]) & "'.", _
                        $aSt, $iStRet, $lexer, $tk))
    EndSwitch

    If Not $fNoEol Then
        If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
            ; Extra characters on line
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Extra symbols on the line", _
                        $aSt, $iStRet, $lexer, $tk))
        EndIf

        $err = __AuParse_GetTok($lexer, $tk)
        If @error Then Return SetError(@error, 0, $err)
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseLine

Func __AuParse_ParseIf(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkIf)
    Local $iCondition, $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_IF, -1, "", "", $tkIf)

    ; Parse Condition
    $iCondition = __AuParse_ParseExpr($lexer, $aSt, $tk)
    If @error Then Return SetError(@error, 0, $iCondition)

    $aSt[$iStRet][$AP_STI_VALUE] = $iCondition

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Then") Then
        ; Error: If statement has no matching Then
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    If __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Multiline IF

        Local $tkElse, $fElse = False, $iElseif = $iStRet
        While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "EndIf")
            $tkElse = $tk

            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "ElseIf") Then
                If $fElse Then
                    ; Elseif appearing after else?
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf

                ; Tidy previous else
                $aSt[$iElseif][$AP_STI_RIGHT] = StringTrimRight($aSt[$iElseif][$AP_STI_RIGHT], 1)

                ; Create new elseif branch
                $iElseif = __AuAST_AddBranch($aSt, $AP_BR_IF, -1, "", "", $tkElse)
                $aSt[$iStRet][$AP_STI_LEFT] &= $iElseif & ","

                ; Parse Condition
                $iCondition = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then Return SetError(@error, 0, $iCondition)

                $aSt[$iElseif][$AP_STI_VALUE] = $iCondition

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Then") Then
                    ; Error: ElseIf statement has no matching Then
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Else") Then
                ; Else

                ; Tidy previous else
                $aSt[$iElseif][$AP_STI_RIGHT] = StringTrimRight($aSt[$iElseif][$AP_STI_RIGHT], 1)

                ; Create new elseif branch
                $iElseif = __AuAST_AddBranch($aSt, $AP_BR_IF, "", "", "", $tkElse)
                $aSt[$iStRet][$AP_STI_LEFT] &= $iElseif & ","
                $fElse = True

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            Else
                $i = __AuParse_ParseLine($lexer, $aSt, $tk)
                If @error Then
                    ; Error: Error parsing line
                    Return SetError(@error, 0, $i)
                EndIf

                If $i Then $aSt[$iElseif][$AP_STI_RIGHT] &= $i & ","
            EndIf
        WEnd

        $aSt[$iElseif][$AP_STI_RIGHT] = StringTrimRight($aSt[$iElseif][$AP_STI_RIGHT], 1)
    Else
        Local $sBody = __AuParse_ParseLine($lexer, $aSt, $tk, False, True)
        If @error Then Return SetError(@error, 0, $sBody)

        $aSt[$iStRet][$AP_STI_RIGHT] = $sBody
    EndIf

    $aSt[$iStRet][$AP_STI_LEFT] = StringTrimRight($aSt[$iStRet][$AP_STI_LEFT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseIf

Func __AuParse_ParseWhile(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkWhile)
    Local $iCondition, $sBody, $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_WHILE, "", -1, "", _
            $tkWhile)

    $iCondition = __AuParse_ParseExpr($lexer, $aSt, $tk)
    If @error Then Return SetError(@error, 0, $iCondition)

    $aSt[$iStRet][$AP_STI_LEFT] = $iCondition

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "WEnd")
        $i = __AuParse_ParseLine($lexer, $aSt, $tk)
        If @error Then
            ; Error: Error parsing line
            Return SetError(@error, 0, $i)
        EndIf

        If $i Then $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
    WEnd
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseWhile

Func __AuParse_ParseFor(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkFor)
    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_FOR, "", -1, "", _
            $tkFor)

    ; Parse Variable
    Local $tkVar = $tk

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_VARIABLE) Then
        ; Unexpected token
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    $aSt[$iStRet][$AP_STI_VALUE] = __AuAST_AddBranchTok($aSt, $tkVar)

    If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "In") Then
        ; For .. In .. Next
        $aSt[$iStRet][$AP_STI_BRTYPE] = $AP_BR_FORIN

        ; Get Next Var
        $tkVar = $tk
        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_VARIABLE) Then
            ; Unexpected token
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
        $aSt[$iStRet][$AP_STI_LEFT] = __AuAST_AddBranchTok($aSt, $tkVar)
    ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then
        ; For .. = .. To .. Next

        ; Parse From
        $iFrom = __AuParse_ParseExpr($lexer, $aSt, $tk)
        If @error Then Return SetError(@error, 0, $iFrom)

        $aSt[$iStRet][$AP_STI_LEFT] = $iFrom

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "To") Then
            ; Error: Expected TO
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf

        ; Parse To
        $iTo = __AuParse_ParseExpr($lexer, $aSt, $tk)
        If @error Then Return SetError(@error, 0, $iTo)

        $aSt[$iStRet][$AP_STI_LEFT] &= "," & $iTo

        If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Step") Then
            ; Step used

            If $tk[$AL_TOKI_TYPE] <> $AL_TOK_OP Then
                If $tk[$AL_TOKI_TYPE] = $AL_TOK_NUMBER Then
                    ; Step is +N
                    $aSt[$iStRet][$AP_STI_LEFT] &= ",+," & $tk[$AL_TOKI_DATA]
                    __AuParse_Accept($lexer, $tk, $AL_TOK_NUMBER)
                Else
                    ; Error: Enexpected token
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            Else
                If StringInStr("+-*/", $tk[$AL_TOKI_DATA]) Then
                    $aSt[$iStRet][$AP_STI_LEFT] &= "," & $tk[$AL_TOKI_DATA] & ","
                    __AuParse_Accept($lexer, $tk, $AL_TOK_OP)

                    If $tk[$AL_TOKI_TYPE] = $AL_TOK_NUMBER Then
                        $aSt[$iStRet][$AP_STI_LEFT] &= $tk[$AL_TOKI_DATA]
                        __AuParse_Accept($lexer, $tk, $AL_TOK_NUMBER)
                    Else
                        ; Expecting number
                        Return SetError(@ScriptLineNumber, 0, 0)
                    EndIf
                Else
                    ; Illegal step operator
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            EndIf
        EndIf
    Else
        ; Unexpected Token
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    ; Parse Body
    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Next")
        $i = __AuParse_ParseLine($lexer, $aSt, $tk)
        If @error Then
            ; Error: Error parsing line
            Return SetError(@error, 0, $i)
        EndIf

        If $i Then $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
    WEnd
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseFor

Func __AuParse_ParseDo(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkDo)
    Local $iCondition, $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_DO, "", -1, "", _
            $tkDo)

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    ; Parse Body
    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Until")
        $i = __AuParse_ParseLine($lexer, $aSt, $tk)
        If @error Then
            ; Error: Error parsing line
            Return SetError(@error, 0, $i)
        EndIf

        If $i Then $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
    WEnd
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    ; Parse Condition
    $iCondition = __AuParse_ParseExpr($lexer, $aSt, $tk)
    If @error Then Return SetError(@error, 0, $iCondition)

    $aSt[$iStRet][$AP_STI_LEFT] = $iCondition

    Return $iStRet
EndFunc   ;==>__AuParse_ParseDo

Func __AuParse_ParseSelect(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkSelect)
    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_SELECT, "", "", "", _
            $tkSelect)

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Local $iCase = 0, $iBody = 0, $iExpr = 0, $tkCase
    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "EndSelect")
        $tkCase = $tk

        If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Case") Then ; New Case
            ; Clear up old case data
            If $iCase Then
                $aSt[$iCase][$AP_STI_RIGHT] = StringTrimRight($aSt[$iCase][$AP_STI_RIGHT], 1)
            EndIf

            ; Create case.
            $iCase = __AuAST_AddBranch($aSt, $AP_BR_CASE, "", "", "", _
                    $tkCase)
            $aSt[$iStRet][$AP_STI_RIGHT] &= $iCase & ","

            ; Parse case expression.
            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Else") Then
                $aSt[$iCase][$AP_STI_VALUE] = "Else"
            Else
                $iExpr = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then Return SetError(@error, 0, $iExpr)

                $aSt[$iCase][$AP_STI_LEFT] = $iExpr
            EndIf

            If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                ; Error: Extra characters on line
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf
        Else
            ; Another code line
            $iBody = __AuParse_ParseLine($lexer, $aSt, $tk)
            If @error Then
                ; Error: Error parsing line
                Return SetError(@error, 0, $iBody)
            EndIf

            If $iBody Then $aSt[$iCase][$AP_STI_RIGHT] &= $iBody & ","
        EndIf
    WEnd

    ; Tidy up cases list
    If $iCase Then
        $aSt[$iCase][$AP_STI_RIGHT] = StringTrimRight($aSt[$iCase][$AP_STI_RIGHT], 1)
    EndIf
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseSelect

Func __AuParse_ParseSwitch(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkSwitch)
    Local $iExpr

    ; Create branch
    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_SWITCH, "", "", "", _
            $tkSwitch)

    ; Parse Expression
    $iExpr = __AuParse_ParseExpr($lexer, $aSt, $tk)
    If @error Then Return SetError(@error, 0, $iExpr)

    $aSt[$iStRet][$AP_STI_LEFT] = $iExpr

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    ; Parse body
    Local $iCase = 0, $iBody = 0, $iExpr = 0, $tkCase
    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "EndSwitch")
        $tkCase = $tk

        If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Case") Then ; New Case
            ; Clear up old case data
            If $iCase Then
                $aSt[$iCase][$AP_STI_RIGHT] = StringTrimRight($aSt[$iCase][$AP_STI_RIGHT], 1)
            EndIf

            ; Create case.
            $iCase = __AuAST_AddBranch($aSt, $AP_BR_CASE, "", "", "", _
                    $tkCase)
            $aSt[$iStRet][$AP_STI_RIGHT] &= $iCase & ","

            ; Parse case expression.
            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Else") Then
                $aSt[$iCase][$AP_STI_VALUE] = "Else"
            Else
                Do
                    $iExpr = __AuParse_ParseExpr($lexer, $aSt, $tk)
                    If @error Then Return SetError(@error, 0, $iExpr)

                    $aSt[$iCase][$AP_STI_LEFT] &= $iExpr & ","
                Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)

                $aSt[$iCase][$AP_STI_LEFT] = StringTrimRight($aSt[$iCase][$AP_STI_LEFT], 1)
            EndIf

            If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                ; Error: Extra characters on line
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf
        ElseIf $iCase = 0 And __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
            ; Empty line before first case?
        Else
            ; Another code line
            $iBody = __AuParse_ParseLine($lexer, $aSt, $tk)
            If @error Then
                ; Error: Error parsing line
                Return SetError(@error, 0, $iBody)
            EndIf

            If $iBody Then $aSt[$iCase][$AP_STI_RIGHT] &= $iBody & ","
        EndIf
    WEnd

    ; Tidy up cases list
    If $iCase Then
        $aSt[$iCase][$AP_STI_RIGHT] = StringTrimRight($aSt[$iCase][$AP_STI_RIGHT], 1)
    EndIf
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseSwitch


Func __AuParse_ParseFuncCall(ByRef $lexer, ByRef $aSt, ByRef $tk, $iFunc)
    Local $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_FUNCCALL, "", $iFunc, "", $tk)

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
        Do
            $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
            If @error Then Return SetError(@error, 0, $i)

            $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
        Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)
        $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
            ; Error: Expected closing parenthesis.
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Expected closing parenthesis.", $aSt, $iStRet, $lexer, $tk))
        EndIf
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseFuncCall


Func __AuParse_ParseParamDecl(ByRef $lexer, ByRef $aSt, ByRef $tk)
    Local $iFlags, $iDefault

    $first = $tk

    $iFlags = 0

    If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "ByRef") Then
        $iFlags = BitOR($iFlags, $AP_VARF_BYREF)

        If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const") Then
            $iFlags = BitOR($iFlags, $AP_VARF_CONST)
        EndIf
    EndIf

    If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const") Then
        $iFlags = BitOR($iFlags, $AP_VARF_CONST)

        If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Byref") Then
            $iFlags = BitOR($iFlags, $AP_VARF_BYREF)
        EndIf
    EndIf

    Local $iVar = __AuAST_AddBranchTok($aSt, $tk)
    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_DECL, $iFlags, $iVar, "", _
            $first[$AL_TOKI_ABS], $first[$AL_TOKI_LINE], $first[$AL_TOKI_COL])

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_VARIABLE) Then
        ; Error: Expected variable name
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    If __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then
        ; Default value
        $iDefault = __AuParse_ParseExpr($lexer, $aSt, $tk)
        If @error Then Return SetError(@error, 0, $iDefault)

        $aSt[$iStRet][$AP_STI_RIGHT] = $iDefault
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseParamDecl

Func __AuParse_ParseFuncDecl(ByRef $lexer, ByRef $aSt, ByRef $tk)
    Local $sFuncName = $tk[$AL_TOKI_DATA], $i

    $iStRet = __AuAST_AddBranch($aSt, $AP_BR_FUNCDEF, $sFuncName, -1, -1, _
            $tk[$AL_TOKI_ABS], $tk[$AL_TOKI_LINE], $tk[$AL_TOKI_COL])

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_WORD) Then
        ; Error: Expected function name
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_OPAR) Then
        ; Error: Expected function parameter list
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    $aSt[$iStRet][$AP_STI_LEFT] = ""
    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
        ; Parse Parameters
        Do
            $i = __AuParse_ParseParamDecl($lexer, $aSt, $tk)
            If @error Then
                ; Error: Error parsing parameter declaration
                Return SetError(@error, 0, $i)
            EndIf

            $aSt[$iStRet][$AP_STI_LEFT] &= $i & ","
        Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)
        $aSt[$iStRet][$AP_STI_LEFT] = StringTrimRight($aSt[$iStRet][$AP_STI_LEFT], 1)

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
            ; Error: Expected closing parenthesis
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
    EndIf

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Expected newline
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    ; Parse Lines in function body
    $aSt[$iStRet][$AP_STI_RIGHT] = ""
    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "EndFunc")
        $i = __AuParse_ParseLine($lexer, $aSt, $tk)
        If @error Then
            ; Error: Error parsing line
            Return SetError(@error, 0, $i)
        EndIf

        If $i Then $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
    WEnd
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseFuncDecl

Func __AuParse_ParseEnumDecls(ByRef $lexer, ByRef $aSt, ByRef $tk, $iStRet)
    Local $var, $iValue, $j, $iIncrement = 0
    Local $sDecls = ""

    Do
        $iDecl = __AuAST_AddBranch($aSt, $AP_BR_DECL, $aSt[$iStRet][$AP_STI_VALUE], -1, -1)

        ; Add variable
        $var = $tk
        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_VARIABLE) _
                And Not __AuParse_Accept($lexer, $tk, $AL_TOK_WORD) Then
            ; Error: Expected a variable name.
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
        $aSt[$iDecl][$AP_STI_LEFT] = __AuAST_AddBranchTok($aSt, $var)

        $iValue = ""
        If __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then ; Definition
            $iValue = __AuParse_ParseExpr($lexer, $aSt, $tk)
            If @error Then Return SetError(@error, 0, $iValue)
        EndIf
        $aSt[$iDecl][$AP_STI_RIGHT] = $iValue

        $aSt[$iStRet][$AP_STI_LEFT] &= $iDecl & ","
    Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)

    $aSt[$iStRet][$AP_STI_LEFT] = StringTrimRight($aSt[$iStRet][$AP_STI_LEFT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseEnumDecls

Func __AuParse_ParseDecls(ByRef $lexer, ByRef $aSt, ByRef $tk, $iFirstDecl)
    Local $iVar, $iValue, $i, $err

    Local $iStRet = ""
    Local $iDecl = 0

    While 1
        ; Parsing new declaration/definition
        If $iDecl = 0 Then
            $iDecl = $iFirstDecl
        Else
            $iDecl = __AuAST_AddBranch($aSt, $AP_BR_DECL, $aSt[$iFirstDecl][$AP_STI_VALUE], -1, -1)
        EndIf
        $iStRet &= $iDecl & ","

        ; Parse Variable
        $iVar = __AuAST_AddBranchTok($aSt, $tk)

        If $tk[$AL_TOKI_TYPE] <> $AL_TOK_VARIABLE Then
            ; Error: Expected a variable name.
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Expected a variable", _
                        $aSt, $iStRet, $lexer, $tk))
        EndIf
        $aSt[$iDecl][$AP_STI_LEFT] = $iVar

        $err = __AuParse_GetTok($lexer, $tk)
        If @error then Return SetError(@error, 0, $err)

        ; PArse Value
        $tkPrev = $tk
        If __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then ; Array Decl
            Local $err = __AuParse_ParseDeclArray($lexer, $aSt, $tk, $iDecl, $iVar, $tkPrev)
            If @error Then Return SetError(@error, 0, $err)
        Else
            $iValue = ""
            If __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then ; Definition
                $iValue = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then Return SetError(@error, 0, $iValue)
            EndIf

            $aSt[$iDecl][$AP_STI_RIGHT] = $iValue
        EndIf

        If $tk[$AL_TOKI_TYPE] <> $AL_TOK_COMMA Then
            ExitLoop
        EndIf

        $err = __AuParse_GetTok($lexer, $tk)
        If @error Then Return SetError(@error, 0, $err)
    WEnd

    $iStRet = StringTrimRight($iStRet, 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseDecls

; The first [ of the declaration has been accepted.
Func __AuParse_ParseDeclArray(ByRef $lexer, ByRef $aSt, ByRef $tk, $iStRet, $iVar, $tkOBrack)
    Local $iLookup, $iLiteral

    ; Parse Lookup
    ; $iVariable = __AuAST_AddBranchTok($aSt, $tkVar)
    $iLookup = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $iVar, $tkOBrack)
    If @error Then Return SetError(@error, 0, $iLookup)

    $aSt[$iStRet][$AP_STI_LEFT] = $iLookup

    ; Parse data if needed.
    If __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then
        ; Array is being defined
        $tkOBrack = $tk

        If __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK, Default) Then
            $iLiteral = __AuParse_ParseArrayLiteral($lexer, $aSt, $tk, $tkOBrack)
            If @error Then
                ; Error: Error parsing array literal
                Return SetError(@error, 0, $iLiteral)
            EndIf

            $aSt[$iStRet][$AP_STI_RIGHT] = $iLiteral
        Else
            ; Error: Expected array literal
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
    Else
        $aSt[$iStRet][$AP_STI_RIGHT] = ""
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseDeclArray

; The first [ of the declaration has been accepted.
Func __AuParse_ParseArrayLookup(ByRef $lexer, ByRef $aSt, ByRef $tk, $iVar, $tkOBrack)
    Local $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_LOOKUP, "", $iVar, "", $tkOBrack)

    Do
        $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
        If @error Then Return SetError(@error, 0, $i)

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EBRACK) Then
            ; Error: Expected closing bracket.
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf

        $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
    Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK)
    $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseArrayLookup

; The first [ of the declaration has been accepted.
Func __AuParse_ParseArrayLiteral(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkOBrack)
    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_ARRAY, "", "", "", $tkOBrack)

    Local $iExpr
    While Not __AuParse_Accept($lexer, $tk, $AL_TOK_EBRACK)
        $tkOBrack = $tk

        If __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then
            ; Nested array
            $iExpr = __AuParse_ParseArrayLiteral($lexer, $aSt, $tk, $tkOBrack)
            If @error Then
                ; Error parsing nested array
                Return SetError(@error, 0, $iExpr)
            EndIf
        Else
            $iExpr = __AuParse_ParseExpr($lexer, $aSt, $tk)
            If @error Then Return SetError(@error, 0, $iExpr)
        EndIf

        If $iExpr Then $aSt[$iStRet][$AP_STI_LEFT] &= $iExpr & ","

        If __AuParse_Accept($lexer, $tk, $AL_TOK_EBRACK) Then
            ExitLoop
        EndIf
        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA) Then
            ; Expected Comma
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
    WEnd
    $aSt[$iStRet][$AP_STI_LEFT] = StringTrimRight($aSt[$iStRet][$AP_STI_LEFT], 1)

    Return $iStRet
EndFunc   ;==>__AuParse_ParseArrayLiteral




Func __AuParse_GetTok(ByRef $lexer, ByRef $tk)
    Local $t
    Do
        $t = _Ault_LexerStep($lexer)
        If @error Then
            Return SetError(@error, 0, $t)
        EndIf
    Until $t[$AL_TOKI_TYPE] <> $AL_TOK_COMMENT

    $tk = $t
EndFunc   ;==>__AuParse_GetTok

Func __AuParse_Accept(ByRef $lexer, ByRef $tk, $iTokType = Default, $sTokData = Default)
    If $iTokType <> Default And $tk[$AL_TOKI_TYPE] <> $iTokType Then Return False
    If $sTokData <> Default And $tk[$AL_TOKI_DATA] <> $sTokData Then Return False

    Local $err = __AuParse_GetTok($lexer, $tk)
    If @error Then
        ; Error in the next token
        Return SetError(@error, 0, $err)
    EndIf

    Return True
EndFunc   ;==>__AuParse_Accept
