

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

    $err = _Ault_ParseChild($lexer, $aSt)
    If @error Then Return SetError(@error, @extended, $err)

    REturn $aSt
EndFunc

Func _Ault_ParseChild(ByRef $lexer, ByRef $aSt, $tkIncl = 0)
    If Not IsArray($lexer) Then
        ConsoleWrite("Dude. That needs to be an array." & @LF)
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Local $iSt

    Local $tk[$_AL_TOKI_COUNT]
    __AuParse_GetTok($lexer, $tk)

    If IsArray($tkIncl) Then
        $iSt = __AuAST_AddBranchTok($aSt, $tkIncl)
    Else
        $iSt = __AuAST_AddBranch($aSt, $AP_BR_FILE, $lexer[$AL_LEXI_FILENAME])
    EndIf

    Local $i
    While $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOF
        $i = __AuParse_ParseLine($lexer, $aSt, $tk, True)
        If @error Then
            ; Error: Error parsing line
            Return SetError(@error, 0, $i)
        ElseIf $i = -1 Then
            ExitLoop
        EndIf

        If $i Then $aSt[$iSt][$AP_STI_LEFT] &= $i & ","
    WEnd
    $aSt[$iSt][$AP_STI_LEFT] = StringTrimRight($aSt[$iSt][$AP_STI_LEFT], 1)

    Return $iSt
EndFunc   ;==>_Ault_Parse



Func __AuParse_ParseExpr(ByRef $lexer, ByRef $aSt, ByRef $tk, $rbp = 0)
    Local $tkPrev = $tk
    __AuParse_GetTok($lexer, $tk)

    Local $left = __AuParse_ParseExpr_Nud($lexer, $aSt, $tk, $tkPrev)
    If @error Then
        ; Error: Unexpected token
        Return SetError(@error, 0, $left)
    EndIf

    While __AuParse_ParseExpr_Lbp($tk) > $rbp
        $tkPrev = $tk
        __AuParse_GetTok($lexer, $tk)

        $left = __AuParse_ParseExpr_Led($lexer, $aSt, $tk, $tkPrev, $left)
        If @error Then
            ; Error: Error parsing expression
            Return SetError(@error, 0, $left)
        EndIf
    WEnd

    Return $left
EndFunc   ;==>__AuParse_ParseExpr

Func __AuParse_ParseExpr_Nud(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkPrev)
    Local $iStRet, $i

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

            If __AuParse_Accept($lexer, $tk, $AL_TOK_OPAR) Then
                $iFunc = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then
                $i = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $i, $tkOBrack)
            Else
                $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev)
            EndIf

        Case $tkPrev[$AL_TOKI_TYPE] = $AL_TOK_OPAR
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_GROUP, "", -1, "", _
                    $tkPrev)

            $i = __AuParse_ParseExpr($lexer, $aSt, $tk, 0)
            If @error Then
                ; Error: Error parsing expression
                Return SetError(@error, 0, $i)
            EndIf

            If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
                ; Error: Expected closing parentheses.
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf

            $aSt[$iStRet][$AP_STI_LEFT] = $i

        Case ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_KEYWORD And $tkPrev[1] = "Not") Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_OP And $tkPrev[1] = "+") Or _
                ($tkPrev[$AL_TOKI_TYPE] = $AL_TOK_OP And $tkPrev[1] = "-")
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_OP, $tkPrev[$AL_TOKI_DATA], -1, 0, _
                    $tkPrev)

            $i = __AuParse_ParseExpr($lexer, $aSt, $tk, $AP_OPPREC_NOT)
            If @error Then
                ; Error: Error parsing expression
                Return SetError(@error, 0, $i)
            EndIf

            $aSt[$iStRet][$AP_STI_LEFT] = $i

        Case $tkPrev[$AL_TOKI_TYPE] = $AL_TOK_FUNC Or $tkPrev[$AL_TOKI_TYPE] = $AL_TOK_WORD
            $tkOBrack = $tk

            If __AuParse_Accept($lexer, $tk, $AL_TOK_OPAR) Then
                $iFunc = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then
                $i = __AuAST_AddBranchTok($aSt, $tkPrev)
                $iStRet = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $i, $tkOBrack)
            Else
                $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev)
            EndIf

        Case Else
            _ArrayDisplay($tk, @ScriptLineNumber & ": Unexpected Token. ")
            ; Error: Unexpected token.
            Return SetError(@ScriptLineNumber, 0, 0)
    EndSelect

    Return SetError(@error, 0, $iStRet)
EndFunc   ;==>__AuParse_ParseExpr_Nud

Func __AuParse_ParseExpr_Led(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkPrev, $left)
    Local $right, $iStRet, $s

    If $tkPrev[$AL_TOKI_TYPE] <> $AL_TOK_OP Then
        ; Error: Expected operator.
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Switch $tkPrev[$AL_TOKI_DATA]
        Case "^", "*", "/", "+", "-", "&", "=", "==", "<", ">", "<=", ">=", "<>", "And", "Or"
            $iStRet = __AuAST_AddBranchTok($aSt, $tkPrev, $left, -1)

            $right = __AuParse_ParseExpr($lexer, $aSt, $tk, __AuParse_ParseExpr_Lbp($tkPrev))
            If @error Then
                ; Error: Error parsing expression
                Return SetError(@error, 0, $right)
            EndIf

            $aSt[$iStRet][$AP_STI_RIGHT] = $right
        Case Else
            ; Error: Operator not valid here
            Return SetError(@ScriptLineNumber, 0, 0)
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


Func __AuParse_ParseLine(ByRef $lexer, ByRef $aSt, ByRef $tk, $fTopLevel = False)
    Local $iStRet, $i, $j
    Local $abs, $line, $col
    Local $tkFirst, $s

    $tkFirst = $tk

    ; Ignore empty lines?
    If __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        Return 0 ; __AuAST_AddBranchTok($aSt, $tkFirst)
    EndIf

    Select
        Case __AuParse_Accept($lexer, $tk, $AL_TOK_INCLUDE)
            Return _Ault_ParseChild($lexer, $aSt, $tkFirst)
        Case $fTopLevel And __AuParse_Accept($lexer, $tk, $AL_TOK_EOF)
            Return -1
        Case __AuParse_Accept($lexer, $tk, $AL_TOK_PREPROC)
            $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)

        Case $fTopLevel And __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Func")
            $iStRet = __AuParse_ParseFuncDecl($lexer, $aSt, $tk)

        Case Not $fTopLevel And __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "ContinueCase")
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_STMT, $tkFirst[$AL_TOKI_DATA], "", "", _
                    $tkFirst[$AL_TOKI_ABS], $tkFirst[$AL_TOKI_LINE], $tkFirst[$AL_TOKI_COL])

            If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                ; Expecting new line after continuecase
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf

        Case Not $fTopLevel And (__AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Return") Or _
                __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "ContinueLoop") Or _
                __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "ExitLoop") Or _
                __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Exit"))
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_STMT, $tkFirst[$AL_TOKI_DATA], "", "", _
                    $tkFirst[$AL_TOKI_ABS], $tkFirst[$AL_TOKI_LINE], $tkFirst[$AL_TOKI_COL])

            If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then
                    ; Error parsing expression
                    Return SetError(@error, 0, $i)
                EndIf

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                    ; Expecting new line after return statement
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf

                $aSt[$iStRet][$AP_STI_LEFT] = $i
            EndIf

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "If")
            $iStRet = __AuParse_ParseIf($lexer, $aSt, $tk, $tkFirst)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Do")
            $iStRet = __AuParse_ParseDo($lexer, $aSt, $tk, $tkFirst)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "While")
            $iStRet = __AuParse_ParseWhile($lexer, $aSt, $tk, $tkFirst)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "For")
            $iStRet = __AuParse_ParseFor($lexer, $aSt, $tk, $tkFirst)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Select")
            $iStRet = __AuParse_ParseSelect($lexer, $aSt, $tk, $tkFirst)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Switch")
            $iStRet = __AuParse_ParseSwitch($lexer, $aSt, $tk, $tkFirst)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Local")
            $i = $AP_VARF_LOCAL

            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Enum") Then
                $iStRet = __AuParse_ParseEnumDecls($lexer, $aSt, $tk, $i, $tkFirst)
            Else
                If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const") Then
                    If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Static") Then
                        $i = BitOR($i, $AP_VARF_CONST, $AP_VARF_STATIC)
                    Else
                        $i = BitOR($i, $AP_VARF_CONST)
                    EndIf
                ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Static") Then
                    If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const") Then
                        $i = BitOR($i, $AP_VARF_STATIC, $AP_VARF_CONST)
                    Else
                        $i = BitOR($i, $AP_VARF_STATIC)
                    EndIf
                EndIf

                $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $i)
            EndIf

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Global")
            $i = $AP_VARF_GLOBAL

            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Enum") Then
                $iStRet = __AuParse_ParseEnumDecls($lexer, $aSt, $tk, $i, $tkFirst)
            Else
                If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const") Then
                    $i = BitOR($i, $AP_VARF_CONST)
                EndIf

                $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $i)
            EndIf

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Dim")
            $i = $AP_VARF_DIM

            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Enum") Then
                $i = BitOR($i, $AP_VARF_CONST)
                $iStRet = __AuParse_ParseEnumDecls($lexer, $aSt, $tk, $i, $tkFirst)
            Else
                If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const") Then
                    $i = BitOR($i, $AP_VARF_CONST)
                EndIf

                $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $i)
            EndIf

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Enum")
            $i = BitOR($AP_VARF_DIM, $AP_VARF_CONST)
            $iStRet = __AuParse_ParseEnumDecls($lexer, $aSt, $tk, $i)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Const")
            $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $AP_VARF_DIM)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Static")
            $i = $AP_VARF_STATIC

            If __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Global") Then
                $i = BitOR($i, $AP_VARF_GLOBAL)
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "Local") Then
                $i = BitOR($i, $AP_VARF_LOCAL)
            EndIf

            $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $i)

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "ReDim")
            $iStRet = __AuAST_AddBranch($aSt, $AP_BR_REDIM, "", -1, "")

            $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
            If @error Then
                ; Error: Error parsing array lookup
                Return SetError(@error, 0, $i)
            EndIf

            If $aSt[$i][$AP_STI_BRTYPE] <> $AP_BR_LOOKUP Then
                ; Expecting array redim statement
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf

            $aSt[$iStRet][$AP_STI_LEFT] = $i

        Case __AuParse_Accept($lexer, $tk, $AL_TOK_VARIABLE, Default)
            $op = $tk

            If __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then ; Array Assignment
                $iStRet = __AuAST_AddBranch($aSt, $AP_BR_ASSIGN, "???", -1, -1, $op)

                $i = __AuAST_AddBranchTok($aSt, $tkFirst)

                $i = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $i, $op)
                If @error Then
                    ; Error: Error parsing array lookup
                    Return SetError(@error, 0, $i)
                EndIf

                $aSt[$iStRet][$AP_STI_LEFT] = $i
                $aSt[$iStRet][$AP_STI_VALUE] = $tk[$AL_TOKI_DATA]

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_ASSIGN) _
                        And Not __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then
                    ; Error: Expected assignment operator
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf

                $j = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then
                    ; Error: Error parsing expression
                    Return SetError(@error, 0, $j)
                EndIf

                $aSt[$iStRet][$AP_STI_RIGHT] = $j

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
                        And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_OPAR) Then ; Function call
                $iFunc = __AuAST_AddBranchTok($aSt, $tkFirst)

                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
                If @error Then
                    ; Error parsing func call
                    Return SetError(@error, 0, $iStRet)
                EndIf

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
                        And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_ASSIGN) _
                    Or __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then ; Assignment

                ; Fix '=' seen as operator
                $op[$AL_TOKI_TYPE] = $AL_TOK_ASSIGN

                $iStRet = __AuAST_AddBranchTok($aSt, $op, -1, -1)
                $aSt[$iStRet][$AP_STI_LEFT] = __AuAST_AddBranchTok($aSt, $tkFirst)

                $j = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then
                    ; Error: Error parsing expression
                    Return SetError(@error, 0, $j)
                EndIf

                $aSt[$iStRet][$AP_STI_RIGHT] = $j

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf

            Else
                ; Error: Expected statement
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf

            ; Object lookup? Todo.
        Case __AuParse_Accept($lexer, $tk, $AL_TOK_WORD)
            If __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then ; Array Lookup
                ; Todo
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_OPAR) Then ; Function call
                $iFunc = __AuAST_AddBranchTok($aSt, $tkFirst)

                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
                If @error Then
                    ; Error: Error parsing function call
                    Return SetError(@error, 0, $iStRet)
                EndIf

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
                        And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            ElseIf __AuParse_Accept($lexer, $tk, $AL_TOK_ASSIGN) Then ; Assignment
                $iStRet = __AuAST_AddBranch($aSt, $AP_BR_ASSIGN, $s, -1, -1)

                $aSt[$iStRet][$AP_STI_LEFT] = __AuAST_AddBranchTok($aSt, $tkFirstData)

                $j = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then
                    ; Error: Error parsing expression
                    Return SetError(@error, 0, $j)
                EndIf

                $aSt[$iStRet][$AP_STI_RIGHT] = $j

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf

            Else
                ; Error: Expected statement
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf
        Case __AuParse_Accept($lexer, $tk, $AL_TOK_FUNC)
            If __AuParse_Accept($lexer, $tk, $AL_TOK_OPAR) Then ; Function call
                $iFunc = __AuAST_AddBranchTok($aSt, $tkFirst)

                $iStRet = __AuParse_ParseFuncCall($lexer, $aSt, $tk, $iFunc)
                If @error Then
                    ; Error: Error parsing function call
                    Return SetError(@error, 0, $iStRet)
                EndIf

                If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
                        And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
                    ; Error: Extra characters on line
                    Return SetError(@ScriptLineNumber, 0, 0)
                EndIf
            Else
                ; Error: Expected function call
                Return SetError(@ScriptLineNumber, 0, 0)
            EndIf
        Case Else
            _ArrayDisplay($tk, @ScriptLineNumber & ": Unexpected Token.")
            ; Error: Unexpected token.
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Unexpected token starting a line '" & __AuTok_TypeToStr($tk[$AL_TOKI_TYPE]) & "'.", _
                        $aSt, $iStRet, $lexer, $tk))
    EndSelect

    Return SetError(@error, 0, $iStRet)
EndFunc   ;==>__AuParse_ParseLine

Func __AuParse_ParseIf(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkIf)
    Local $iCondition, $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_IF, -1, "", "", $tkIf)

    ; Parse Condition
    $iCondition = __AuParse_ParseExpr($lexer, $aSt, $tk)
    If @error Then
        ; Error: Error parsing expression
        Return SetError(@error, 0, $iCondition)
    EndIf
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
                If @error Then
                    ; Error: Error parsing expression
                    Return SetError(@error, 0, $iCondition)
                EndIf
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

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
                And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
            ; Error: Extra characters on line
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
    Else
        Local $sBody = __AuParse_ParseLine($lexer, $aSt, $tk)
        If @error Then
            ; Error: Error parsing line
            Return SetError(@error, 0, $sBody)
        EndIf

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
    If @error Then
        ; Error: Error parsing expression
        Return SetError(@error, 0, $iCondition)
    EndIf

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

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
            And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

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
        If @error Then
            ; Error: Error parsing expression
            Return SetError(@error, 0, $iFrom)
        EndIf
        $aSt[$iStRet][$AP_STI_LEFT] = $iFrom

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_KEYWORD, "To") Then
            ; Error: Expected TO
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf

        ; Parse To
        $iTo = __AuParse_ParseExpr($lexer, $aSt, $tk)
        If @error Then
            ; Error: Error parsing expression
            Return SetError(@error, 0, $iTo)
        EndIf
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

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
            And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

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
    If @error Then
        ; Error: Error parsing expression
        Return SetError(@error, 0, $iCondition)
    EndIf
    $aSt[$iStRet][$AP_STI_LEFT] = $iCondition

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Error: Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

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
                If @error Then
                    ; Error in case expression
                    Return SetError(@error, 0, $iExpr)
                EndIf
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

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseSelect

Func __AuParse_ParseSwitch(ByRef $lexer, ByRef $aSt, ByRef $tk, $tkSwitch)
    Local $iExpr

    ; Create branch
    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_SWITCH, "", "", "", _
            $tkSwitch)

    ; Parse Expression
    $iExpr = __AuParse_ParseExpr($lexer, $aSt, $tk)
    If @error Then
        ; Error: Error parsing expression
        Return SetError(@error, 0, $iExpr)
    EndIf
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
                    If @error Then
                        ; Error in case expression
                        Return SetError(@error, 0, $iExpr)
                    EndIf
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

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) Then
        ; Extra characters on line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseSwitch


Func __AuParse_ParseFuncCall(ByRef $lexer, ByRef $aSt, ByRef $tk, $iFunc)
    Local $i

    Local $iStRet = __AuAST_AddBranch($aSt, $AP_BR_FUNCCALL, "", $iFunc, "", $tk)

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
        Do
            $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
            If @error Then
                ; Error: Error parsing function argument expression
                Return SetError(@error, 0, $i)
            EndIf

            $aSt[$iStRet][$AP_STI_RIGHT] &= $i & ","
        Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)
        $aSt[$iStRet][$AP_STI_RIGHT] = StringTrimRight($aSt[$iStRet][$AP_STI_RIGHT], 1)

        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EPAR) Then
            ; Error: Expected closing parenthesis.
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Expected closing parenthesis.", $aSt, $iStRet, $lexer, $tk))
        EndIf
    Else
        $aSt[$iStRet][$AP_STI_RIGHT] = 0
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
        If @error Then
            ; Error parsing expression
            Return SetError(@error, 0, $iDefault)
        EndIf

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

Func __AuParse_ParseEnumDecls(ByRef $lexer, ByRef $aSt, ByRef $tk, $iFlags, $tkEnum)
    Local $var, $iValue, $j, $iIncrement = 0
    Local $sDecls = ""

    $iStRet = __AuAST_AddBranch($aSt, $AP_BR_ENUMDEF, $iFlags, "", "", $tkEnum)

    Do
        $iDecl = __AuAST_AddBranch($aSt, $AP_BR_DECL, BitOR($iFlags, $AP_VARF_ENUM), -1, -1)

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
            If @error Then
                ; Error: Error parsing expression
                Return SetError(@error, 0, $iValue)
            EndIf
        EndIf
        $aSt[$iDecl][$AP_STI_RIGHT] = $iValue

        $aSt[$iStRet][$AP_STI_LEFT] &= $iDecl & ","
    Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)

    $aSt[$iStRet][$AP_STI_LEFT] = StringTrimRight($aSt[$iStRet][$AP_STI_LEFT], 1)

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
            And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
        ; Error: Expected end of line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseEnumDecls

Func __AuParse_ParseDecls(ByRef $lexer, ByRef $aSt, ByRef $tk, $iFlags)
    Local $iVar, $iValue, $i

    Local $iStRet = ""
    Local $iDecl

    Do
        ; Parsing new declaration/definition
        $iDecl = __AuAST_AddBranch($aSt, $AP_BR_DECL, $iFlags, -1, -1)
        $iStRet &= $iDecl & ","

        ; Parse Variable
        $iVar = __AuAST_AddBranchTok($aSt, $tk)
        If Not __AuParse_Accept($lexer, $tk, $AL_TOK_VARIABLE) _
                And Not __AuParse_Accept($lexer, $tk, $AL_TOK_WORD) Then
            ; Error: Expected a variable name.
            Return SetError(@ScriptLineNumber, 0, 0)
        EndIf
        $aSt[$iDecl][$AP_STI_LEFT] = $iVar

        ; PArse Value
        $tkPrev = $tk
        If __AuParse_Accept($lexer, $tk, $AL_TOK_OBRACK) Then ; Array Decl
            Local $err = __AuParse_ParseDeclArray($lexer, $aSt, $tk, $iDecl, $iVar, $tkPrev)
            If @error Then Return SetError(@error, 0, $err)
        Else
            $iValue = ""
            If __AuParse_Accept($lexer, $tk, $AL_TOK_OP, "=") Then ; Definition
                $iValue = __AuParse_ParseExpr($lexer, $aSt, $tk)
                If @error Then
                    ; Error: Error parsing expression
                    Return SetError(@error, 0, $iValue)
                EndIf
            EndIf

            $aSt[$iDecl][$AP_STI_RIGHT] = $iValue
        EndIf
    Until Not __AuParse_Accept($lexer, $tk, $AL_TOK_COMMA)

    $iStRet = StringTrimRight($iStRet, 1)

    If Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOL) _
            And Not __AuParse_Accept($lexer, $tk, $AL_TOK_EOF) Then
        ; Error: Expected end of line
        Return SetError(@ScriptLineNumber, 0, 0)
    EndIf

    Return $iStRet
EndFunc   ;==>__AuParse_ParseDecls

; The first [ of the declaration has been accepted.
Func __AuParse_ParseDeclArray(ByRef $lexer, ByRef $aSt, ByRef $tk, $iStRet, $iVar, $tkOBrack)
    Local $iLookup, $iLiteral

    ; Parse Lookup
    ; $iVariable = __AuAST_AddBranchTok($aSt, $tkVar)
    $iLookup = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $iVar, $tkOBrack)
    If @error Then
        ; Error: Error parsing lookup
        Return SetError(@error, 0, $iLookup)
    EndIf
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
        If @error Then
            ; Error: Error parsing expression
            Return SetError(@error, 0, $i)
        EndIf

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
            If @error Then
                ; Error parsing expression
                Return SetError(@error, 0, $iExpr)
            EndIf
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
    Do
        $tk = _Ault_LexerStep($lexer)
        If @error Then
            ConsoleWrite("Lexer Error: " & @error & @LF)
        EndIf
    Until $tk[$AL_TOKI_TYPE] <> $AL_TOK_COMMENT
EndFunc   ;==>__AuParse_GetTok

Func __AuParse_Accept(ByRef $lexer, ByRef $tk, $iTokType = Default, $sTokData = Default)
    If $iTokType <> Default And $tk[$AL_TOKI_TYPE] <> $iTokType Then Return False
    If $sTokData <> Default And $tk[$AL_TOKI_DATA] <> $sTokData Then Return False

    __AuParse_GetTok($lexer, $tk)
    Return True
EndFunc   ;==>__AuParse_Accept
