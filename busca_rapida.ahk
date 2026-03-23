#Requires AutoHotkey v2
#SingleInstance Force
SendMode "Input"
SetWorkingDir(A_ScriptDir)

; ============================================================
; AUTO-EXECUÇÃO: FORÇAR UI ACCESS (PARA O TRABALHO)
; ============================================================
if !InStr(A_AhkPath, "_UIA.exe")
{
    uiaPath := RegExReplace(A_AhkPath, "i)\.exe$", "_UIA.exe")
    if FileExist(uiaPath)
    {
        Run('"' uiaPath '" /restart "' A_ScriptFullPath '"')
        ExitApp
    }
}

; ============================================================
; CONFIGURAÇÕES GERAIS E CAMINHOS
; ============================================================
iniFile := A_ScriptDir "\busca_preferencias.ini"
oneCommanderPath := "C:\01_Pasta Unificada MiniPC\14024140\gerenciador_arquivos\portatil_OneCommander3.96.0.0\OneCommander.exe"
PDFApp := "C:\Program Files\PDF24\pdf24-Reader.exe"

PastaPadrao := "C:\02_CNISLINHA 2"
PastaAno := "C:\Users\CLEUTONCESARLARA\INSS\Arquivo_aps14024140 - Digitalizacao\2026"
PastaGDrive := "G:\Meu Drive\inss-ccl-01-2026"
PastaMiniPC := "C:\01_Pasta Unificada MiniPC"

HideTip() => ToolTip()

; ============================================================
; MÓDULO 1 – LIMPAR CPF (ALT + S)
; ============================================================
!s::{
    if !ClipWait(1)
    {
        MsgBox("Área de transferência vazia.")
        return
    }
    clean := RegExReplace(A_Clipboard, "[\.\-]")
    onlyDigits := RegExReplace(clean, "\D")

    if (StrLen(onlyDigits) = 11)
    {
        A_Clipboard := onlyDigits
        ToolTip("CPF limpo: " onlyDigits)
    }
    else
        ToolTip("Conteúdo não parece CPF.")

    SetTimer(HideTip, -1200)
}

; ============================================================
; MÓDULO 2 – BUSCA INTELIGENTE (ALT + A)
; ============================================================
!a::{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")

    textoOriginal := ""
    if ClipWait(0.3)
        textoOriginal := A_Clipboard

    A_Clipboard := ClipSaved

    explorerChoice := IniRead(iniFile, "Preferencias", "Explorer", 1)
    pastaSelecionada := IniRead(iniFile, "Preferencias", "Pasta", 1)
    limparPref := IniRead(iniFile, "Preferencias", "Limpar", 1)

    BuscaGUI := Gui("+AlwaysOnTop", "Busca Inteligente")
    BuscaGUI.SetFont("s10")

    ; Campo editável
    BuscaGUI.Add("Text",, "Texto para busca:")
    inputBusca := BuscaGUI.Add("Edit", "w400", textoOriginal)

    ; Explorador
    BuscaGUI.Add("Text",, "Explorador:")
    c1 := explorerChoice=1 ? "Checked" : ""
    c2 := explorerChoice=2 ? "Checked" : ""
    c3 := explorerChoice=3 ? "Checked" : ""
    radExp1 := BuscaGUI.Add("Radio","Group " c1,"OneCommander")
    radExp2 := BuscaGUI.Add("Radio",c2,"Windows Explorer")
    radExp3 := BuscaGUI.Add("Radio",c3,"Windows Explorer (Abrir OC com ALT+O)")

    ; Pastas
    BuscaGUI.Add("Text",,"Pasta:")
    p1 := pastaSelecionada=1 ? "Checked":""
    p2 := pastaSelecionada=2 ? "Checked":""
    p3 := pastaSelecionada=3 ? "Checked":""
    p4 := pastaSelecionada=4 ? "Checked":""

    radPasta1 := BuscaGUI.Add("Radio","Group " p1, PastaPadrao)
    radPasta2 := BuscaGUI.Add("Radio",p2, PastaAno)
    radPasta3 := BuscaGUI.Add("Radio",p3, PastaGDrive)
    radPasta4 := BuscaGUI.Add("Radio",p4, PastaMiniPC)

    ; Configuração
    BuscaGUI.Add("Text",,"Configuração:")
    chkLimpar := BuscaGUI.Add("Checkbox", (limparPref=1 ? "Checked" : ""), "Remover pontos e traços")

    btn := BuscaGUI.Add("Button","Default w80","Executar")
    btn.OnEvent("Click", (*) => ExecutarBusca(BuscaGUI, radExp1, radExp2, radExp3, radPasta1, radPasta2, radPasta3, radPasta4, chkLimpar, inputBusca.Value))

    BuscaGUI.OnEvent("Escape", (*) => BuscaGUI.Destroy())
    BuscaGUI.OnEvent("Close", (*) => BuscaGUI.Destroy())

    inputBusca.Focus()
    BuscaGUI.Show()
}

ExecutarBusca(guiObj, radExp1, radExp2, radExp3, radPasta1, radPasta2, radPasta3, radPasta4, chkLimpar, textoOriginal){
    escolhaExplorador := radExp1.Value ? 1 : (radExp2.Value ? 2 : 3)

    if (radPasta1.Value)
    {
        escolhaPasta := 1
        caminho := PastaPadrao
    }
    else if (radPasta2.Value)
    {
        escolhaPasta := 2
        caminho := PastaAno
    }
    else if (radPasta3.Value)
    {
        escolhaPasta := 3
        caminho := PastaGDrive
    }
    else
    {
        escolhaPasta := 4
        caminho := PastaMiniPC
    }

    deveLimpar := chkLimpar.Value

    IniWrite(escolhaExplorador, iniFile, "Preferencias", "Explorer")
    IniWrite(escolhaPasta, iniFile, "Preferencias", "Pasta")
    IniWrite(deveLimpar, iniFile, "Preferencias", "Limpar")

    textoFinal := deveLimpar ? RegExReplace(textoOriginal, "[\.\-]") : textoOriginal

    if (escolhaExplorador = 1)
    {
        if FileExist(oneCommanderPath)
            Run('"' oneCommanderPath '" "' caminho '"')
        else
            MsgBox("OneCommander não encontrado.")
    }
    else if (escolhaExplorador = 2)
    {
        query := "search-ms:query=" textoFinal "&crumb=location:" caminho
        Run(query)
    }
    else if (escolhaExplorador = 3)
    {
        query := "search-ms:query=" textoFinal "&crumb=location:" caminho
        Run(query)
        ToolTip("Busca aberta no Explorer.`nSelecione um arquivo e pressione ALT+O para abrir no OneCommander.")
        SetTimer(HideTip, -5000)
    }

    guiObj.Destroy()
}

; ============================================================
; MÓDULO 3 – CONVERTER XHTML -> PDF (ALT + X)
; ============================================================
!x::{
    count := 0
    Loop Files, PastaPadrao "\*.xhtml"
    {
        old := A_LoopFileFullPath
        new := RegExReplace(old, "i)\.xhtml$", ".pdf")
        FileMove(old, new, 1)

        if FileExist(new)
        {
            Run('"' PDFApp '" "' new '"')
            count++
        }
    }
    TrayTip("Conversao", count ? count " arquivo(s) convertidos." : "Nenhum XHTML encontrado.", 3)
}

; ============================================================
; MÓDULO 4 – GERAR NOME PADRÃO (ALT + H)
; ============================================================
!h::
{
    texto := A_Clipboard

    if !RegExMatch(texto, "\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b", &cpf)
    {
        MsgBox("CPF não encontrado.")
        return
    }

    cpfLimpo := RegExReplace(cpf[0], "[^0-9]")
    RegExMatch(texto, "\b[A-Za-zÀ-ÿ]+\b", &nome)

    if nome
    {
        nomeFormatado := StrLower(nome[0])
        A_Clipboard := nomeFormatado "_" cpfLimpo
    }
    else
    {
        A_Clipboard := cpfLimpo
    }
}

; ============================================================
; MÓDULO 5 – COPIAR NOME DO ARQUIVO (F1)
; ============================================================
F1::{
    titulo := WinGetTitle("A")
    A_Clipboard := RegExReplace(titulo, "( - | — ).*", "")
    Send("!{Space}")
    Sleep(300)
    Send("^v")
}

; ============================================================
; MÓDULO 6 – BUSCAR PDF NA PASTA CNIS (ALT + D)
; ============================================================
!d::{
    if !ClipWait(1)
        return
    texto := RegExReplace(A_Clipboard, "[\.\-]")
    resultados := []
    Loop Files, PastaPadrao "\*" texto "*.pdf", "R"
    {
        resultados.Push(A_LoopFileFullPath)
        if (resultados.Length > 10)
            break
    }
    if (resultados.Length = 0)
    {
        MsgBox("Nenhum PDF encontrado.")
    }
    else if (resultados.Length > 10)
    {
        Run("search-ms:query=" texto "&crumb=location:" PastaPadrao)
    }
    else
    {
        for arquivo in resultados
        {
            Run(arquivo)
            Sleep(150)
        }
        ToolTip(resultados.Length " PDF(s) aberto(s).")
        SetTimer(HideTip, -1500)
    }
}

; ============================================================
; MÓDULO 7 – ABRIR NO ONECOMMANDER A PARTIR DA BUSCA (ALT + O)
; ============================================================
!o::{
    ClipSaved := ClipboardAll()
    A_Clipboard := ""
    Send("^c")

    if !ClipWait(1)
    {
        A_Clipboard := ClipSaved
        ToolTip("Nenhum arquivo copiado. Selecione um arquivo primeiro.")
        SetTimer(HideTip, -2000)
        return
    }

    caminhoArquivo := A_Clipboard
    A_Clipboard := ClipSaved

    ; Pega o primeiro arquivo se houver múltiplos
    if InStr(caminhoArquivo, "`n")
        caminhoArquivo := StrSplit(caminhoArquivo, "`n", "`r")[1]

    ; Remove aspas se houver
    caminhoArquivo := StrReplace(caminhoArquivo, '"', '')

    if !FileExist(caminhoArquivo)
    {
        ToolTip("Caminho não encontrado ou inválido: " caminhoArquivo)
        SetTimer(HideTip, -2000)
        return
    }

    SplitPath(caminhoArquivo, &nome, &dir)

    ; Verifica se o arquivo e a pasta existem e, se sim, abre no OneCommander
    if FileExist(oneCommanderPath)
    {
        ; Passar o arquivo ao invés do diretório pode abrir focado no OneCommander dependendo de configurações
        Run('"' oneCommanderPath '" "' caminhoArquivo '"')
        ToolTip("Aberto no OneCommander.")
        SetTimer(HideTip, -2000)
    }
    else
    {
        MsgBox("OneCommander não encontrado em:`n" oneCommanderPath)
    }
}