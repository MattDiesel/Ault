
Local $sAutoItDir = StringRegExpReplace(@Autoitexe, '^(.+)\\[^\\]+$', "$1")

Local $__AL_AU3API = FileRead($sAutoItDir & "\SciTE\api\au3.api")

Global $__AL_KEYWORDS = StringRegExp($__AL_AU3API, "(\w+)\?4", 3)
Global $__AL_FUNCS = StringRegExp($__AL_AU3API, "(?:\n|\A)([^\_]\w+)\s\(", 3)
Global $__AL_MACROS = StringRegExp($__AL_AU3API, "(?:\n|\A)(@\w+)\?3", 3)

Local $aTypes[3] = ["KEYWORDS", "FUNCS", "MACROS"]
Local $aArrays[3] = [$__AL_KEYWORDS, $__AL_FUNCS, $__AL_MACROS]

Local $hFile, $a
For $n = 0 To 2
    $hFile = FileOpen("al_" & StringLower($aTypes[$n]) & ".au3", 2)
    $a = $aArrays[$n]

    FileWrite($hFile, "Global $__AL_" & $aTypes[$n] & "[" & UBound($a) & "] = [ _" & @CRLF)
    For $i = 0 To UBound($a) - 2
        FileWrite($hFile, @TAB & @TAB & '"' & $a[$i] & '", _' & @CRLF)
    Next
    FileWrite($hFile, @TAB & @TAB & '"' & $a[UBound($a) - 1] & '"]' & @CRLF)

    FileFlush($hFile)
    FileClose($hFile)
Next
