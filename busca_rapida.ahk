; ============================================================
; MÓDULO 5 – COPIAR NOME DO ARQUIVO (F1)
; ============================================================

F1::{
    ; Salva o conteúdo atual da área de transferência
    ClipSalvo := ClipboardAll()
    A_Clipboard := ""
    nomeExtraido := ""

    ; Verifica se a janela ativa é o Windows Explorer
    classeJanela := WinGetClass("A")
    if (classeJanela = "CabinetWClass" or classeJanela = "ExploreWClass") {
        ; Tenta copiar o arquivo selecionado
        Send("^c")
        if ClipWait(0.5) {
            ; Extrai apenas o nome do primeiro arquivo copiado, sem o caminho e sem a extensão
            SplitPath(A_Clipboard, &nomeArquivo, , &extensao, &nomeSemExt)
            nomeExtraido := nomeSemExt
        }
    }

    ; Se não extraiu nome de um arquivo (não estava no Explorer ou não havia nada selecionado)
    if (nomeExtraido = "") {
        titulo := WinGetTitle("A")
        ; Remove tudo a partir de " - " ou " — "
        nomeLimpo := RegExReplace(titulo, "( - | — ).*", "")
        ; Remove também possíveis extensões de arquivo do título caso existam
        nomeExtraido := RegExReplace(nomeLimpo, "\.[a-zA-Z0-9]{2,4}$", "")
    }

    ; Define o novo conteúdo para a busca
    A_Clipboard := nomeExtraido
    ClipWait(1) ; Aguarda garantir que a área de transferência foi atualizada

    ; Abre o buscador (assumindo que seja o atalho do PowerToys Run, Flow Launcher, etc)
    Send("!{Space}")
    Sleep(300)

    ; Cola o texto
    Send("^v")

    ; Pequena pausa para garantir que o sistema operacional processou a colagem
    Sleep(150)

    ; Restaura a área de transferência original para não perder o que estava copiado antes
    A_Clipboard := ClipSalvo
}
