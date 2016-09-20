
#include-once
#include "Parser.au3"
#include "Lexer.au3"


#cs
    Syntax Tree Usage:

    The syntax tree is a flat array of "branches". The branches can point to each other by referencing
    the child branches index. In a simplistic way, the following tree:

    1
    /   \
    2       3
    /   \
    4       5

    Results in an array with the following columns:

    Index   | Left  | Right
    1       | 2     | 3
    2       | 0     | 0
    3       | 4     | 5
    4       | 0     | 0
    5       | 0     | 0

    Reconstructing the tree from the table is usually done recursively, passing the tree and the index.

    Test(Tree, 1, 1)

    Func Test(Tree, Index, Depth)
    Print Index

    Test(Tree, Tree[Index].Left, Depth + 1)
    Test(Tree, Tree[Index].Right, Depth + 1)
    EndFunc

    Gives the output:

    > 1 2 3 4 5

    To avoid the need for nested arrays, the syntax trees here will allow comma seperated lists of
    indexes. So the new tree:

       1
     /   \
    2    3 --------- 4 --------- 5
    /     \                    /   \
    6      7                  8     9

    Produces the table:


    Index   | Left  | Right
    1       | 2     | 3,4,5
    2       | 0     | 0
    3       | 6     | 7
    4       | 0     | 0
    5       | 8     | 9
    6       | 0     | 0
    7       | 0     | 0
    8       | 0     | 0
    9       | 0     | 0

#ce


; Branch Types
Global Enum $AP_BR_NUMBER = $AL_TOK_NUMBER, _ ; Value
        $AP_BR_OP = $AL_TOK_OP, _ ; Name|Left|Right
        $AP_BR_ASSIGN = $AL_TOK_ASSIGN, _ ; Operator|LEft|Right
        $AP_BR_STR = $AL_TOK_STR, _ ; Value
        $AP_BR_VARIABLE = $AL_TOK_VARIABLE, _ ; Name
        $AP_BR_MACRO = $AL_TOK_MACRO, _ ; Name
        $AP_BR_PREPROC = $AL_TOK_PREPROC, _ ; Line
        $AP_BR_KEYWORD = $AL_TOK_KEYWORD, _ ; Keyword
        $AP_BR_WORD = $AL_TOK_WORD, _ ; Word
        $AP_BR_FUNC = $AL_TOK_FUNC, _ ; Function
        $AP_BR_FILE = $AL_TOK_INCLUDE, _ ; Include
        $AP_BR_ENUMDEF = 100, _ ; Flags|0|Declarations (NB: Enums only)
        $AP_BR_DECL, _ ; Flags|Variable|Value
        $AP_BR_FUNCDEF, _ ; Name|Parameters|Body
        $AP_BR_IF, _ ; Condition|Elseifs|Body
        $AP_BR_WHILE, _ ; 0|Condition|Body
        $AP_BR_DO, _ ; 0|Condition|Body
        $AP_BR_FOR, _ ; Variable|Start,End,StepOp,Step|Body
        $AP_BR_FORIN, _; Variable|Range|Body
        $AP_BR_SELECT, _ ; 0|0|Cases
        $AP_BR_SWITCH, _ ; 0|Condition|Cases
        $AP_BR_CASE, _ ; [Else]|Condition|Body
		$AP_BR_CASERANGE, _ ; 0|From|To
        $AP_BR_STMT, _ ; Name|Expression
        $AP_BR_REDIM, _ ; 0|Lookup|0
        $AP_BR_GROUP, _ ; 0|Expr
        $AP_BR_LOOKUP, _ ; 0|Variable|Indexes
        $AP_BR_FUNCCALL, _ ; 0|Function|Arguments
        $AP_BR_ARRAY, _ ; 0|Values
        $_AP_BR_COUNT

; Branch name strings
Global Const $_AP_BR_NAMES[$_AP_BR_COUNT - 100] = [ _
        "Variable Declarations", _
        "Variable Declaration", _
        "Function Definition", _
        "IF...THEN test", _
        "WHILE...WEND loop", _
        "DO...UNTIL loop", _
        "FOR...TO...NEXT loop", _
        "FOR...IN...NEXT loop", _
        "SELECT statement", _
        "SWITCH statement", _
        "CASE statement", _
        "CASE range condition", _
        "Statement", _
        "ReDim", _
        "Group ()", _
        "Array Lookup", _
        "Function Call", _
        "Array Literal"]

; Syntax tree index
Global Enum $AP_STI_BRTYPE = 0, _
        $AP_STI_VALUE, _
        $AP_STI_LEFT, _
        $AP_STI_RIGHT, _
        $AP_STI_TOK_ABS, _
        $AP_STI_TOK_LINE, _
        $AP_STI_TOK_COL, _
        $_AP_STI_COUNT


Global Enum _
        $AP_VARF_LOCAL = 1, _
        $AP_VARF_GLOBAL = 2, _
        $AP_VARF_DIM = 4, _
        $AP_VARF_STATIC = 8, _
        $AP_VARF_CONST = 16, _
        $AP_VARF_BYREF = 32, _
        $AP_VARF_ENUM = 64



Func __AuAST_BrTypeToStr($iBr)
    If $iBr < 100 Then
        Return __AuTok_TypeToStr($iBr)
    Else
        If $iBr >= $_AP_BR_COUNT + 100 Or $iBr < 0 Then Return "Branch???"
        Return $_AP_BR_NAMES[$iBr - 100]
    EndIf
EndFunc

Func _Ault_SerializeAST(ByRef Const $aSt, $dA = @TAB, $dB = @CRLF)
    Local $sOut = ""

    For $i = 1 To $aSt[0][0]
        For $j = 0 To UBound($aSt, 2)-1
            If $j = $AP_STI_VALUE Then
                $sOut &= StringToBinary($aSt[$i][$j]) & $dA
            Else
                $sOut &= $aSt[$i][$j] & $dA
            EndIf
        Next
        $sOut = StringTrimRight($sOut, 1) & $dB
    Next
    Return $sOut
EndFunc

Func _Ault_DeSerializeAST($sData, $dA = @TAB, $dB = @CRLF)
    Local $aLines = StringSplit($sData, $dB, 1)
    Local $aSt[$aLines[0]+1][$_AP_STI_COUNT]

    Local $aSplit
    For $i = 1 To $aLines[0]
        $aSplit = STringSplit($aLines[$i], $dA, 1)

        If $aSplit[0] < $_AP_STI_COUNT-1 Then ExitLoop

        For $j = 1 To $_AP_STI_COUNT
            If $j-1 = $AP_STI_VALUE Then
                $aSt[$i][$j-1] = BinaryToString($aSplit[$j])
            Else
                $aSt[$i][$j-1] = $aSplit[$j]
            EndIf
        Next
    Next

    $aSt[0][0] = $aLines[0]
    REturn $aSt
EndFunc

Func __AuAST_AddBranchTok(ByRef $aSt, ByRef Const $tok, $brLeft = "", $brRight = "")
    Return __AuAST_AddBranch($aSt, $tok[$AL_TOKI_TYPE], $tok[$AL_TOKI_DATA], $brLeft, $brRight, _
            $tok[$AL_TOKI_ABS], $tok[$AL_TOKI_LINE], $tok[$AL_TOKI_COL])
EndFunc

Func __AuAST_AddBranch(ByRef $aSt, $iType, $vValue, $brLeft = "", $brRight = "", $iAbs = "", $iLine = "", $iCol = "")
    If $aSt[0][0] >= UBound($aSt) - 1 Then
        ReDim $aSt[$aSt[0][0] + 100][$_AP_STI_COUNT]
    EndIf

    $aSt[0][0] += 1

    $aSt[$aSt[0][0]][$AP_STI_BRTYPE] = $iType
    $aSt[$aSt[0][0]][$AP_STI_VALUE] = $vValue
    $aSt[$aSt[0][0]][$AP_STI_LEFT] = $brLeft
    $aSt[$aSt[0][0]][$AP_STI_RIGHT] = $brRight
    $aSt[$aSt[0][0]][$AP_STI_TOK_ABS] = $iAbs
    $aSt[$aSt[0][0]][$AP_STI_TOK_LINE] = $iLine
    $aSt[$aSt[0][0]][$AP_STI_TOK_COL] = $iCol

    If IsArray($iAbs) Then ; Pass a token for position
        $aSt[$aSt[0][0]][$AP_STI_TOK_ABS] = $iAbs[$AL_TOKI_ABS]
        $aSt[$aSt[0][0]][$AP_STI_TOK_LINE] = $iAbs[$AL_TOKI_LINE]
        $aSt[$aSt[0][0]][$AP_STI_TOK_COL] = $iAbs[$AL_TOKI_COL]
    EndIf

    Return $aSt[0][0]
EndFunc   ;==>__AuAST_AddBranch
