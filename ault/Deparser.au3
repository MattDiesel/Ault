
#include "AST.au3"



Func _Ault_Deparse(ByRef Const $aSt, $iBr = 1, $sIndent = "")
	Switch $aSt[$iBr][$AP_STI_BRTYPE]

		Case $AL_TOK_EOL
			Return @CRLF

		Case $AP_BR_FILE
			$sOut = ""
			$aSplit = StringSplit($aSt[$iBr][$AP_STI_LEFT], ",")
			For $i = 1 To $aSplit[0]
				$sOut &= _Ault_Deparse($aSt, $aSplit[$i]) & @CRLF
			Next
			Return $sOut

		Case $AP_BR_NUMBER, $AP_BR_STR, $AP_BR_VARIABLE, $AP_BR_MACRO, $AP_BR_PREPROC, $AP_BR_KEYWORD, $AP_BR_FUNC, $AP_BR_WORD
			Return $aSt[$iBr][$AP_STI_VALUE]

		Case $AP_BR_OP
			If $aSt[$iBr][$AP_STI_VALUE] = "?" Then
				; Ternary Operator
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")

				Return _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & " ? " & _Ault_Deparse($aSt, $aSplit[1]) & " : " & _Ault_Deparse($aSt, $aSplit[2])

			ElseIf $aSt[$iBr][$AP_STI_RIGHT] = 0 Then
				; Unary Operator
				If $aSt[$iBr][$AP_STI_VALUE] = "Not" Then
					Return "Not " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT])
				Else
					Return $aSt[$iBr][$AP_STI_VALUE] & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT])
				EndIf
			Else
				If $aSt[$iBr][$AP_STI_VALUE] = "." Then ; Don't add space around access operator
					Return _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & $aSt[$iBr][$AP_STI_VALUE] & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_RIGHT])
				Else
					Return _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & " " & $aSt[$iBr][$AP_STI_VALUE] & " " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_RIGHT])
				EndIf
			EndIf

		Case $AP_BR_ASSIGN
			Return _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & " " & $aSt[$iBr][$AP_STI_VALUE] & " " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_RIGHT])

		Case $AP_BR_GROUP
			Return "(" & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & ")"

		Case $AP_BR_FUNCCALL
			$sOut = _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & "("

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= _Ault_Deparse($aSt, $aSplit[$i]) & ", "
				Next
				$sOut = StringTrimRight($sOut, 2)
			EndIf
			Return $sOut & ")"

		Case $AP_BR_FUNCDEF
			$sOut = "Func " & $aSt[$iBr][$AP_STI_VALUE] & "("

			If $aSt[$iBr][$AP_STI_LEFT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_LEFT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= _Ault_Deparse($aSt, $aSplit[$i]) & ", "
				Next
				$sOut = StringTrimRight($sOut, 2)
			EndIf
			$sOut = $sOut & ")" & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit[$i], $sIndent & "    ") & @CRLF
				Next
			EndIf
			$sOut &= $sIndent & "EndFunc"

			Return $sOut


		Case $AP_BR_ENUMDEF
			Local $aFlags[6] = ["Local", "Global", "Dim", "Static", "Const", "Byref"]

			$sOut = ""
			$p = 1
			For $i = 0 To 5
				If BitAND($aSt[$iBr][$AP_STI_VALUE], $p) Then
					$sOut &= $aFlags[$i] & " "
				EndIf
				$p *= 2
			Next

			$sOut &= "Enum "

			; Check Step
			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_LEFT], ",")
				$sOut &= "Step " & $aSplit[1] & $aSplit[2] & " "
			EndIf

			$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
			For $i = 1 To $aSplit[0]
				$sOut &= _Ault_Deparse($aSt, $aSplit[$i]) & ", "
			Next
			$sOut = StringTrimRight($sOut, 2)

			Return $sOut


		Case $AP_BR_DECL
			Local $aFlags[6] = ["Local", "Global", "Dim", "Static", "Const", "Byref"]

			$sOut = ""

			If Not BitAND($aSt[$iBr][$AP_STI_VALUE], $AP_VARF_ENUM) Then
				$p = 1
				For $i = 0 To 5
					If BitAND($aSt[$iBr][$AP_STI_VALUE], $p) Then
						$sOut &= $aFlags[$i] & " "
					EndIf
					$p *= 2
				Next
			EndIf

			$sOut &= _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT])

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$sOut &= " = " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_RIGHT])
			EndIf

			Return $sOut

		Case $AP_BR_IF
			$sOut = "If " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_VALUE]) & " Then" & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit[$i], $sIndent & "    ") & @CRLF
				Next
			EndIf

			; Elseifs
			If $aSt[$iBr][$AP_STI_LEFT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_LEFT], ",")

				For $i = 1 To $aSplit[0]
					If $aSt[$aSplit[$i]][$AP_STI_VALUE] = "" Then
						; Else Statement
						$sOut &= $sIndent & "Else" & @CRLF

						If $aSt[$aSplit[$i]][$AP_STI_RIGHT] <> "" Then
							$aSplit2 = StringSplit($aSt[$aSplit[$i]][$AP_STI_RIGHT], ",")
							For $j = 1 To $aSplit2[0]
								$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit2[$j], $sIndent & "    ") & @CRLF
							Next
						EndIf
					Else
						; ElseIf Statement
						$sOut &= $sIndent & "ElseIf " & _Ault_Deparse($aSt, $aSt[$aSplit[$i]][$AP_STI_VALUE]) & " Then" & @CRLF

						If $aSt[$aSplit[$i]][$AP_STI_RIGHT] <> "" Then
							$aSplit2 = StringSplit($aSt[$aSplit[$i]][$AP_STI_RIGHT], ",")
							For $j = 1 To $aSplit2[0]
								$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit2[$j], $sIndent & "    ") & @CRLF
							Next
						EndIf
					EndIf
				Next
			EndIf

			$sOut &= $sIndent & "EndIf"

			Return $sOut

		Case $AP_BR_WHILE
			$sOut = "While " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit[$i], $sIndent & "    ") & @CRLF
				Next
			EndIf
			$sOut &= $sIndent & "WEnd"

			Return $sOut

		Case $AP_BR_FOR
			$aSplit = StringSplit($aSt[$iBr][$AP_STI_LEFT], ",")
			$sOut = "For " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_VALUE]) & " = " & _Ault_Deparse($aSt, $aSplit[1]) & " To " & _Ault_Deparse($aSt, $aSplit[2])

			If $aSplit[0] > 2 Then
				$sOut &= " Step " & $aSplit[3] & $aSplit[4]
			EndIf
			$sOut &= @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit[$i], $sIndent & "    ") & @CRLF
				Next
			EndIf
			$sOut &= $sIndent & "Next"
			Return $sOut

		Case $AP_BR_FORIN
			$sOut = "For " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_VALUE]) & " In " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit[$i], $sIndent & "    ") & @CRLF
				Next
			EndIf
			$sOut &= $sIndent & "Next"
			$sOut &= $sIndent & "Next"
			Return $sOut


		Case $AP_BR_DO
			$sOut = "Do" & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    " & _Ault_Deparse($aSt, $aSplit[$i], $sIndent & "    ") & @CRLF
				Next
			EndIf
			$sOut &= $sIndent & "Until " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT])

			Return $sOut

		Case $AP_BR_SELECT
			$sOut = "Select" & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    Case "

					If $aSt[$aSplit[$i]][$AP_STI_VALUE] = "Else" Then
						$sOut &= "Else" & @CRLF
					Else
						$sOut &= _Ault_Deparse($aSt, $aSt[$aSplit[$i]][$AP_STI_LEFT]) & @CRLF
					EndIf

					If $aSt[$aSplit[$i]][$AP_STI_RIGHT] <> "" Then
						$aSplit2 = StringSplit($aSt[$aSplit[$i]][$AP_STI_RIGHT], ",")

						For $j = 1 To $aSplit2[0]
							$sOut &= $sIndent & "        " & _Ault_Deparse($aSt, $aSplit2[$j], $sIndent & "        ") & @CRLF
						Next
					EndIf
				Next
			EndIf
			$sOut &= $sIndent & "EndSelect"

			Return $sOut

		Case $AP_BR_SWITCH
			$sOut = "Switch " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & @CRLF

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= $sIndent & "    Case "

					If $aSt[$aSplit[$i]][$AP_STI_VALUE] = "Else" Then
						$sOut &= "Else" & @CRLF
					Else
						$aSplit2 = StringSplit($aSt[$aSplit[$i]][$AP_STI_LEFT], ",")
						For $j = 1 To $aSplit2[0]
							$sOut &= _Ault_Deparse($aSt, $aSplit2[$j]) & ", "
						Next

						$sOut = StringTrimRight($sOut, 2) & @CRLF
					EndIf

					If $aSt[$aSplit[$i]][$AP_STI_RIGHT] <> "" Then
						$aSplit2 = StringSplit($aSt[$aSplit[$i]][$AP_STI_RIGHT], ",")

						For $j = 1 To $aSplit2[0]
							$sOut &= $sIndent & "        " & _Ault_Deparse($aSt, $aSplit2[$j], $sIndent & "        ") & @CRLF
						Next
					EndIf
				Next
			EndIf
			$sOut &= $sIndent & "EndSwitch"

			Return $sOut
		Case $AP_BR_CASERANGE
			Return _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & " To " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_RIGHT])

		Case $AP_BR_LOOKUP
			$sOut = _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT]) & "["

			If $aSt[$iBr][$AP_STI_RIGHT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_RIGHT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= _Ault_Deparse($aSt, $aSplit[$i]) & "]["
				Next
				$sOut = StringTrimRight($sOut, 1)
			Else
				$sOut &= "]"
			EndIf

			Return $sOut

		Case $AP_BR_ARRAY
			$sOut = "["
			If $aSt[$iBr][$AP_STI_LEFT] <> "" Then
				$aSplit = StringSplit($aSt[$iBr][$AP_STI_LEFT], ",")
				For $i = 1 To $aSplit[0]
					$sOut &= _Ault_Deparse($aSt, $aSplit[$i]) & ", "
				Next
				$sOut = StringTrimRight($sOut, 2) & "]"
			Else
				$sOut &= "]"
			EndIf

			Return $sOut

		Case $AP_BR_STMT
			If $aSt[$iBr][$AP_STI_LEFT] = "" Then
				Return $aSt[$iBr][$AP_STI_VALUE]
			Else
				Return $aSt[$iBr][$AP_STI_VALUE] & " " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT])
			EndIf

		Case $AP_BR_REDIM
			Return "ReDim " & _Ault_Deparse($aSt, $aSt[$iBr][$AP_STI_LEFT])

	EndSwitch

	Return "???"
EndFunc   ;==>_Ault_Deparse
