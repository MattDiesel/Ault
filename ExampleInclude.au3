
#include-once

Func _MyFunction(ByRef $a, $b = 12)
    Local $ret = 0

    If $a = 1 Then $ret += 12

    If Not Mod($b, 2) Then
        $ret = $ret * 2
    EndIf

    Return $ret
EndFunc
