

#include "ault\AST.au3"
#include "ault\Parser.au3"
#include "ault\ASTUtils.au3"
#include "ault\Deparser.au3"
#include "ault\ErrorHandler.au3"


Local $a = _Ault_ParseFile("ExampleScript.au3")
; Local $a = _Ault_ParseFile("ault\Deparser.au3")

If @error Then
    _Ault_ErrorBox($a)
Else
    _Ault_ViewAST($a)
    MsgBox(0, "Test", _Ault_Deparse($a))
EndIf

