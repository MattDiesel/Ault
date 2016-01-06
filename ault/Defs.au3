
#include-once

#include <Array.au3>

#include "al_keywords.au3"
#include "al_funcs.au3"
#include "al_macros.au3"
#include "Token.au3"


Func _Ault_IsKeyword($s)
    Return _ArrayBinarySearch($__AL_KEYWORDS, $s) >= 0
EndFunc   ;==>_Ault_IsKeyword

Func _Ault_IsStandardFunc($s)
    Return _ArrayBinarySearch($__AL_FUNCS, $s) >= 0
EndFunc   ;==>_Ault_IsStandardFunc

Func _Ault_IsMacro($s)
    Return _ArrayBinarySearch($__AL_MACROS, $s) >= 0
EndFunc   ;==>_Ault_IsMacro
