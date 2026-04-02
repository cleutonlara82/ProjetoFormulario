#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetWorkingDir(A_ScriptDir)

; ============================================================
; AUTO-EXECUÇÃO: FORÇAR UI ACCESS
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
; CONFIGURAÇÕES E GLOBAIS
; ============================================================
Global ArquivoINI := A_ScriptDir "\config_ferramentas.ini"
Global PDFApp := "C:\Program Files\PDF24\pdf24-Reader.exe"
Global Painel := ""
Global edtBusca, radOC, radWE, txtCaminhoOC
Global chkP1, chkP2, chkP3, chkP4, chkP5, edtP5
Global btnColeta

; --- VARIÁVEIS DA COLETA E HISTÓRICO ---
Global ColetaAtiva := false
Global ParagrafosLivres := []
Global HistoricoMemoria := []
Global RevLst, RevEdt, RevGuiObj

if !FileExist(ArquivoINI) {
    IniWrite("C:\01_Pasta Unificada MiniPC\14024140\gerenciador_arquivos\portatil_OneCommander3.96.0.0\OneCommander.exe", ArquivoINI, "Configuracoes", "OneCommanderPath")
    IniWrite("1", ArquivoINI, "Configuracoes", "ExploradorPadrao")
    IniWrite("1", ArquivoINI, "Configuracoes", "ModoColeta")
    IniWrite(A_MyDocuments, ArquivoINI, "Configuracoes", "PastaSalvarTxt")
    IniWrite("notepad.exe", ArquivoINI, "Configuracoes", "AppSalvarTxt")
    IniWrite("C:\02_CNISLINHA 2", ArquivoINI, "PastasPadrao", "Pasta1")
    IniWrite("C:\Users\CLEUTONCESARLARA\INSS\Arquivo_aps14024140 - Digitalizacao\2026", ArquivoINI, "PastasPadrao", "Pasta2")
    IniWrite("G:\Meu Drive\inss-ccl-01-2026", ArquivoINI, "PastasPadrao", "Pasta3")
    IniWrite("C:\01_Pasta Unificada MiniPC", ArquivoINI, "PastasPadrao", "Pasta4")
    IniWrite("0", ArquivoINI, "SelecaoPastas", "Chk1")
    IniWrite("0", ArquivoINI, "SelecaoPastas", "Chk2")
    IniWrite("0", ArquivoINI, "SelecaoPastas", "Chk3")
    IniWrite("0", ArquivoINI, "SelecaoPastas", "Chk4")
    IniWrite("0", ArquivoINI, "SelecaoPastas", "Chk5")
    IniWrite("", ArquivoINI, "PastasCustom", "Caminho")
}

Global oneCommanderPath := IniRead(ArquivoINI, "Configuracoes", "OneCommanderPath", "")
Global PastaSalvarPadrao := IniRead(ArquivoINI, "Configuracoes", "PastaSalvarTxt", A_MyDocuments)
Global AppSalvarPadrao := IniRead(ArquivoINI, "Configuracoes", "AppSalvarTxt", "notepad.exe")

HideTip() => ToolTip()

; ============================================================
; TECLA MESTRA (F12) - PAINEL CENTRAL
; ============================================================
F12::{
    if WinExist("Central INSS") {
        Painel.Destroy()
    }
    CriarPainelCentral()
}

; ============================================================
; INTERFACE UNIFICADA
; ============================================================
CriarPainelCentral() {
    Global Painel, edtBusca, radOC, radWE, txtCaminhoOC, oneCommanderPath
    Global chkP1, chkP2, chkP3, chkP4, chkP5, edtP5, btnColeta, HistoricoMemoria

    Painel := Gui("-MaximizeBox", "Central INSS")
    Painel.BackColor := "FFFFFF"
    Painel.MarginX := 20
    Painel.MarginY := 20

    ; Produtividade: Fechar a janela ao pressionar Esc
    Painel.OnEvent("Escape", (*) => Painel.Destroy())

    Painel.SetFont("s13 w800 c003366", "Segoe UI")
    Painel.Add("Text", "w400 Center", "CENTRAL DE PRODUTIVIDADE")
    Painel.Add("Text", "w400 h2 0x10 y+10")

    ; --- MÓDULO VISUAL: COLETA ---
    Painel.SetFont("s10 w700 c008000", "Segoe UI")
    Painel.Add("Text", "w400 y+10", "⛏️ MODO COLETA DE TEXTOS")

    Painel.SetFont("s10 w700 cBlack", "Segoe UI")
    btnColeta := Painel.Add("Button", "w400 h45 x20 y+5 BackgroundSilver", ColetaAtiva ? "🛑 PAUSAR E GERAR (F9)" : "▶️ INICIAR CAPTURA (F9)")
    btnColeta.OnEvent("Click", (*) => AlternarModoColeta())

    ; --- MÓDULO: HISTÓRICO ---
    if (HistoricoMemoria.Length > 0) {
        Painel.SetFont("s9 w700 c990000", "Segoe UI")
        Painel.Add("Text", "w400 y+15", "📚 HISTÓRICO RECENTE (RESTAURAR)")
        Painel.SetFont("s9 w400 cBlack", "Segoe UI")

        opcoesHist := []
        Loop HistoricoMemoria.Length {
            opcoesHist.Push("Coleta " A_Index " (" HistoricoMemoria[A_Index].Length " itens salvos)")
        }

        cbHist := Painel.Add("ComboBox", "w280 x20 y+5 Choose1 ReadOnly", opcoesHist)
        btnRest := Painel.Add("Button", "w110 x+10 yp-1 h25", "Restaurar")
        btnRest.OnEvent("Click", (*) => RestauraHistorico(cbHist.Value))
    }

    Painel.Add("Text", "w400 h2 0x10 y+15 x20")

    ; --- TEXTO E ÁREA DE TRANSFERÊNCIA ---
    Painel.SetFont("s10 w700 c00509E", "Segoe UI")
    Painel.Add("Text", "w400 y+15", "📋 TEXTO E ÁREA DE TRANSFERÊNCIA")

    Painel.SetFont("s10 w400 cBlack", "Segoe UI")
    btnLimpar := Painel.Add("Button", "w195 h35 x20 y+10", "Limpar CPF")
    btnGerarNome := Painel.Add("Button", "w195 h35 x+10", "Gerar Nome Padrão")
    btnCopiarNome := Painel.Add("Button", "w400 h35 x20 y+10", "Copiar Título da Janela (Fundo)")

    Painel.Add("Text", "w400 h2 0x10 y+15 x20")

    ; --- BUSCA E ARQUIVOS ---
    Painel.SetFont("s10 w700 c00509E", "Segoe UI")
    Painel.Add("Text", "w400 y+15", "🔍 BUSCA E ARQUIVOS")

    Painel.SetFont("s9 w400 c555555", "Segoe UI")
    Painel.Add("Text", "y+10", "Texto para busca (Copiado):")
    Painel.SetFont("s10 w400 cBlack", "Segoe UI")

    textoLimpo := RegExReplace(A_Clipboard, "[\r\n]+", " ")
    textoClip := SubStr(textoLimpo, 1, 80)
    edtBusca := Painel.Add("Edit", "w400 y+5 Limit80", textoClip)

    Painel.SetFont("s9 w400 c555555", "Segoe UI")
    Painel.Add("Text", "y+10", "Selecione as Pastas para Busca (Alt+1 a Alt+5):")

    s1 := IniRead(ArquivoINI, "SelecaoPastas", "Chk1", "0")
    s2 := IniRead(ArquivoINI, "SelecaoPastas", "Chk2", "0")
    s3 := IniRead(ArquivoINI, "SelecaoPastas", "Chk3", "0")
    s4 := IniRead(ArquivoINI, "SelecaoPastas", "Chk4", "0")
    s5 := IniRead(ArquivoINI, "SelecaoPastas", "Chk5", "0")

    Painel.SetFont("s8 w400 cBlack", "Segoe UI")
    chkP1 := Painel.Add("Checkbox", "w320 y+5 " (s1="1"?"Checked":""), IniRead(ArquivoINI, "PastasPadrao", "Pasta1", ""))
    btnEdit1 := Painel.Add("Button", "w70 x+10 hp-2", "Editar INI")
    chkP2 := Painel.Add("Checkbox", "w400 x20 y+5 " (s2="1"?"Checked":""), IniRead(ArquivoINI, "PastasPadrao", "Pasta2", ""))
    chkP3 := Painel.Add("Checkbox", "w400 x20 y+5 " (s3="1"?"Checked":""), IniRead(ArquivoINI, "PastasPadrao", "Pasta3", ""))
    chkP4 := Painel.Add("Checkbox", "w400 x20 y+5 " (s4="1"?"Checked":""), IniRead(ArquivoINI, "PastasPadrao", "Pasta4", ""))

    Painel.SetFont("s9 w400 c555555", "Segoe UI")
    chkP5 := Painel.Add("Checkbox", "x20 y+10 " (s5="1"?"Checked":""), "Pasta Adicional (Caminho Livre):")
    Painel.SetFont("s10 w400 cBlack", "Segoe UI")
    edtP5 := Painel.Add("Edit", "w400 y+5", IniRead(ArquivoINI, "PastasCustom", "Caminho", ""))

    Painel.SetFont("s9 w400 c555555", "Segoe UI")
    Painel.Add("Text", "x20 y+15", "Explorador:")
    Painel.SetFont("s10 w600 cBlack", "Segoe UI")

    expPadrao := IniRead(ArquivoINI, "Configuracoes", "ExploradorPadrao", "1")
    radOC := Painel.Add("Radio", "x20 y+5 " (expPadrao == "1" ? "Checked" : ""), "OneCommander")
    radWE := Painel.Add("Radio", "x+20 " (expPadrao == "2" ? "Checked" : ""), "Windows Explorer")

    Painel.SetFont("s11 w700 cBlack", "Segoe UI")
    btnBuscar := Painel.Add("Button", "w400 h45 x20 y+15 Default", "EXECUTAR BUSCA")

    Painel.Add("Text", "w400 h2 0x10 y+15 x20")

    ; --- EXTRAS E CONFIGURAÇÕES ---
    Painel.SetFont("s10 w700 c00509E", "Segoe UI")
    Painel.Add("Text", "w400 y+15", "⚙️ EXTRAS E CONFIGURAÇÕES")
    btnXHTML := Painel.Add("Button", "w400 h35 y+10", "Converter XHTML -> PDF (Pasta CNIS 2)")

    Painel.SetFont("s9 w600 c333333", "Segoe UI")
    Painel.Add("Text", "x20 y+15 w110", "OneCommander.exe:")
    Painel.SetFont("s8 w400 c777777", "Segoe UI")
    txtCaminhoOC := Painel.Add("Edit", "x+5 yp-2 w205 h25 ReadOnly -E0x200 BackgroundFFFFFF", oneCommanderPath)
    Painel.SetFont("s9 w400 cBlack", "Segoe UI")
    btnProcurarOC := Painel.Add("Button", "x+5 yp w75 h25", "Procurar")

    ; EVENTOS
    btnEdit1.OnEvent("Click", (*) => Run("notepad.exe `"" ArquivoINI "`""))
    btnLimpar.OnEvent("Click", (*) => ModuloLimparCPF())
    btnGerarNome.OnEvent("Click", (*) => ModuloGerarNome())
    btnCopiarNome.OnEvent("Click", (*) => ModuloCopiarNome(Painel))
    btnBuscar.OnEvent("Click", (*) => ModuloExecutarBusca())
    btnXHTML.OnEvent("Click", (*) => ModuloConverterXHTML())
    btnProcurarOC.OnEvent("Click", (*) => AtualizarCaminhoOC())

    Painel.Show("AutoSize Center")

    ; Produtividade: Foco automático no Edit e selecionar tudo para facilitar digitação
    edtBusca.Focus()
    Send("^{a}")
}

RestauraHistorico(indice, *) {
    Global ParagrafosLivres, HistoricoMemoria, Painel
    if (indice == 0)
        return
    ParagrafosLivres := HistoricoMemoria[indice].Clone()
    Painel.Destroy()
    ToolTip("✅ Coleta restaurada na memória!`nAperte F9 para continuar capturando.")
    SetTimer(EsconderDica, -3500)
}

; ============================================================
; LÓGICA DE COLETA (F9) E MESA DE CIRURGIA
; ============================================================

F9::AlternarModoColeta()

AlternarModoColeta() {
    Global ColetaAtiva, ParagrafosLivres, btnColeta, ArquivoINI, HistoricoMemoria

    if (!ColetaAtiva) {
        if (ParagrafosLivres.Length > 0) {
            mensagemAviso := "Itens na memória: " ParagrafosLivres.Length ".`n`nDeseja CONTINUAR ou ZERAR?"
            escolha := MsgBox(mensagemAviso, "Coleta", "Icon? 4")
            if (escolha == "No") {
                ParagrafosLivres := []
            }
        }
        ColetaAtiva := true
        ToolTip("🔴 COLETA ATIVA")
        SetTimer(EsconderDica, -2000)
        try btnColeta.Text := "🛑 PAUSAR E GERAR (F9)"
    } else {
        if (ParagrafosLivres.Length == 0) {
            ColetaAtiva := false
            try btnColeta.Text := "▶️ INICIAR CAPTURA (F9)"
            return
        }

        HistoricoMemoria.InsertAt(1, ParagrafosLivres.Clone())
        if (HistoricoMemoria.Length > 5) {
            HistoricoMemoria.Pop()
        }

        ColetaAtiva := false
        AbrirJanelaRevisao()
    }
}

SugerirNomeArquivo() {
    Global ParagrafosLivres
    textoMassa := ""
    for t in ParagrafosLivres
        textoMassa .= t " "

    nomeSugerido := "Coleta_" A_Now
    if RegExMatch(textoMassa, "\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b", &cpf) {
        cpfLimpo := RegExReplace(cpf[0], "[^0-9]")
        if RegExMatch(textoMassa, "\b[A-Za-zÀ-ÿ]{3,}\b", &nome) {
            nomeSugerido := StrLower(nome[0]) "_" cpfLimpo
        } else {
            nomeSugerido := cpfLimpo
        }
    }
    return nomeSugerido
}

; --- JANELA CIRÚRGICA DE REVISÃO E SALVAMENTO ---
AbrirJanelaRevisao() {
    Global ParagrafosLivres, ArquivoINI, RevLst, RevEdt, RevGuiObj
    Global PastaSalvarPadrao, AppSalvarPadrao

    RevGui := Gui("-MinimizeBox -MaximizeBox +AlwaysOnTop", "Mesa de Cirurgia - Revisão")
    RevGui.MarginX := 20
    RevGui.MarginY := 20
    RevGuiObj := RevGui

    RevGui.SetFont("s11 w700 c003366", "Segoe UI")
    RevGui.Add("Text", "w600", "📋 Itens Capturados (Selecione para editar):")

    RevGui.SetFont("s10 w400 cBlack", "Segoe UI")
    arrTitulos := []
    for idx, txt in ParagrafosLivres
        arrTitulos.Push(idx ". " SubStr(txt, 1, 80) "...")

    RevLst := RevGui.Add("ListBox", "w600 r6 Choose1", arrTitulos)
    RevEdt := RevGui.Add("Edit", "w600 r5 BackgroundFFFFFF", ParagrafosLivres[1])

    RevLst.OnEvent("Change", (*) => (RevEdt.Value := ParagrafosLivres[RevLst.Value]))
    RevEdt.OnEvent("Change", (*) => SalvarEdicao())

    ; --- BOTÕES DE AÇÃO ---
    RevGui.SetFont("s9 w700 c00509E", "Segoe UI")
    btnSubir := RevGui.Add("Button", "w140 h35 y+10", "⬆️ Subir (Alt+↑)")
    btnDescer := RevGui.Add("Button", "w140 h35 x+10 yp", "⬇️ Descer (Alt+↓)")
    btnMesclar := RevGui.Add("Button", "w140 h35 x+10 yp", "🔗 Agrupar (Alt+M)")
    RevGui.SetFont("s9 w700 c8B0000", "Segoe UI")
    btnRemover := RevGui.Add("Button", "w140 h35 x+10 yp", "❌ Remover (Alt+Del)")

    btnSubir.OnEvent("Click", (*) => MoverItemLista(RevLst, RevEdt, -1))
    btnDescer.OnEvent("Click", (*) => MoverItemLista(RevLst, RevEdt, 1))
    btnMesclar.OnEvent("Click", (*) => MesclarItemDaLista(RevLst, RevEdt))
    btnRemover.OnEvent("Click", (*) => RemoverItemDaLista(RevLst, RevEdt, RevGui))

    RevGui.Add("Text", "w600 h2 0x10 y+15")

    ; Formato
    RevGui.SetFont("s10 w700 c00509E", "Segoe UI")
    RevGui.Add("Text", "w600 y+15", "Escolha o formato de saída:")
    RevGui.SetFont("s10 w400 cBlack", "Segoe UI")

    modoSalvo := IniRead(ArquivoINI, "Configuracoes", "ModoColeta", "1")
    rad1 := RevGui.Add("Radio", "x20 y+5 Checked" (modoSalvo=="1"), "Parágrafos Numerados (Separados)")
    rad2 := RevGui.Add("Radio", "x20 y+5 Checked" (modoSalvo=="2"), "Bloco Único Numerado (Separado por ||)")
    rad3 := RevGui.Add("Radio", "x20 y+5 Checked" (modoSalvo=="3"), "Ambos")

    RevGui.Add("Text", "w600 h2 0x10 y+15 x20")

    ; --- CONFIGURAÇÕES DE ARQUIVO (TXT E APP) ---
    RevGui.SetFont("s10 w700 c008000", "Segoe UI")
    RevGui.Add("Text", "w600 y+15 x20", "💾 Salvar Arquivo (.txt) e Abrir no Aplicativo:")

    RevGui.SetFont("s9 w600 cBlack", "Segoe UI")
    RevGui.Add("Text", "x20 y+10 w110", "Nome do Arquivo:")
    RevGui.SetFont("s9 w400 cBlack", "Segoe UI")
    edtNomeArq := RevGui.Add("Edit", "x+5 yp-2 w485", SugerirNomeArquivo())

    RevGui.SetFont("s9 w600 cBlack", "Segoe UI")
    RevGui.Add("Text", "x20 y+10 w110", "Salvar na Pasta:")
    RevGui.SetFont("s8 w400 c777777", "Segoe UI")
    edtPastaTxt := RevGui.Add("Edit", "x+5 yp-2 w405 h23 ReadOnly BackgroundFFFFFF", PastaSalvarPadrao)
    RevGui.SetFont("s9 w400 cBlack", "Segoe UI")
    btnProcPasta := RevGui.Add("Button", "x+5 yp w75 h23", "Procurar")

    RevGui.SetFont("s9 w600 cBlack", "Segoe UI")
    RevGui.Add("Text", "x20 y+10 w110", "Abrir com App:")
    RevGui.SetFont("s8 w400 c777777", "Segoe UI")
    edtAppTxt := RevGui.Add("Edit", "x+5 yp-2 w405 h23 ReadOnly BackgroundFFFFFF", AppSalvarPadrao)
    RevGui.SetFont("s9 w400 cBlack", "Segoe UI")
    btnProcApp := RevGui.Add("Button", "x+5 yp w75 h23", "Procurar")

    btnProcPasta.OnEvent("Click", (*) => SelecionarPastaPadrao(edtPastaTxt))
    btnProcApp.OnEvent("Click", (*) => SelecionarAppPadrao(edtAppTxt))

    ; --- BOTÃO FINAL ---
    RevGui.SetFont("s11 w700", "Segoe UI")
    btnGerar := RevGui.Add("Button", "w600 h50 x20 y+20 Default", "✅ GERAR, SALVAR E ABRIR TEXTO")
    btnGerar.OnEvent("Click", (*) => ProcessarTextoFinal(rad1.Value, rad2.Value, rad3.Value, edtNomeArq.Value, edtPastaTxt.Value, edtAppTxt.Value, RevGui))

    RevGui.Show("AutoSize Center")
}

SelecionarPastaPadrao(ctrl) {
    Global ArquivoINI
    pasta := DirSelect(ctrl.Value, 3, "Selecione a pasta oficial para salvar os arquivos TXT")
    if (pasta != "") {
        ctrl.Value := pasta
        IniWrite(pasta, ArquivoINI, "Configuracoes", "PastaSalvarTxt")
    }
}

SelecionarAppPadrao(ctrl) {
    Global ArquivoINI
    app := FileSelect(3, ctrl.Value, "Selecione o executável do editor (Ex: notepad++.exe)", "Executáveis (*.exe)")
    if (app != "") {
        ctrl.Value := app
        IniWrite(app, ArquivoINI, "Configuracoes", "AppSalvarTxt")
    }
}

SalvarEdicao() {
    Global ParagrafosLivres, RevLst, RevEdt
    idx := RevLst.Value
    if (idx > 0) {
        ParagrafosLivres[idx] := RevEdt.Value
    }
}

MesclarItemDaLista(lstObj, edtObj) {
    Global ParagrafosLivres

    idx := lstObj.Value
    if (idx == 0 or idx >= ParagrafosLivres.Length)
        return

    ParagrafosLivres[idx] := ParagrafosLivres[idx] " " ParagrafosLivres[idx + 1]
    ParagrafosLivres.RemoveAt(idx + 1)

    arrTitulos := []
    for i, txt in ParagrafosLivres
        arrTitulos.Push(i ". " SubStr(txt, 1, 80) "...")

    lstObj.Delete()
    lstObj.Add(arrTitulos)

    lstObj.Choose(idx)
    edtObj.Value := ParagrafosLivres[idx]
}

MoverItemLista(lstObj, edtObj, direcao) {
    Global ParagrafosLivres
    idx := lstObj.Value
    if (idx == 0)
        return
    if (direcao == -1 and idx == 1)
        return
    if (direcao == 1 and idx == ParagrafosLivres.Length)
        return

    novoIdx := idx + direcao
    temp := ParagrafosLivres[idx]
    ParagrafosLivres[idx] := ParagrafosLivres[novoIdx]
    ParagrafosLivres[novoIdx] := temp

    arrTitulos := []
    for i, txt in ParagrafosLivres
        arrTitulos.Push(i ". " SubStr(txt, 1, 80) "...")

    lstObj.Delete()
    lstObj.Add(arrTitulos)
    lstObj.Choose(novoIdx)
    edtObj.Value := ParagrafosLivres[novoIdx]
}

RemoverItemDaLista(lstObj, edtObj, guiObj) {
    Global ParagrafosLivres, btnColeta
    idx := lstObj.Value
    if (idx == 0)
        return

    ParagrafosLivres.RemoveAt(idx)

    if (ParagrafosLivres.Length == 0) {
        guiObj.Destroy()
        ToolTip("Lista esvaziada. Captura cancelada.")
        SetTimer(EsconderDica, -2000)
        try btnColeta.Text := "▶️ INICIAR CAPTURA (F9)"
        return
    }

    arrTitulos := []
    for i, txt in ParagrafosLivres
        arrTitulos.Push(i ". " SubStr(txt, 1, 80) "...")

    lstObj.Delete()
    lstObj.Add(arrTitulos)

    novoIdx := (idx > ParagrafosLivres.Length) ? ParagrafosLivres.Length : idx
    lstObj.Choose(novoIdx)
    edtObj.Value := ParagrafosLivres[novoIdx]
}

; --- GERAÇÃO DO TEXTO FINAL, ARQUIVO E APP ---
ProcessarTextoFinal(pS, pB, pA, nomeArq, pastaDest, appPath, guiObj) {
    Global ParagrafosLivres, ArquivoINI, btnColeta

    escolhaID := pS ? "1" : (pB ? "2" : "3")
    IniWrite(escolhaID, ArquivoINI, "Configuracoes", "ModoColeta")
    guiObj.Destroy()

    bloco := ""
    parag := ""

    for index, txt in ParagrafosLivres {
        bloco .= index ". " txt " || "
        parag .= index ". " txt "`n`n"
    }

    bloco := RegExReplace(bloco, " \|\| $", "")

    if (escolhaID == "1")
        textoFinal := parag
    else if (escolhaID == "2")
        textoFinal := bloco
    else
        textoFinal := "--- BLOCO ---`n" bloco "`n`n--- PARÁGRAFOS ---`n" parag

    nomeArq := RegExReplace(nomeArq, "[\\/:\*\?`"<>\|]", "_")
    if (nomeArq == "")
        nomeArq := "Coleta_" A_Now

    caminhoArquivo := pastaDest "\" nomeArq ".txt"

    try {
        file := FileOpen(caminhoArquivo, "w", "UTF-8")
        file.Write(Trim(textoFinal))
        file.Close()
    } catch {
        MsgBox("Erro ao salvar o arquivo TXT em:`n" caminhoArquivo, "Erro", "IconX")
    }

    A_Clipboard := Trim(textoFinal)

    if FileExist(appPath) or appPath = "notepad.exe" {
        try {
            Run('"' appPath '" "' caminhoArquivo '"')
        } catch {
            MsgBox("Falha ao abrir o aplicativo: " appPath, "Erro", "IconX")
        }
    } else {
        MsgBox("Aplicativo padrão não encontrado. O arquivo TXT foi salvo, mas não pôde ser aberto.", "Aviso", "Icon!")
    }

    ToolTip("✅ Salvo, Copiado e Aberto! (Histórico no F12)")
    SetTimer(EsconderDica, -4000)
    try btnColeta.Text := "▶️ INICIAR CAPTURA (F9)"
}

OnClipboardChange(Monitorar)
Monitorar(Tipo) {
    Global ColetaAtiva, ParagrafosLivres
    if (ColetaAtiva and Tipo = 1) {
        Sleep(150)
        txt := Trim(RegExReplace(A_Clipboard, "[\r\n\t]+", " "))
        txt := RegExReplace(txt, " +", " ")
        if (txt != "") {
            ParagrafosLivres.Push(txt)
            ToolTip("✅ Item " ParagrafosLivres.Length " Capturado")
            SetTimer(EsconderDica, -1000)
        }
    }
}

EsconderDica() => ToolTip()

; ============================================================
; MÓDULOS DE APOIO
; ============================================================
ModuloLimparCPF() {
    if !ClipWait(1) {
        MsgBox("Área de transferência vazia.", "Aviso", "Icon!")
        return
    }
    clean := RegExReplace(RegExReplace(A_Clipboard, "[\.\-]"), "\D")
    if (StrLen(clean) = 11) {
        A_Clipboard := clean
        ToolTip("CPF Limpo: " clean)
    } else {
        ToolTip("Não é CPF")
    }
    SetTimer(HideTip, -1000)
}

ModuloGerarNome() {
    texto := A_Clipboard
    if !RegExMatch(texto, "\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b", &cpf) {
        MsgBox("CPF não encontrado na área de transferência.", "Aviso", "Icon!")
        return
    }
    cpfLimpo := RegExReplace(cpf[0], "[^0-9]")
    RegExMatch(texto, "\b[A-Za-zÀ-ÿ]+\b", &nome)

    if nome {
        A_Clipboard := StrLower(nome[0]) "_" cpfLimpo
        ToolTip("Nome gerado: " A_Clipboard)
    } else {
        A_Clipboard := cpfLimpo
        ToolTip("Nome gerado: " A_Clipboard)
    }
    SetTimer(HideTip, -1000)
}

ModuloCopiarNome(guiObj) {
    WinMinimize("ahk_id " guiObj.Hwnd)
    Sleep(200)
    titulo := WinGetTitle("A")
    A_Clipboard := RegExReplace(titulo, "( - | — ).*", "")
    Send("!{Space}")
    Sleep(300)
    Send("^v")
}

ModuloExecutarBusca() {
    Global edtBusca, ArquivoINI, radOC, oneCommanderPath, chkP1, chkP2, chkP3, chkP4, chkP5, edtP5
    textoFinal := edtBusca.Value

    ToolTip("Executando busca...")
    SetTimer(HideTip, -1500)

    IniWrite(chkP1.Value, ArquivoINI, "SelecaoPastas", "Chk1")
    IniWrite(chkP2.Value, ArquivoINI, "SelecaoPastas", "Chk2")
    IniWrite(chkP3.Value, ArquivoINI, "SelecaoPastas", "Chk3")
    IniWrite(chkP4.Value, ArquivoINI, "SelecaoPastas", "Chk4")
    IniWrite(chkP5.Value, ArquivoINI, "SelecaoPastas", "Chk5")
    IniWrite(edtP5.Value, ArquivoINI, "PastasCustom", "Caminho")

    caminhos := []
    if (chkP1.Value && chkP1.Text != "")
        caminhos.Push(chkP1.Text)
    if (chkP2.Value && chkP2.Text != "")
        caminhos.Push(chkP2.Text)
    if (chkP3.Value && chkP3.Text != "")
        caminhos.Push(chkP3.Text)
    if (chkP4.Value && chkP4.Text != "")
        caminhos.Push(chkP4.Text)
    if (chkP5.Value && edtP5.Value != "")
        caminhos.Push(edtP5.Value)

    if (caminhos.Length == 0) {
        MsgBox("Selecione pelo menos uma pasta para executar a busca.", "Aviso", "Icon!")
        return
    }

    if (radOC.Value) {
        IniWrite("1", ArquivoINI, "Configuracoes", "ExploradorPadrao")
        if !FileExist(oneCommanderPath) {
            MsgBox("Executável do OneCommander não encontrado.", "Erro", "Iconx")
            return
        }
        for path in caminhos {
            caminhoLimpo := Trim(StrReplace(path, "`"", ""))
            caminhoLimpo := RegExReplace(caminhoLimpo, "\\$", "")
            Run('"' oneCommanderPath '" "' caminhoLimpo '"')
            if WinWaitActive("ahk_exe OneCommander.exe", , 3) {
                Sleep(600)
                Send("{F3}")
                Sleep(300)
                SendText(textoFinal)
                Sleep(100)
                Send("{Enter}")
            }
            Sleep(500)
        }
    } else {
        IniWrite("2", ArquivoINI, "Configuracoes", "ExploradorPadrao")

        cmd := "search-ms:query=" textoFinal

        for path in caminhos {
            caminhoLimpo := Trim(StrReplace(path, "`"", ""))
            caminhoLimpo := RegExReplace(caminhoLimpo, "\\$", "")
            cmd .= "&crumb=location:" caminhoLimpo
        }

        Run('explorer.exe "' cmd '"')
    }

    ; Oculta o painel central ao executar a busca para focar nos resultados
    try Painel.Destroy()
}

ModuloConverterXHTML() {
    count := 0
    PastaAlvo := "C:\02_CNISLINHA 2"
    Loop Files, PastaAlvo "\*.xhtml"
    {
        old := A_LoopFileFullPath
        new := RegExReplace(old, "i)\.xhtml$", ".pdf")
        FileMove(old, new, 1)

        if FileExist(new) {
            Run('"' PDFApp '" "' new '"')
            count++
        }
    }
    TrayTip("Conversão", count ? count " arquivo(s) convertidos." : "Nenhum arquivo .xhtml encontrado.", 3)
}

AtualizarCaminhoOC() {
    Global ArquivoINI, oneCommanderPath, txtCaminhoOC
    novoCaminho := FileSelect(3, oneCommanderPath, "Selecione o arquivo OneCommander.exe", "Executáveis (*.exe)")

    if (novoCaminho != "") {
        oneCommanderPath := novoCaminho
        IniWrite(novoCaminho, ArquivoINI, "Configuracoes", "OneCommanderPath")
        txtCaminhoOC.Value := novoCaminho
        MsgBox("Caminho atualizado e salvo com sucesso!", "Pronto", "Iconi")
    }
}

; ============================================================
; ATALHOS DE TECLADO PARA A JANELA DE REVISÃO E CENTRAL
; ============================================================
#HotIf WinActive("Mesa de Cirurgia - Revisão")
!Up::MoverItemLista(RevLst, RevEdt, -1)
!Down::MoverItemLista(RevLst, RevEdt, 1)
!m::MesclarItemDaLista(RevLst, RevEdt) ; Alt + M para Agrupar
!Del::RemoverItemDaLista(RevLst, RevEdt, RevGuiObj) ; Alt + Del para Remover
#HotIf

#HotIf WinActive("Central INSS")
!1::chkP1.Value := !chkP1.Value
!2::chkP2.Value := !chkP2.Value
!3::chkP3.Value := !chkP3.Value
!4::chkP4.Value := !chkP4.Value
!5::chkP5.Value := !chkP5.Value
#HotIf
