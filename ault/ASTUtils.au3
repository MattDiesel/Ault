

#include-once
#include <Array.au3>

#include "AST.au3"



Func _Ault_ViewAST(ByRef Const $aSt)
    Local $a = $aSt
    For $i = 1 To $a[0][0]
        $a[$i][0] = __AuAST_BrTypeToStr(Int($a[$i][0]))
    Next

    _ArrayDisplay($a, "AST View", "", 0, "|", "TYPE|VALUE|LEFT|RIGHT|ABS|LINE|COL")
EndFunc   ;==>_Ault_ViewAST
