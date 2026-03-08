; ============================================================
; 🔎 MÓDULO 1 – BUSCA RÁPIDA (ALT + A)
; ============================================================

; Configurações Iniciais
iniFile := A_ScriptDir . "\config.ini"
PastaPadrao := "C:\PastaPadrao" ; Altere para a pasta padrão desejada

!a::
    WinGet, activeWindow, ID, A

    ; 1. Melhoria: Copiar texto automaticamente (sem precisar dar Ctrl+C antes)
    ClipSaved := ClipboardAll ; Salva o clipboard original
    Clipboard := "" ; Limpa o clipboard
    Send, ^c ; Envia Ctrl+C para copiar o texto selecionado
    ClipWait, 0.5 ; Espera até 0.5s para o texto ir para a área de transferência

    texto := Clipboard

    if (!texto)
    {
        ; Restaura o clipboard original se nada foi copiado
        Clipboard := ClipSaved
        MsgBox, 48, Atenção, Selecione algum texto antes de usar o atalho.
        return
    }

    ; Remove pontos e traços
    texto := RegExReplace(texto, "[\.\-]")
    textoBusca := texto ; Variável para usar na busca sem sobrescrever permanentemente o clipboard

    ; Restaura o clipboard original para não atrapalhar o usuário
    Clipboard := ClipSaved

    ; Lê preferências salvas
    IniRead, explorerChoice, %iniFile%, Preferencias, Explorer, 1
    IniRead, pastaSelecionada, %iniFile%, Preferencias, Pasta, 1

    ; ---------- GUI ----------
    Gui, BuscaGUI:New, +AlwaysOnTop
    Gui, BuscaGUI:Font, s10

    Gui, BuscaGUI:Add, Text,, Texto buscado: %textoBusca%

    Gui, BuscaGUI:Add, Text,, Escolha o explorador:

    c1 := (explorerChoice=1) ? "Checked" : ""
    c2 := (explorerChoice=2) ? "Checked" : ""

    Gui, BuscaGUI:Add, Radio, vExp1 Group %c1%, OneCommander
    Gui, BuscaGUI:Add, Radio, vExp2 %c2%, Windows Explorer

    Gui, BuscaGUI:Add, Text,, Escolha a pasta:

    p1 := (pastaSelecionada=1) ? "Checked" : ""
    p2 := (pastaSelecionada=2) ? "Checked" : ""

    Gui, BuscaGUI:Add, Radio, vPasta1 Group %p1%, %PastaPadrao%
    Gui, BuscaGUI:Add, Radio, vPasta2 %p2%, C:\OutraPasta

    Gui, BuscaGUI:Add, Button, Default gExecutarBusca, Executar
    Gui, BuscaGUI:Show,, Busca Inteligente
return

ExecutarBusca:
    Gui, BuscaGUI:Submit ; Pega os valores das variáveis vExp1, vExp2, vPasta1, vPasta2

    ; Determina as escolhas
    escolhaExplorador := Exp1 ? 1 : 2
    escolhaPasta := Pasta1 ? 1 : 2

    caminhoPasta := (escolhaPasta = 1) ? PastaPadrao : "C:\OutraPasta"

    ; 2. Melhoria: Salva as escolhas para a próxima vez
    IniWrite, %escolhaExplorador%, %iniFile%, Preferencias, Explorer
    IniWrite, %escolhaPasta%, %iniFile%, Preferencias, Pasta

    ; 3. Melhoria: Executa a busca real
    if (escolhaExplorador = 1)
    {
        ; Exemplo de comando para abrir OneCommander (ajuste o caminho do executável se necessário)
        Run, "C:\Program Files\OneCommander\OneCommander.exe" "%caminhoPasta%"
    }
    else if (escolhaExplorador = 2)
    {
        ; Usa a URI search-ms para realizar a busca nativa no Windows Explorer
        ; Isso abre os resultados de busca instantaneamente na pasta escolhida
        query := "search-ms:query=" . textoBusca . "&crumb=location:" . caminhoPasta
        Run, explorer.exe "%query%"
    }

    Gui, BuscaGUI:Destroy
return

BuscaGUIEscape:
BuscaGUIClose:
    Gui, BuscaGUI:Destroy
return
