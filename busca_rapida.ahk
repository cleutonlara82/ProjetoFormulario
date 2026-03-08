; ============================================================
; 🔎 MÓDULO 1 – BUSCA RÁPIDA (ALT + A) (AutoHotkey v2)
; ============================================================
#Requires AutoHotkey v2.0

; Configurações Iniciais
global iniFile := A_ScriptDir . "\config.ini"
global PastaPadrao := "C:\PastaPadrao" ; Altere para a pasta padrão desejada

!a::
{
    activeWindow := WinGetID("A")

    ; 1. Melhoria: Copiar texto automaticamente (sem precisar dar Ctrl+C antes)
    ClipSaved := ClipboardAll() ; Salva o clipboard original
    A_Clipboard := "" ; Limpa o clipboard
    Send("^c") ; Envia Ctrl+C para copiar o texto selecionado

    ; Espera até 0.5s para o texto ir para a área de transferência
    if !ClipWait(0.5)
    {
        ; Restaura o clipboard original se nada foi copiado
        A_Clipboard := ClipSaved
        MsgBox("Selecione algum texto antes de usar o atalho.", "Atenção", 48)
        return
    }

    texto := A_Clipboard

    ; Remove pontos e traços
    texto := RegExReplace(texto, "[\.\-]")
    textoBusca := texto ; Variável para usar na busca sem sobrescrever permanentemente o clipboard

    ; Restaura o clipboard original para não atrapalhar o usuário
    A_Clipboard := ClipSaved

    ; Lê preferências salvas (o valor padrão é o terceiro parâmetro em v2)
    explorerChoice := IniRead(iniFile, "Preferencias", "Explorer", 1)
    pastaSelecionada := IniRead(iniFile, "Preferencias", "Pasta", 1)

    ; ---------- GUI ----------
    BuscaGUI := Gui("+AlwaysOnTop", "Busca Inteligente")
    BuscaGUI.SetFont("s10")

    BuscaGUI.Add("Text",, "Texto buscado: " . textoBusca)

    BuscaGUI.Add("Text",, "Escolha o explorador:")

    c1 := (explorerChoice = 1) ? "Checked" : ""
    c2 := (explorerChoice = 2) ? "Checked" : ""

    radExp1 := BuscaGUI.Add("Radio", "vExp1 Group " . c1, "OneCommander")
    radExp2 := BuscaGUI.Add("Radio", "vExp2 " . c2, "Windows Explorer")

    BuscaGUI.Add("Text",, "Escolha a pasta:")

    p1 := (pastaSelecionada = 1) ? "Checked" : ""
    p2 := (pastaSelecionada = 2) ? "Checked" : ""

    radPasta1 := BuscaGUI.Add("Radio", "vPasta1 Group " . p1, PastaPadrao)
    radPasta2 := BuscaGUI.Add("Radio", "vPasta2 " . p2, "C:\OutraPasta")

    btnExecutar := BuscaGUI.Add("Button", "Default w80", "Executar")

    ; Em v2, os eventos de clique são vinculados a funções (OnEvent)
    btnExecutar.OnEvent("Click", (*) => ExecutarBusca(BuscaGUI, radExp1, radPasta1, textoBusca))
    BuscaGUI.OnEvent("Escape", (*) => BuscaGUI.Destroy())
    BuscaGUI.OnEvent("Close", (*) => BuscaGUI.Destroy())

    BuscaGUI.Show()
}

ExecutarBusca(guiObj, radExp1, radPasta1, textoBusca)
{
    ; A propriedade Value de um Radio button retorna 1 se marcado, 0 se não.
    ; Como agrupamos os Radio buttons, verificamos apenas o primeiro para saber qual foi escolhido.
    escolhaExplorador := radExp1.Value ? 1 : 2
    escolhaPasta := radPasta1.Value ? 1 : 2

    caminhoPasta := (escolhaPasta = 1) ? PastaPadrao : "C:\OutraPasta"

    ; 2. Melhoria: Salva as escolhas para a próxima vez
    IniWrite(escolhaExplorador, iniFile, "Preferencias", "Explorer")
    IniWrite(escolhaPasta, iniFile, "Preferencias", "Pasta")

    ; 3. Melhoria: Executa a busca real
    if (escolhaExplorador = 1)
    {
        ; Exemplo de comando para abrir OneCommander (ajuste o caminho do executável se necessário)
        Run('"C:\Program Files\OneCommander\OneCommander.exe" "' . caminhoPasta . '"')
    }
    else if (escolhaExplorador = 2)
    {
        ; Usa a URI search-ms para realizar a busca nativa no Windows Explorer
        query := "search-ms:query=" . textoBusca . "&crumb=location:" . caminhoPasta
        Run('explorer.exe "' . query . '"')
    }

    guiObj.Destroy()
}
