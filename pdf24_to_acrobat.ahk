#Requires AutoHotkey v2.0

; Configurar correspondência de título de janela para conter o texto ("PDF24")
SetTitleMatchMode 2

; Criar um grupo para as janelas do PDF24 (Reader ou Creator) para garantir que o atalho funcione
GroupAdd "PDF24Group", "ahk_exe pdf24-Reader.exe"
GroupAdd "PDF24Group", "ahk_exe pdf24.exe"
GroupAdd "PDF24Group", "PDF24"

#HotIf WinActive("ahk_group PDF24Group")
F12::
{
    ; Obter o título da janela ativa do PDF24
    winTitle := WinGetTitle("A")

    ; O título geralmente é algo como "nome_do_arquivo.pdf - PDF24 Reader"
    ; Vamos extrair apenas o nome do arquivo, removendo tudo a partir de " - PDF24"
    fileName := winTitle
    pos := InStr(winTitle, " - PDF24")
    if (pos > 0) {
        fileName := SubStr(winTitle, 1, pos - 1)
    }

    ; Guarda o conteúdo atual da área de transferência
    ClipSaved := ClipboardAll()
    A_Clipboard := ""

    ; Dar um pequeno delay para garantir que o AHK possa enviar comandos confiavelmente
    Sleep 100

    ; Enviar Ctrl+S para abrir a janela "Salvar Como"
    ; No PDF24, para a aba atual ser salva, o comando mais padrão é o Ctrl+S.
    Send "^s"

    ; Aguardar até que a janela "Salvar como" (Save As) apareça
    ; ahk_class #32770 é a classe padrão de janelas de diálogo do Windows
    if !WinWaitActive("ahk_class #32770", , 3) {
        MsgBox("A janela de 'Salvar Como' não apareceu. Certifique-se de que Ctrl+S abre a janela para salvar o arquivo no PDF24.", "Erro de Automação", "Iconi")
        return
    }

    ; Dar um pequeno delay para a janela focar completamente
    Sleep 200

    ; Focar na barra de endereço usando Alt+D (atalho padrão do Windows)
    Send "!d"
    Sleep 100

    ; Copiar o caminho da pasta
    Send "^c"

    ; Aguardar o clipboard ser preenchido com o caminho da pasta
    if !ClipWait(2) {
        Send "{Esc}" ; Fechar a janela se falhar
        MsgBox("Falha ao copiar o caminho da pasta.", "Erro", "Iconi")
        return
    }

    folderPath := A_Clipboard

    ; Fechar a janela de Salvar Como pressionando Esc
    Send "{Esc}"

    ; Montar o caminho completo
    ; Evitar barras duplas se o folderPath terminar com barra (ex: diretório raiz C:\)
    if (SubStr(folderPath, -1) == "\") {
        fullPath := folderPath . fileName
    } else {
        fullPath := folderPath . "\" . fileName
    }

    ; Verificar se o arquivo realmente existe para termos certeza
    if (!FileExist(fullPath)) {
        MsgBox("Não foi possível validar o caminho do arquivo.`n`nCaminho montado: " . fullPath, "Aviso", "Iconi")
        return
    }

    ; Colocar o caminho completo na área de transferência
    A_Clipboard := fullPath

    ; Mostrar um pequeno balão informando o sucesso
    ToolTip("Caminho copiado para a área de transferência!`n" . fullPath)
    SetTimer () => ToolTip(), -3000 ; Remove o balão após 3 segundos
}
#HotIf
