#Requires AutoHotkey v2.0

; Configurar correspondência de título de janela para conter o texto ("PDF24")
SetTitleMatchMode 2

; Função para extrair o caminho do PDF da linha de comando do processo do PDF24
GetPDFPathFromProcess(pid) {
    try {
        wmi := ComObject("WbemScripting.SWbemLocator").ConnectServer()
        query := wmi.ExecQuery("Select * from Win32_Process where ProcessId = " . pid)

        for process in query {
            cmdLine := process.CommandLine

            ; A linha de comando geralmente é algo como:
            ; "C:\Program Files\PDF24\pdf24-Reader.exe" "C:\Caminho\Para\O\Arquivo.pdf"
            ; Vamos usar Expressão Regular para extrair o caminho do arquivo entre aspas, ignorando o executável.

            if RegExMatch(cmdLine, '"[^"]+"\s+"([^"]+\.pdf)"', &match) {
                return match[1]
            }
            ; Alternativamente, se a linha de comando não tiver aspas em volta do executável ou algo similar
            if RegExMatch(cmdLine, 'i)\s"([^"]+\.pdf)"', &match) {
                return match[1]
            }
        }
    } catch {
        return ""
    }
    return ""
}

#HotIf WinActive("PDF24")
F12::
{
    ; Obter o PID da janela ativa do PDF24
    activePid := WinGetPID("A")

    ; Extrair o caminho do arquivo
    filePath := GetPDFPathFromProcess(activePid)

    ; Remover eventuais aspas duplas adicionais do caminho
    filePath := StrReplace(filePath, '"', "")

    if (filePath == "" or !FileExist(filePath)) {
        MsgBox("Não foi possível identificar o caminho do arquivo PDF aberto automaticamente.`n`nCaminho obtido: " . filePath, "Aviso", "Iconi")
        return
    }

    ; ATENÇÃO: Configure o caminho do executável do seu Acrobat Reader ou Acrobat DC aqui.
    ; Exemplo: acrobatExecutablePath := "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
    acrobatExecutablePath := ""

    if (acrobatExecutablePath != "") {
        Run('"' . acrobatExecutablePath . '" "' . filePath . '"')
    } else {
        MsgBox("Por favor, edite o script e configure a variável 'acrobatExecutablePath' com o caminho do Acrobat Reader.", "Configuração Necessária", "Iconi")
    }
}
#HotIf
