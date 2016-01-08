
$err = __AuParse_GetTok($lexer, $tk)
If @error Then Return SetError(@error, 0, $err)


Return SetError(@ScriptLineNumber, 0, _
        _Error_Create("Expected closing parenthesis after expression group.", _
            $aSt, $iStRet, $lexer, $tk)))


Func __AuParse_KwordToVarF($sKword)
    Switch $tkFirst[$AL_TOK_DATA]
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

    Return 0
EndFunc




$err = __AuParse_GetTok($lexer, $tk)
If @error Then Return SetError(@error, 0, $err)

Switch $tkFirst[$AL_TOK_TYPE]
    Case $AL_TOK_INCLUDE
        Return _Ault_ParseChild($lexer, $aSt, $tkFirst)

    Case $AL_TOK_PREPROC
        Return __AuAST_AddBranchTok($aSt, $tkFirst)

    Case $AL_TOK_VARIABLE
        $op = $tk
        $iLHS = __AuAST_AddBranchTok($aSt, $tkFirst)

        ; LHS might be an array
        If $tk[$AL_TOK_TYPE] = $AL_TOK_OBRACK Then ; Array
            $err = __AuParse_GetTok($lexer, $tk)
            If @error Then Return SetError(@error, 0, $err)

            $iLHS = __AuParse_ParseArrayLookup($lexer, $aSt, $tk, $iLHS, $op)
            If @error Then Return SetError(@error, 0, $iLHS)
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
                        $aSt, $iStRet, $lexer, $tk)))
        EndIf

        If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
            ; Error: Extra characters on line
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Extra characters on line.", _
                        $aSt, $iStRet, $lexer, $tk)))
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
                            $aSt, $iStRet, $lexer, $tk)))
            EndIf
        Else
            ; Error: Expected function call
            Return SetError(@ScriptLineNumber, 0, _
                    _Error_Create("Expected a function call.", _
                        $aSt, $iStRet, $lexer, $tk)))
        EndIf

    Case $AL_TOK_KEYWORD
        Switch $tkFirst[$AL_TOK_DATA]
            Case "Func"
                If Not $fTopLevel Then
                    ; Function definition not valid except at file level.
                    Return SetError(@ScriptLineNumber, 0, _
                            _Error_Create("Function definition not valid except at file level", _
                                $aSt, $iStRet, $lexer, $tk))
                EndIf

                $iStRet = __AuParse_ParseFuncDecl($lexer, $aSt, $tk)

            Case "ContinueCase"
                $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)
                $aSt[$iStRet][$AP_STI_TYPE] = $AP_BR_STMT

            Case "Return", "ExitLoop", "ContinueLoop", "Exit"
                $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)
                $aSt[$iStRet][$AP_STI_TYPE] = $AP_BR_STMT

                ; Statements can take an expression
                If $tk[$AL_TOKI_TYPE] <> $AL_TOK_EOL Then
                    $i = __AuParse_ParseExpr($lexer, $aSt, $tk)
                    If @error Then Return SetError(@error, 0, $i)

                    $aSt[$iStRet][$AP_STI_LEFT] = $i
                EndIf

            Case "Redim"
                $iStRet = __AuAST_AddBranchTok($aSt, $tkFirst)
                $aSt[$iStRet][$AP_STI_TYPE] = $AP_BR_STMT

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

                $iStRet = __AuAST_AddBranch($aSt, $AP_BR_DECL, $iFlags, "", "", $tkFirst)

                $aSt[$iStRet][$AP_STI_VALUE] = __AuParse_KwordToVarF($tkFirst[$AL_TOK_DATA])
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
                    EndSwitch

                    $err = __AuParse_GetTok($lexer, $tk)
                    If @error Then Return SetError(@error, 0, $err)
                WEnd

                ; Parse variable list
                If BitAND($i, $AP_VARF_ENUM) Then
                    $aSt[$iStRet][$AP_STI_TYPE] = $AP_BR_ENUMDEF ; Correct the type
                    $iStRet = __AuParse_ParseEnumDecls($lexer, $aSt, $tk, $i, $iStRet)
                Else
                    $iStRet = __AuParse_ParseDecls($lexer, $aSt, $tk, $i, $iStRet)
                EndIf
                If @error Then Return SEtError(@error, 0, $iStRet)

            Case Else
                Return SetError(@ScriptLineNumber, 0, _
                        _Error_Create("Keyword '" & $tk[$AL_TOKI_DATA] & "' not valid at the start of a line.", _
                            $aSt, $iStRet, $lexer, $tk))
        EndSwitch

    Case Else
        ; Unexpected Token
        Return SetError(@ScriptLineNumber, 0, _
                _Error_Create("Unexpected token starting a line '" & __AuTok_TypeToStr($tk[$AL_TOKI_TYPE]) & "'.", _
                    $aSt, $iStRet, $lexer, $tk))
EndSwitch



