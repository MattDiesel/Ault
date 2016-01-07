
#include <WinAPIShPath.au3>
#include <StringConstants.au3>
#include <Array.au3>


;Global Const $AUTOIT_REGISTRYKEY = "HKLM\SOFTWARE\AutoIt v3\AutoIt"
Global Const $AUTOIT_REGISTRYKEY = "HKLM\SOFTWARE\Wow6432Node\AutoIt v3\AutoIt"
Global Const $AUTOIT_EXTENSIONKEY = "HKCR\.au3"



Func _AutoIt_IsInstalled($fBeta = False)
    _AutoIt_GetInstallDir($fBeta)
    Return Not @error
EndFunc   ;==>_AutoIt_IsInstalled

Func _AutoIt_Version($fBeta = False)
    Return FileGetVersion(_AutoIt_GetAutoItExe($fBeta))
EndFunc   ;==>_AutoIt_Version

Func _AutoIt_IsBetaActive()
    Local $sFileType = RegRead($AUTOIT_EXTENSIONKEY, "")
    If @error Then Return SetError(1, 0, False) ; AutoIt not installed?

    If $sFileType = "AutoIt3Script" Then
        Return False
    ElseIf $sFileType = "AutoIt3ScriptBeta" Then
        Return True
    EndIf

    Return SetError(2, 0, False) ; au3 files associated with something else.
EndFunc   ;==>_AutoIt_IsBetaActive

Func _AutoIt_FileTypeHandlerKey()
    Local $sFileType = RegRead($AUTOIT_EXTENSIONKEY, "")
    If @error Then Return SetError(1, 0, False) ; AutoIt not installed?

    Return "HKCR\" & $sFileType
EndFunc   ;==>_AutoIt_FileTypeHandlerKey

Func _AutoIt_IsX64Active()
    Local $sFileTypeHandlerKey = _AutoIt_FileTypeHandlerKey()
    If @error Then Return SetError(@error, @extended, "")

    Local $sCommand = RegRead($sFileTypeHandlerKey & "\Shell\Run\Command", "")
    If @error Then Return SetError(1, 0, False)

    Local $sCommand32 = RegRead($sFileTypeHandlerKey & "\Shell\RunX86\Command", "")
    If @error Then Return False

    Local $sCommand64 = RegRead($sFileTypeHandlerKey & "\Shell\RunX64\Command", "")
    If @error Then Return False

    If $sCommand = $sCommand32 Then
        Return False
    ElseIf $sCommand = $sCommand64 Then
        Return True
    EndIf

    Return SetError(2, 0, False)
EndFunc   ;==>_AutoIt_IsX64Active

Func _AutoIt_IsSciTEInstalled($fBeta = Default)
    _AutoIt_GetSciTEDir($fBeta)
    Return Not @error
EndFunc   ;==>_AutoIt_IsSciTEInstalled

Func _AutoIt_DefaultAction()
    Local $sFileTypeHandlerKey = _AutoIt_FileTypeHandlerKey()
    If @error Then Return SetError(@error, @extended, "")

    Local $sRet = RegRead(_AutoIt_FileTypeHandlerKey() & "\Shell", "")
    If @error Then Return SetError(1, 0, "")

    Return $sRet
EndFunc   ;==>_AutoIt_DefaultAction

Func _AutoIt_GetSciTEDir($fBeta = Default)
    Local $sSciTEDir = _WinAPI_PathAppend(_AutoIt_GetInstallDir(False), "SciTE")

    If Not FileExists($sSciTEDir) Or Not _WinAPI_PathIsDirectory($sSciTEDir) Then Return SetError(1, 0, "")

    Return $sSciTEDir
EndFunc   ;==>_AutoIt_GetSciTEDir

Func _AutoIt_GetInstallDir($fBeta = Default)
    If $fBeta = Default Then $fBeta = _AutoIt_IsBetaActive()

    Local $sInstallDir = RegRead($AUTOIT_REGISTRYKEY, "InstallDir")
    If @error Then Return SetError(1, 0, "") ; AutoIt not installed

    If $fBeta Then
        $sInstallDir = _WinAPI_PathAppend($sInstallDir, "Beta")

        If Not FileExists($sInstallDir) Then Return SetError(1, 0, "") ; Beta Directory does not exist
    EndIf

    Return $sInstallDir
EndFunc   ;==>_AutoIt_GetInstallDir

Func _AutoIt_GetAutoItExe($fBeta = Default, $fX64 = Default)
    If $fX64 = Default Then $fX64 = _AutoIt_IsX64Active()

    Return _WinAPI_PathAppend(_AutoIt_GetInstallDir($fBeta), "AutoIt3" & ($fX64 ? "_x64" : "") & ".exe")
EndFunc   ;==>_AutoIt_GetAutoItExe

Func _AutoIt_GetIncludeDirs($fBeta = Default)
    Local $aRet[3] = [1, _WinAPI_PathAppend(_AutoIt_GetInstallDir($fBeta), "Include"), ""]

    Local $sDirs = RegRead($AUTOIT_REGISTRYKEY, "Include")
    If Not @error Then
        Local $a = StringSplit($sDirs, ";")

        ReDim $aRet[3 + $a[0]]
        $aRet[0] = 1 + $a[0]

        For $i = 1 To $a[0]
            $aRet[$i + 1] = StringStripWS($a[$i], $STR_STRIPLEADING + $STR_STRIPTRAILING)
        Next
    EndIf

    Return $aRet
EndFunc   ;==>_AutoIt_GetIncludeDirs

Func _AutoIt_ResolveInclude($sScriptPath, $sFileName, $fLocal = False, $fBeta = Default)
    Local Static $aDirs = _AutoIt_GetIncludeDirs($fBeta)

    ; Add script directory
    $aDirs[0] = UBound($aDirs) -1
    $aDirs[$aDirs[0]] = _WinAPI_PathRemoveFileSpec($sScriptPath)

    Local $sPath
    If $fLocal Then
        For $i = $aDirs[0] To 1 Step -1
            $sPath = _WinAPI_PathCanonicalize(_WinAPI_PathAppend($aDirs[$i], $sFileName))

            If FileExists($sPath) And Not _WinAPI_PathIsDirectory($sPath) Then Return $sPath
        Next
    Else
        For $i = 1 To $aDirs[0]
            $sPath = _WinAPI_PathCanonicalize(_WinAPI_PathAppend($aDirs[$i], $sFileName))

            If FileExists($sPath) And Not _WinAPI_PathIsDirectory($sPath) Then Return $sPath
        Next
    EndIf

    Return SetError(1, 0, "")
EndFunc   ;==>_AutoIt_ResolveInclude
