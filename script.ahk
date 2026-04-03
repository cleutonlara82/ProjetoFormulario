#Requires AutoHotkey v2.0
#SingleInstance Force

; ==========================================
; CONFIGURAÇÕES E INICIALIZAÇÃO
; ==========================================
Global DirExigencias := A_ScriptDir "\Exigencias"
Global DirAnalise := A_ScriptDir "\Servicos_Analise"
Global ArqRegras := A_ScriptDir "\regras_marcacao.txt"
Global ArqConfig := A_ScriptDir "\config.ini"

; Variáveis de Dados
Global BancoExigencias := Map()
Global ListaServicosExig := []
Global BancoServicos := Map()
Global ListaServicos := []
Global RegrasAutoCheck := Map()
Global TitulosUnicos := []
Global TitulosMapArquivos := Map()
Global FlatExig := []
Global DadosOrdem := []

; Variáveis de Interface
Global G_Exig := unset, LV_Exig, Prev_Exig, Nome_Exig, Dados_Exig, Drop_Exig
Global G_Ana := unset, Drop_Ana, Prev_Ana, Nome_Ana, Dados_Ana, Checks_Ana := []
Global MenuGui := unset
Global G_Edit := unset, Busca_Ed, LV_Titulos, Titulo_Edit, Texto_Edit, LV_Arquivos, LV_Partes := unset, TopicoCarregado := []
Global G_Conf := unset, Busca_Conf, LV_Gatilhos, LV_Alvos, Edit_RegrasAtuais
Global G_NovoT := unset, Drop_NT_Arq, Drop_NT_Aba, Edit_NT_Tit, Edit_NT_Txt
Global G_Ord := unset, Drop_Ord_Arq, LB_Ord_Abas, LB_Ord_Tops, LB_Ord_Subs
Global G_Abas := unset, Drop_GA_Arq, LB_GA_Abas
Global G_Clone := unset, Drop_Cl_Origem, Chk_Cl_Abas, Edit_Cl_Novo

If !DirExist(DirExigencias)
    DirCreate(DirExigencias)
If !FileExist(DirExigencias "\exigencias_inss.txt")
    CriarPadraoExigencias()

If !DirExist(DirAnalise)
    CriarPadraoAnalise()

RecarregarDadosGerais()

; Ativa o monitoramento do mouse para exibir os balões explicativos (Tooltips)
OnMessage(0x0200, ControleTooltip)

TrayTip "Sistema INSS Ativo", "Pressione F11 para abrir o menu.", 1

; ==========================================
; ATALHO TECLADO E MENU PRINCIPAL
; ==========================================
f11::AbrirMenuPrincipal()

AbrirMenuPrincipal(*) {
    Global MenuGui
    if IsSet(MenuGui) && MenuGui
        MenuGui.Destroy()

    MenuGui := Gui("", "Menu APS Prudentópolis")
    MenuGui.OnEvent("Escape", (gui, *) => gui.Minimize())

    MenuGui.SetFont("s11 bold", "Segoe UI")
    MenuGui.Add("Text", "w350 Center", "O que você deseja fazer?")

    MenuGui.SetFont("s10 norm")
    BtnExig := MenuGui.Add("Button", "w350 h45 y+15", "1. Despacho de EXIGÊNCIAS")
    BtnExig.OnEvent("Click", (*) => (MenuGui.Destroy(), AbrirExigencias()))

    BtnAna := MenuGui.Add("Button", "w350 h45 y+10", "2. Despacho de ANÁLISE / ACERTOS")
    BtnAna.OnEvent("Click", (*) => (MenuGui.Destroy(), AbrirAnalise()))

    BtnSidep := MenuGui.Add("Button", "w350 h45 y+10", "3. Despacho Exclusivo SIDEP")
    BtnSidep.OnEvent("Click", (*) => (MenuGui.Destroy(), AbrirAnalise("", "", "SIDEP_Despachos")))

    BtnEdit := MenuGui.Add("Button", "w350 h45 y+10", "4. EDITOR Amigável e Gestor")
    BtnEdit.OnEvent("Click", (*) => (MenuGui.Destroy(), AbrirEditorAmigavel()))

    BtnConf := MenuGui.Add("Button", "w350 h45 y+10", "5. CONFIGURAR Marcações Automáticas")
    BtnConf.OnEvent("Click", (*) => (MenuGui.Destroy(), AbrirConfigMarcacoes()))

    MenuGui.Show("AutoSize Center")
}

; ==========================================
; MÓDULO 1: EXIGÊNCIAS
; ==========================================
AbrirExigencias(nomeP := "", dadosP := "", servicoSel := "") {
    Global G_Exig, Drop_Exig, LV_Exig, Prev_Exig, Nome_Exig, Dados_Exig, FlatExig

    if IsSet(G_Exig) && G_Exig
        G_Exig.Destroy()

    G_Exig := Gui("", "Gerador de EXIGÊNCIAS - INSS")
    G_Exig.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Exig.SetFont("s10", "Segoe UI")

    G_Exig.Add("Text", "w550", "Interessado:")
    Nome_Exig := G_Exig.Add("Edit", "vNomeEx w550 Uppercase", nomeP)
    Nome_Exig.OnEvent("Change", GerarExig)

    G_Exig.Add("Text", "y+10", "Dados extraídos:")
    Dados_Exig := G_Exig.Add("Edit", "vDadosEx w550", dadosP)
    Dados_Exig.OnEvent("Change", GerarExig)

    G_Exig.Add("Text", "y+10 w550", "Serviço Selecionado (Exigências):")
    arrServ := []
    for s in ListaServicosExig
        arrServ.Push(s)
    if (arrServ.Length == 0)
        arrServ.Push("Vazio")

    if (servicoSel == "")
        servicoSel := IniRead(ArqConfig, "Preferencias", "UltimoServicoExig", "")
    if (servicoSel == "" || !GetIndex(arrServ, servicoSel, true)) && arrServ.Length > 0
        servicoSel := arrServ[1]

    Drop_Exig := G_Exig.Add("DropDownList", "vServEx w550 Choose" GetIndex(arrServ, servicoSel), arrServ)
    Drop_Exig.OnEvent("Change", (*) => (
        v := G_Exig.Submit(false),
        IniWrite(v.ServEx, ArqConfig, "Preferencias", "UltimoServicoExig"),
        AbrirExigencias(v.NomeEx, v.DadosEx, v.ServEx)
    ))

    G_Exig.Add("Text", "y+15", "Selecione os Motivos (Marque o Quadrado):")
    LV_Exig := G_Exig.Add("ListView", "r18 w550 Checked -Multi", ["Tópico"])
    LV_Exig.ModifyCol(1, 520)

    FlatExig := []
    if BancoExigencias.Has(servicoSel) {
        for item in BancoExigencias[servicoSel] {
            LV_Exig.Add(, item.t)
            FlatExig.Push({isSub: false, c: item.c})
            parentIdx := FlatExig.Length
            for sub in item.subs {
                LV_Exig.Add(, "  ↳ " sub.t)
                FlatExig.Push({isSub: true, c: sub.c, parentIdx: parentIdx})
            }
        }
    }
    LV_Exig.OnEvent("ItemCheck", GerarExig)

    G_Exig.Add("Text", "x580 y10 w650", "PRÉ-VISUALIZAÇÃO (Pode editar livremente antes de copiar):")
    Prev_Exig := G_Exig.Add("Edit", "x580 y30 w650 h680 BackgroundFFFFFF")

    BtnVoltar := G_Exig.Add("Button", "x10 y730 w550 h50", "⬅️ VOLTAR AO MENU")
    BtnVoltar.OnEvent("Click", (*) => (G_Exig.Destroy(), AbrirMenuPrincipal()))

    BtnCopiar := G_Exig.Add("Button", "x580 y730 w650 h50 Default", "COPIAR TEXTO")
    BtnCopiar.OnEvent("Click", (*) => (A_Clipboard := Prev_Exig.Value, ToolTip("Copiado!"), SetTimer(()=>ToolTip(), -2000)))

    G_Exig.Show("w1250 h800")
    GerarExig()
}

GerarExig(*) {
    if !IsSet(G_Exig) || !G_Exig
        return
    vals := G_Exig.Submit(false)
    t := ""
    if (vals.NomeEx != "")
        t .= "INTERESSADO: " vals.NomeEx "`n"
    if (vals.DadosEx != "")
        t .= "DADOS EXTRAÍDOS: " vals.DadosEx "`n`n"
    else if (vals.NomeEx != "")
        t .= "`n"

    t .= "MOTIVOS DA EXIGÊNCIA:`n--------------------------------------------------`n"

    for i, item in FlatExig {
        isChecked := (LV_Exig.GetNext(i-1, "Checked") == i)

        if (!item.isSub && isChecked) {
            str := item.c
            j := i + 1
            while (j <= FlatExig.Length && FlatExig[j].isSub && FlatExig[j].parentIdx == i) {
                if (LV_Exig.GetNext(j-1, "Checked") == j)
                    str .= " " FlatExig[j].c
                j++
            }
            t .= str "`n`n--------------------------------------------------`n"
        }
        else if (item.isSub && isChecked) {
            parentChecked := (LV_Exig.GetNext(item.parentIdx-1, "Checked") == item.parentIdx)
            if (!parentChecked)
                t .= item.c "`n`n--------------------------------------------------`n"
        }
    }
    Prev_Exig.Value := t
}

; ==========================================
; MÓDULO 2: ANÁLISE / ACERTOS
; ==========================================
AbrirAnalise(nomeP := "", dadosP := "", servicoSel := "") {
    Global G_Ana, Drop_Ana, Prev_Ana, Nome_Ana, Dados_Ana, Checks_Ana
    Checks_Ana := []

    if IsSet(G_Ana) && G_Ana
        G_Ana.Destroy()

    G_Ana := Gui("", "Gerador de ANÁLISE / ACERTOS - INSS")
    G_Ana.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Ana.SetFont("s10", "Segoe UI")

    G_Ana.Add("Text", "x10 y10 w550", "Interessado:")
    Nome_Ana := G_Ana.Add("Edit", "vNomeAn x10 y30 w550 Uppercase", nomeP)
    Nome_Ana.OnEvent("Change", GerarAna)

    G_Ana.Add("Text", "x10 y65 w550", "Dados extraídos:")
    Dados_Ana := G_Ana.Add("Edit", "vDadosAn x10 y85 w550", dadosP)
    Dados_Ana.OnEvent("Change", GerarAna)

    G_Ana.Add("Text", "x10 y120 w550", "Serviço Selecionado (Análise):")
    arrServ := []
    for s in ListaServicos
        arrServ.Push(s)
    if (arrServ.Length == 0)
        arrServ.Push("Vazio")

    if (servicoSel == "")
        servicoSel := IniRead(ArqConfig, "Preferencias", "UltimoServicoAna", "")
    if (servicoSel == "" || !GetIndex(arrServ, servicoSel, true)) && arrServ.Length > 0
        servicoSel := arrServ[1]

    Drop_Ana := G_Ana.Add("DropDownList", "vServAn x10 y140 w550 Choose" GetIndex(arrServ, servicoSel), arrServ)
    Drop_Ana.OnEvent("Change", (*) => (
        v := G_Ana.Submit(false),
        IniWrite(v.ServAn, ArqConfig, "Preferencias", "UltimoServicoAna"),
        AbrirAnalise(v.NomeAn, v.DadosAn, v.ServAn)
    ))

    AbasServ := []
    if BancoServicos.Has(servicoSel) {
        for abaObj in BancoServicos[servicoSel]
            AbasServ.Push(abaObj.nome)
    }

    if (AbasServ.Length > 0) {
        MinhasAbas := G_Ana.Add("Tab3", "x10 y180 w550 h530", AbasServ)
        for indice, abaObj in BancoServicos[servicoSel] {
            MinhasAbas.UseTab(indice)
            yPos := 220
            for item in abaObj.itens {
                chk := G_Ana.Add("Checkbox", "x25 y" yPos " w500", item.t)
                chk.OnEvent("Click", AoClicarCheckbox)
                Checks_Ana.Push({ctrl: chk, txt: item.c, isSub: false})
                parentIdx := Checks_Ana.Length
                yPos += 30

                for sub in item.subs {
                    chkSub := G_Ana.Add("Checkbox", "x45 y" yPos " w480", "↳ " sub.t)
                    chkSub.OnEvent("Click", AoClicarCheckbox)
                    Checks_Ana.Push({ctrl: chkSub, txt: sub.c, isSub: true, parentIdx: parentIdx})
                    yPos += 30
                }
            }
        }
        MinhasAbas.UseTab()
    }

    G_Ana.Add("Text", "x580 y10 w650", "PRÉ-VISUALIZAÇÃO (Pode editar livremente antes de copiar):")
    Prev_Ana := G_Ana.Add("Edit", "x580 y30 w650 h680 BackgroundFFFFFF")

    BtnVoltarA := G_Ana.Add("Button", "x10 y730 w550 h50", "⬅️ VOLTAR AO MENU")
    BtnVoltarA.OnEvent("Click", (*) => (G_Ana.Destroy(), AbrirMenuPrincipal()))

    BtnCopiarA := G_Ana.Add("Button", "x580 y730 w650 h50 Default", "COPIAR TEXTO")
    BtnCopiarA.OnEvent("Click", (*) => (A_Clipboard := Prev_Ana.Value, ToolTip("Copiado!"), SetTimer(()=>ToolTip(), -2000)))

    G_Ana.Show("w1250 h800")
    GerarAna()
}

GerarAna(*) {
    if !IsSet(G_Ana) || !G_Ana
        return
    v := G_Ana.Submit(false)
    t := ""
    if (v.NomeAn != "")
        t .= "INTERESSADO: " v.NomeAn "`n"
    if (v.DadosAn != "")
        t .= "DADOS EXTRAÍDOS: " v.DadosAn "`n`n"
    else if (v.NomeAn != "")
        t .= "`n"

    t .= "ACERTO ADMINISTRATIVO / PROCEDIMENTOS:`n--------------------------------------------------`n"

    for i, cb in Checks_Ana {
        if (!cb.isSub && cb.ctrl.Value == 1) {
            str := cb.txt
            j := i + 1
            while (j <= Checks_Ana.Length && Checks_Ana[j].isSub && Checks_Ana[j].parentIdx == i) {
                if (Checks_Ana[j].ctrl.Value == 1)
                    str .= " " Checks_Ana[j].txt
                j++
            }
            t .= "• " str "`n`n"
        }
        else if (cb.isSub && cb.ctrl.Value == 1) {
            parent := Checks_Ana[cb.parentIdx]
            if (parent.ctrl.Value == 0)
                t .= "• " cb.txt "`n`n"
        }
    }
    Prev_Ana.Value := t
}

AoClicarCheckbox(ctrl, info) {
    GerarAna()
    if (RegrasAutoCheck.Has(ctrl.Text)) {
        alvos := RegrasAutoCheck[ctrl.Text]
        for cb in Checks_Ana {
            for alvo in alvos {
                if (cb.ctrl.Text == alvo)
                    cb.ctrl.Value := ctrl.Value
            }
        }
        GerarAna()
    }
}

; ==========================================
; MÓDULO 3: EDITOR AVANÇADO E GESTOR DE CONTEÚDO
; ==========================================
AbrirEditorAmigavel(*) {
    Global G_Edit, Busca_Ed, LV_Titulos, Titulo_Edit, Texto_Edit, LV_Arquivos

    if IsSet(G_Edit) && G_Edit
        G_Edit.Destroy()

    G_Edit := Gui("", "Editor e Gestor Avançado - INSS")
    G_Edit.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Edit.SetFont("s10", "Segoe UI")

    G_Edit.Add("Text", "w600", "1. 🔎 Buscar Tópico (Exigências e Análises):")
    Busca_Ed := G_Edit.Add("Edit", "w600 vBuscaEdit")
    Busca_Ed.OnEvent("Change", FiltrarTitulos_Editor)

    LV_Titulos := G_Edit.Add("ListView", "w600 r6 -Multi", ["Tópicos Disponíveis (Clique em um)"])
    LV_Titulos.ModifyCol(1, 570)
    LV_Titulos.OnEvent("Click", CarregarTextoEArquivos)

    G_Edit.Add("Text", "w600 y+10", "2. Selecione o que editar (Tópico ou Subtópico):")
    LV_Partes := G_Edit.Add("ListView", "w600 r5 -Multi", ["Parte", "Tipo", "Index"])
    LV_Partes.ModifyCol(1, 450)
    LV_Partes.ModifyCol(2, 120)
    LV_Partes.ModifyCol(3, 0)
    LV_Partes.OnEvent("Click", AoClicarParte)

    BtnNovoSub := G_Edit.Add("Button", "w295 h30 y+5", "➕ Adicionar Subtópico")
    BtnNovoSub.OnEvent("Click", AdicionarSubtopico)
    BtnDelSub := G_Edit.Add("Button", "x+10 yp w295 h30", "🗑️ Excluir Subtópico Selecionado")
    BtnDelSub.OnEvent("Click", ExcluirSubtopico)

    G_Edit.Add("Text", "x15 w600 y+10", "3. Edite o TÍTULO da parte selecionada:")
    Titulo_Edit := G_Edit.Add("Edit", "w600 vTituloEdit")
    Titulo_Edit.OnEvent("Change", SalvarEdicaoParte)

    G_Edit.Add("Text", "w600 y+10", "4. Edite o TEXTO da parte selecionada:")
    Texto_Edit := G_Edit.Add("Edit", "w600 h120 vTextoEdit")
    Texto_Edit.OnEvent("Change", SalvarEdicaoParte)

    G_Edit.Add("Text", "w600 y+10", "5. ONDE salvar (Marque os arquivos de destino):")
    LV_Arquivos := G_Edit.Add("ListView", "w600 r3 Checked -Multi", ["Arquivos onde o tópico está", "CaminhoOculto"])
    LV_Arquivos.ModifyCol(1, 570)
    LV_Arquivos.ModifyCol(2, 0)

    BtnSalvarSel := G_Edit.Add("Button", "w295 h40 y+10 Default", "💾 SALVAR EDIÇÃO NOS MARCADOS")
    BtnSalvarSel.Dica := "Salva o texto atualizado APENAS nos arquivos marcados com a caixinha acima."
    BtnSalvarSel.OnEvent("Click", (*) => ExecutarSalvamento(false))

    BtnSalvarTodos := G_Edit.Add("Button", "x+10 yp w295 h40", "🔥 SALVAR EM TODOS OS ARQUIVOS")
    BtnSalvarTodos.Dica := "Salva o texto atualizado em TODOS os arquivos onde este tópico aparece."
    BtnSalvarTodos.OnEvent("Click", (*) => ExecutarSalvamento(true))

    ; Ferramentas de Gestão
    G_Edit.Add("Text", "x15 y+15 w600", "5. Gerenciamento de Tópicos e Abas:")

    BtnNovoTopico := G_Edit.Add("Button", "x15 y+5 w145 h35", "➕ NOVO Tópico")
    BtnNovoTopico.Dica := "Cria um novo título e texto (exigência ou análise) do zero."
    BtnNovoTopico.OnEvent("Click", AbrirNovoTopico)

    BtnDelTopico := G_Edit.Add("Button", "x+6 yp w145 h35", "🗑️ EXCLUIR Tópico")
    BtnDelTopico.Dica := "Apaga definitivamente o tópico selecionado dos arquivos marcados."
    BtnDelTopico.OnEvent("Click", ExecutarExclusaoTopico)

    BtnGerirAbas := G_Edit.Add("Button", "x+6 yp w145 h35", "📑 GERENCIAR Abas")
    BtnGerirAbas.Dica := "Cria, renomeia ou apaga as categorias (abas) dentro das Análises."
    BtnGerirAbas.OnEvent("Click", AbrirGestorAbas)

    BtnReordenar := G_Edit.Add("Button", "x+6 yp w145 h35", "🔄 REORDENAR Tudo")
    BtnReordenar.Dica := "Muda a ordem das abas e tópicos para organizar sua tela."
    BtnReordenar.OnEvent("Click", AbrirGestorOrdem)

    G_Edit.Add("Text", "x15 y+10 w600", "6. Gerenciamento de Serviços (Arquivos):")

    BtnNovoServAn := G_Edit.Add("Button", "x15 y+5 w145 h35", "➕ Serviço ANÁLISE")
    BtnNovoServAn.Dica := "Cria um novo agrupamento (arquivo) em branco para Análise."
    BtnNovoServAn.OnEvent("Click", (*) => CriarNovoServico(DirAnalise))

    BtnNovoServEx := G_Edit.Add("Button", "x+6 yp w145 h35", "➕ Serviço EXIG.")
    BtnNovoServEx.Dica := "Cria um novo agrupamento (arquivo) em branco para Exigências."
    BtnNovoServEx.OnEvent("Click", (*) => CriarNovoServico(DirExigencias))

    BtnClonarServ := G_Edit.Add("Button", "x+6 yp w145 h35", "📋 CLONAR Serviço")
    BtnClonarServ.Dica := "Copia a estrutura vazia ou o texto completo de um serviço existente."
    BtnClonarServ.OnEvent("Click", AbrirClonarServico)

    BtnDelServico := G_Edit.Add("Button", "x+6 yp w145 h35", "🗑️ EXCLUIR Serviço")
    BtnDelServico.Dica := "Exclui um serviço inteiro do sistema permanentemente."
    BtnDelServico.OnEvent("Click", ExcluirServico)

    BtnVoltarE := G_Edit.Add("Button", "x15 y+15 w600 h35", "⬅️ VOLTAR AO MENU PRINCIPAL")
    BtnVoltarE.Dica := "Volta para a tela de escolhas."
    BtnVoltarE.OnEvent("Click", (*) => (G_Edit.Destroy(), AbrirMenuPrincipal()))

    G_Edit.Show("AutoSize Center")
    FiltrarTitulos_Editor()
}

FiltrarTitulos_Editor(*) {
    Global LV_Titulos, Busca_Ed, TitulosUnicos
    LV_Titulos.Delete()
    termo := Busca_Ed.Value
    for tit in TitulosUnicos {
        if (termo == "" || InStr(tit, termo, false))
            LV_Titulos.Add(, tit)
    }
}

CarregarTextoEArquivos(ctrl, Item, *) {
    Global LV_Titulos, Titulo_Edit, Texto_Edit, LV_Arquivos, TitulosMapArquivos, LV_Partes, TopicoCarregado
    if (Item == 0)
        return

    topicoAlvo := LV_Titulos.GetText(Item)

    TopicoCarregado := {tit: topicoAlvo, txtOriginal: "", txtPrincipal: "", subs: []}

    LV_Arquivos.Delete()
    if TitulosMapArquivos.Has(topicoAlvo) {
        for arq in TitulosMapArquivos[topicoAlvo] {
            SplitPath arq, &nomeArq, &dirArq
            prefixo := InStr(dirArq, "Exigencias") ? "[Exigência] " : "[Análise] "
            LV_Arquivos.Add("Check", prefixo . nomeArq, arq)
        }
    }

    if (LV_Arquivos.GetCount() > 0) {
        caminhoPrimeiroArq := LV_Arquivos.GetText(1, 2)
        Conteudo := FileRead(caminhoPrimeiroArq, "UTF-8")
        achou := false

        cTxt := ""
        cSubs := []
        isSub := false
        curSub := unset

        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if InStr(linha, "TITULO::") == 1 {
                if (achou)
                    break
                achou := (Trim(SubStr(linha, 9)) == topicoAlvo) ? true : false
                continue
            }
            if (achou && RegExMatch(linha, "^\[.*\]$"))
                break

            if (achou) {
                if InStr(linha, "SUBTITULO::") == 1 {
                    if (isSub && IsSet(curSub))
                        cSubs.Push(curSub)
                    curSub := {t: Trim(SubStr(linha, 12)), c: ""}
                    isSub := true
                    continue
                }

                if (isSub && IsSet(curSub))
                    curSub.c .= linha "`n"
                else
                    cTxt .= linha "`n"
            }
        }
        if (isSub && IsSet(curSub))
            cSubs.Push(curSub)

        TopicoCarregado.txtPrincipal := Trim(cTxt, "`n`r ")
        TopicoCarregado.subs := cSubs
    }

    AtualizarLVPartes()
}

AtualizarLVPartes() {
    Global LV_Partes, TopicoCarregado, Titulo_Edit, Texto_Edit
    LV_Partes.Delete()
    if (!IsSet(TopicoCarregado) || !TopicoCarregado.HasProp("tit"))
        return

    LV_Partes.Add(, TopicoCarregado.tit, "Principal", 0)
    for i, sub in TopicoCarregado.subs {
        LV_Partes.Add(, sub.t, "Subtópico", i)
    }

    Titulo_Edit.Value := ""
    Texto_Edit.Value := ""
}

AoClicarParte(ctrl, Item, *) {
    Global LV_Partes, TopicoCarregado, Titulo_Edit, Texto_Edit
    if (Item == 0)
        return

    tipo := LV_Partes.GetText(Item, 2)
    idx := Integer(LV_Partes.GetText(Item, 3))

    if (tipo == "Principal") {
        Titulo_Edit.Value := TopicoCarregado.tit
        Texto_Edit.Value := TopicoCarregado.txtPrincipal
    } else {
        Titulo_Edit.Value := TopicoCarregado.subs[idx].t
        Texto_Edit.Value := Trim(TopicoCarregado.subs[idx].c, "`n`r ")
    }
}

SalvarEdicaoParte(*) {
    Global LV_Partes, TopicoCarregado, Titulo_Edit, Texto_Edit
    linhaSel := LV_Partes.GetNext(0)
    if (linhaSel == 0)
        return

    tipo := LV_Partes.GetText(linhaSel, 2)
    idx := Integer(LV_Partes.GetText(linhaSel, 3))

    if (tipo == "Principal") {
        TopicoCarregado.tit := Titulo_Edit.Value
        TopicoCarregado.txtPrincipal := Texto_Edit.Value
        LV_Partes.Modify(linhaSel, , Titulo_Edit.Value)
    } else {
        TopicoCarregado.subs[idx].t := Titulo_Edit.Value
        TopicoCarregado.subs[idx].c := Texto_Edit.Value
        LV_Partes.Modify(linhaSel, , Titulo_Edit.Value)
    }
}

AdicionarSubtopico(*) {
    Global TopicoCarregado, LV_Partes
    if (!IsSet(TopicoCarregado) || !TopicoCarregado.HasProp("tit"))
        return MsgBox("Selecione um tópico primeiro!", "Aviso", "Icon!")

    novoSub := {t: "Novo Subtópico", c: ""}
    TopicoCarregado.subs.Push(novoSub)
    AtualizarLVPartes()
    LV_Partes.Modify(LV_Partes.GetCount(), "Select Focus")
    AoClicarParte(LV_Partes, LV_Partes.GetCount())
}

ExcluirSubtopico(*) {
    Global LV_Partes, TopicoCarregado
    linhaSel := LV_Partes.GetNext(0)
    if (linhaSel == 0)
        return MsgBox("Selecione um subtópico para excluir!", "Aviso", "Icon!")

    tipo := LV_Partes.GetText(linhaSel, 2)
    idx := Integer(LV_Partes.GetText(linhaSel, 3))

    if (tipo == "Principal")
        return MsgBox("Não é possível excluir o tópico principal por aqui. Use o botão 'EXCLUIR Tópico' na seção 5.", "Aviso", "Icon!")

    TopicoCarregado.subs.RemoveAt(idx)
    AtualizarLVPartes()
}

ExecutarSalvamento(salvarEmTodos) {
    Global LV_Titulos, LV_Arquivos, TitulosMapArquivos, TopicoCarregado
    linhaSel := LV_Titulos.GetNext(0)
    if (linhaSel == 0)
        return MsgBox("Selecione um tópico na lista primeiro!", "Aviso", "Icon!")

    if (!IsSet(TopicoCarregado) || !TopicoCarregado.HasProp("tit"))
        return MsgBox("Tópico não carregado corretamente!", "Erro", "Icon!")

    topicoOriginal := LV_Titulos.GetText(linhaSel)
    novoTitulo := TopicoCarregado.tit

    ; Construir o novo texto completo a partir do objeto TopicoCarregado
    novoTextoCompleto := TopicoCarregado.txtPrincipal
    for sub in TopicoCarregado.subs {
        novoTextoCompleto .= "`nSUBTITULO::" sub.t "`n" Trim(sub.c, "`n`r ")
    }
    novoTextoCompleto := Trim(novoTextoCompleto, "`n`r ")

    arquivosAlvo := Map()

    if (salvarEmTodos) {
        for arq in TitulosMapArquivos[topicoOriginal]
            arquivosAlvo[arq] := true
    } else {
        RowPos := 0
        Loop {
            RowPos := LV_Arquivos.GetNext(RowPos, "Checked")
            if (RowPos = 0)
                break
            arquivosAlvo[LV_Arquivos.GetText(RowPos, 2)] := true
        }
        if (arquivosAlvo.Count == 0)
            return MsgBox("Nenhum arquivo foi marcado para salvar.", "Aviso", "Icon!")
    }

    for caminho in arquivosAlvo {
        Conteudo := FileRead(caminho, "UTF-8")
        NovoConteudo := ""
        dentroDoTopico := false
        editouArquivo := false

        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if InStr(linha, "TITULO::") == 1 {
                if (Trim(SubStr(linha, 9)) == topicoOriginal) {
                    dentroDoTopico := true
                    editouArquivo := true
                    NovoConteudo .= "TITULO::" novoTitulo "`n" novoTextoCompleto "`n`n"
                    continue
                } else {
                    dentroDoTopico := false
                }
            }
            if (RegExMatch(linha, "^\[.*\]$"))
                dentroDoTopico := false

            if (!dentroDoTopico && linha != "")
                NovoConteudo .= linha "`n"
        }

        if (editouArquivo) {
            NovoConteudo := RegExReplace(NovoConteudo, "\n{3,}", "`n`n")
            FileDelete(caminho)
            FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminho, "UTF-8")
        }
    }

    if (topicoOriginal != novoTitulo)
        AtualizarRegrasRenomeadas(topicoOriginal, novoTitulo)

    MsgBox("Alterações salvas com sucesso!", "Concluído", "Iconi T3")
    RecarregarDadosGerais()
    Busca_Ed.Value := novoTitulo
    FiltrarTitulos_Editor()
}

ExecutarExclusaoTopico(*) {
    Global LV_Titulos, LV_Arquivos, TitulosMapArquivos
    linhaSel := LV_Titulos.GetNext(0)
    if (linhaSel == 0)
        return MsgBox("Selecione um tópico na lista para excluir!", "Aviso", "Icon!")

    topicoOriginal := LV_Titulos.GetText(linhaSel)

    resp := MsgBox("Deseja EXCLUIR permanentemente o tópico:`n" topicoOriginal "`n`ndos arquivos marcados?", "Atenção", "YesNo Icon!")
    if resp != "Yes"
        return

    arquivosAlvo := Map()
    RowPos := 0
    Loop {
        RowPos := LV_Arquivos.GetNext(RowPos, "Checked")
        if (RowPos = 0)
            break
        arquivosAlvo[LV_Arquivos.GetText(RowPos, 2)] := true
    }
    if (arquivosAlvo.Count == 0)
        return MsgBox("Nenhum arquivo foi marcado.", "Aviso", "Icon!")

    for caminho in arquivosAlvo {
        Conteudo := FileRead(caminho, "UTF-8")
        NovoConteudo := ""
        dentroDoTopico := false
        editouArquivo := false

        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if InStr(linha, "TITULO::") == 1 {
                if (Trim(SubStr(linha, 9)) == topicoOriginal) {
                    dentroDoTopico := true
                    editouArquivo := true
                    continue
                } else {
                    dentroDoTopico := false
                }
            }
            if (RegExMatch(linha, "^\[.*\]$"))
                dentroDoTopico := false

            if (!dentroDoTopico && linha != "")
                NovoConteudo .= linha "`n"
        }

        if (editouArquivo) {
            NovoConteudo := RegExReplace(NovoConteudo, "\n{3,}", "`n`n")
            FileDelete(caminho)
            if (Trim(NovoConteudo) != "")
                FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminho, "UTF-8")
        }
    }

    RemoverRegraExcluida(topicoOriginal)
    MsgBox("Tópico excluído com sucesso!", "Concluído", "Iconi T3")
    RecarregarDadosGerais()
    FiltrarTitulos_Editor()
}

; ---- FUNÇÕES DE GESTÃO: GESTOR DE ABAS ----
AbrirGestorAbas(*) {
    Global G_Abas, Drop_GA_Arq, LB_GA_Abas, DirAnalise

    if IsSet(G_Abas) && G_Abas
        G_Abas.Destroy()

    G_Abas := Gui("", "Gerenciador de Abas (Categorias)")
    G_Abas.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Abas.SetFont("s10", "Segoe UI")

    G_Abas.Add("Text", "w400", "1. Selecione o Serviço de Análise:")
    listaArqs := []
    Loop Files, DirAnalise "\*.txt"
        listaArqs.Push(A_LoopFileName)

    Drop_GA_Arq := G_Abas.Add("DropDownList", "w400 Choose1", listaArqs)
    Drop_GA_Arq.OnEvent("Change", AtualizarListaAbasGA)

    G_Abas.Add("Text", "w400 y+10", "2. Abas Existentes:")
    LB_GA_Abas := G_Abas.Add("ListBox", "w400 r8")

    BtnNovaAba := G_Abas.Add("Button", "w130 h35 y+10", "➕ NOVA Aba")
    BtnNovaAba.OnEvent("Click", GANovaAba)

    BtnRenAba := G_Abas.Add("Button", "x+5 yp w130 h35", "✏️ RENOMEAR")
    BtnRenAba.OnEvent("Click", GARenomearAba)

    BtnDelAba := G_Abas.Add("Button", "x+5 yp w130 h35", "🗑️ EXCLUIR")
    BtnDelAba.OnEvent("Click", GAExcluirAba)

    AtualizarListaAbasGA()
    G_Abas.Show("AutoSize Center")
}

AtualizarListaAbasGA(*) {
    Global Drop_GA_Arq, LB_GA_Abas, DirAnalise
    LB_GA_Abas.Delete()
    arq := Drop_GA_Arq.Text
    if (arq == "")
        return

    Conteudo := FileRead(DirAnalise "\" arq, "UTF-8")
    abas := []
    Loop Parse, Conteudo, "`n", "`r" {
        if RegExMatch(Trim(A_LoopField), "^\[(.*)\]$", &Match)
            abas.Push(Match[1])
    }
    if (abas.Length > 0)
        LB_GA_Abas.Add(abas)
}

GANovaAba(*) {
    Global Drop_GA_Arq, DirAnalise
    arq := Drop_GA_Arq.Text
    if (arq == "")
        return

    ib := InputBox("Digite o nome da NOVA ABA (ex: Outros):", "Nova Aba", "w350 h100")
    if (ib.Result == "OK" && Trim(ib.Value) != "") {
        nomeAba := Trim(ib.Value)
        caminho := DirAnalise "\" arq
        FileAppend("`n`n[" nomeAba "]`n", caminho, "UTF-8")
        MsgBox("Aba adicionada com sucesso!", "Sucesso", "Iconi")
        AtualizarListaAbasGA()
        RecarregarDadosGerais()
    }
}

GARenomearAba(*) {
    Global Drop_GA_Arq, LB_GA_Abas, DirAnalise
    arq := Drop_GA_Arq.Text
    abaAntiga := LB_GA_Abas.Text
    if (abaAntiga == "")
        return MsgBox("Selecione uma aba na lista primeiro!", "Aviso", "Icon!")

    ib := InputBox("Digite o NOVO NOME para a aba [" abaAntiga "]:", "Renomear Aba", "w350 h100", abaAntiga)
    if (ib.Result == "OK" && Trim(ib.Value) != "" && Trim(ib.Value) != abaAntiga) {
        abaNova := Trim(ib.Value)
        caminho := DirAnalise "\" arq
        Conteudo := FileRead(caminho, "UTF-8")
        NovoConteudo := ""

        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if (linha == "[" abaAntiga "]")
                NovoConteudo .= "[" abaNova "]`n"
            else
                NovoConteudo .= linha "`n"
        }

        FileDelete(caminho)
        FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminho, "UTF-8")
        MsgBox("Aba renomeada com sucesso!", "Sucesso", "Iconi")
        AtualizarListaAbasGA()
        RecarregarDadosGerais()
    }
}

GAExcluirAba(*) {
    Global Drop_GA_Arq, LB_GA_Abas, DirAnalise
    arq := Drop_GA_Arq.Text
    abaExcluir := LB_GA_Abas.Text
    if (abaExcluir == "")
        return MsgBox("Selecione uma aba na lista primeiro!", "Aviso", "Icon!")

    resp := MsgBox("ATENÇÃO: Deseja EXCLUIR a aba [" abaExcluir "] e TODOS os tópicos dentro dela no arquivo " arq "?`n`nEssa ação não pode ser desfeita.", "Excluir Aba", "YesNo Icon!")
    if (resp == "Yes") {
        caminho := DirAnalise "\" arq
        Conteudo := FileRead(caminho, "UTF-8")
        NovoConteudo := ""
        dentroDaAba := false

        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)

            if RegExMatch(linha, "^\[(.*)\]$", &Match) {
                if (Match[1] == abaExcluir) {
                    dentroDaAba := true
                    continue
                } else {
                    dentroDaAba := false
                }
            }

            if (!dentroDaAba)
                NovoConteudo .= linha "`n"
        }

        NovoConteudo := RegExReplace(NovoConteudo, "\n{3,}", "`n`n")
        FileDelete(caminho)
        FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminho, "UTF-8")

        MsgBox("Aba e seus tópicos foram excluídos!", "Sucesso", "Iconi")
        AtualizarListaAbasGA()
        RecarregarDadosGerais()
    }
}

; ---- FUNÇÕES DE GESTÃO: GESTOR DE ORDEM ----
AbrirGestorOrdem(*) {
    Global G_Ord, Drop_Ord_Arq, LB_Ord_Abas, LB_Ord_Tops, DadosOrdem, DirAnalise, DirExigencias

    if IsSet(G_Ord) && G_Ord
        G_Ord.Destroy()

    G_Ord := Gui("", "Gestor de Ordem - Mover Abas e Tópicos")
    G_Ord.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Ord.SetFont("s10", "Segoe UI")

    G_Ord.Add("Text", "x15 y15 w600", "1. Selecione o Arquivo (Serviço) para organizar:")
    listaArqs := []
    Loop Files, DirExigencias "\*.txt"
        listaArqs.Push("[Exigência] " A_LoopFileName)
    Loop Files, DirAnalise "\*.txt"
        listaArqs.Push("[Análise] " A_LoopFileName)

    Drop_Ord_Arq := G_Ord.Add("DropDownList", "x15 y35 w600 Choose1", listaArqs)
    Drop_Ord_Arq.OnEvent("Change", CarregarDadosOrdem)

    G_Ord.Add("Text", "x15 y75 w180", "2. Reordenar Abas:")
    G_Ord.Add("Text", "x255 y75 w180", "3. Reordenar Tópicos:")
    G_Ord.Add("Text", "x495 y75 w180", "4. Reordenar Subtópicos:")

    LB_Ord_Abas := G_Ord.Add("ListBox", "x15 y95 w180 r12")
    LB_Ord_Abas.OnEvent("Change", AtualizarTopsOrdem)

    BtnSubA := G_Ord.Add("Button", "x200 y95 w35 h40", "▲")
    BtnSubA.OnEvent("Click", (*) => MoverAbaOrdem(-1))
    BtnDesA := G_Ord.Add("Button", "x200 y140 w35 h40", "▼")
    BtnDesA.OnEvent("Click", (*) => MoverAbaOrdem(1))

    LB_Ord_Tops := G_Ord.Add("ListBox", "x255 y95 w180 r12")
    LB_Ord_Tops.OnEvent("Change", AtualizarSubsOrdem)

    BtnSubT := G_Ord.Add("Button", "x440 y95 w35 h40", "▲")
    BtnSubT.OnEvent("Click", (*) => MoverTopOrdem(-1))
    BtnDesT := G_Ord.Add("Button", "x440 y140 w35 h40", "▼")
    BtnDesT.OnEvent("Click", (*) => MoverTopOrdem(1))

    LB_Ord_Subs := G_Ord.Add("ListBox", "x495 y95 w180 r12")

    BtnSubS := G_Ord.Add("Button", "x680 y95 w35 h40", "▲")
    BtnSubS.OnEvent("Click", (*) => MoverSubOrdem(-1))
    BtnDesS := G_Ord.Add("Button", "x680 y140 w35 h40", "▼")
    BtnDesS.OnEvent("Click", (*) => MoverSubOrdem(1))

    BtnSalvarOrd := G_Ord.Add("Button", "x15 y300 w700 h45 Default", "💾 SALVAR NOVA ORDEM NO ARQUIVO")
    BtnSalvarOrd.OnEvent("Click", SalvarDadosOrdem)

    CarregarDadosOrdem()
    G_Ord.Show("AutoSize Center")
}

CarregarDadosOrdem(*) {
    Global Drop_Ord_Arq, LB_Ord_Abas, LB_Ord_Tops, LB_Ord_Subs, DadosOrdem, DirAnalise, DirExigencias
    sel := Drop_Ord_Arq.Text
    if (sel == "")
        return

    isExig := InStr(sel, "[Exigência]")
    arqNome := Trim(SubStr(sel, InStr(sel, "]")+1))
    caminho := isExig ? (DirExigencias "\" arqNome) : (DirAnalise "\" arqNome)

    Conteudo := FileRead(caminho, "UTF-8")
    DadosOrdem := []
    AbaAtual := {nome: "[Geral]", header: "", tops: []}
    TopAtual := unset
    SubAtual := unset

    Loop Parse, Conteudo, "`n", "`r" {
        linha := Trim(A_LoopField)

        if RegExMatch(linha, "^\[(.*)\]$", &Match) {
            if (AbaAtual.nome != "[Geral]" || AbaAtual.tops.Length > 0 || Trim(AbaAtual.header) != "")
                DadosOrdem.Push(AbaAtual)
            AbaAtual := {nome: linha, header: "", tops: []}
            TopAtual := unset
            SubAtual := unset
        }
        else if InStr(linha, "TITULO::") == 1 {
            TopAtual := {tit: Trim(SubStr(linha, 9)), txtPrincipal: "", subs: []}
            AbaAtual.tops.Push(TopAtual)
            SubAtual := unset
        }
        else if InStr(linha, "SUBTITULO::") == 1 {
            if IsSet(TopAtual) {
                SubAtual := {tit: Trim(SubStr(linha, 12)), txt: ""}
                TopAtual.subs.Push(SubAtual)
            }
        }
        else {
            if IsSet(SubAtual)
                SubAtual.txt .= linha "`n"
            else if IsSet(TopAtual)
                TopAtual.txtPrincipal .= linha "`n"
            else
                AbaAtual.header .= linha "`n"
        }
    }
    if (AbaAtual.nome != "[Geral]" || AbaAtual.tops.Length > 0 || Trim(AbaAtual.header) != "")
        DadosOrdem.Push(AbaAtual)

    LB_Ord_Abas.Delete()
    for a in DadosOrdem
        LB_Ord_Abas.Add([a.nome])

    if (DadosOrdem.Length > 0)
        LB_Ord_Abas.Choose(1)
    AtualizarTopsOrdem()
}

AtualizarTopsOrdem(*) {
    Global LB_Ord_Abas, LB_Ord_Tops, DadosOrdem
    idxAba := LB_Ord_Abas.Value
    LB_Ord_Tops.Delete()
    if (idxAba > 0 && idxAba <= DadosOrdem.Length) {
        for t in DadosOrdem[idxAba].tops
            LB_Ord_Tops.Add([t.tit])
    }
    if (DadosOrdem[idxAba].tops.Length > 0)
        LB_Ord_Tops.Choose(1)
    AtualizarSubsOrdem()
}

AtualizarSubsOrdem(*) {
    Global LB_Ord_Abas, LB_Ord_Tops, LB_Ord_Subs, DadosOrdem
    idxAba := LB_Ord_Abas.Value
    idxTop := LB_Ord_Tops.Value
    LB_Ord_Subs.Delete()
    if (idxAba > 0 && idxTop > 0) {
        for s in DadosOrdem[idxAba].tops[idxTop].subs
            LB_Ord_Subs.Add([s.tit])
    }
}

MoverAbaOrdem(dir) {
    Global LB_Ord_Abas, DadosOrdem
    idx := LB_Ord_Abas.Value
    if (idx == 0 || (dir == -1 && idx == 1) || (dir == 1 && idx == DadosOrdem.Length))
        return

    temp := DadosOrdem[idx]
    DadosOrdem[idx] := DadosOrdem[idx + dir]
    DadosOrdem[idx + dir] := temp

    LB_Ord_Abas.Delete()
    for a in DadosOrdem
        LB_Ord_Abas.Add([a.nome])
    LB_Ord_Abas.Choose(idx + dir)
    AtualizarTopsOrdem()
}

MoverTopOrdem(dir) {
    Global LB_Ord_Abas, LB_Ord_Tops, DadosOrdem
    idxAba := LB_Ord_Abas.Value
    idxTop := LB_Ord_Tops.Value
    if (idxAba == 0 || idxTop == 0)
        return

    topsRef := DadosOrdem[idxAba].tops
    if ((dir == -1 && idxTop == 1) || (dir == 1 && idxTop == topsRef.Length))
        return

    temp := topsRef[idxTop]
    topsRef[idxTop] := topsRef[idxTop + dir]
    topsRef[idxTop + dir] := temp

    LB_Ord_Tops.Delete()
    for t in topsRef
        LB_Ord_Tops.Add([t.tit])
    LB_Ord_Tops.Choose(idxTop + dir)
    AtualizarSubsOrdem()
}

MoverSubOrdem(dir) {
    Global LB_Ord_Abas, LB_Ord_Tops, LB_Ord_Subs, DadosOrdem
    idxAba := LB_Ord_Abas.Value
    idxTop := LB_Ord_Tops.Value
    idxSub := LB_Ord_Subs.Value
    if (idxAba == 0 || idxTop == 0 || idxSub == 0)
        return

    subsRef := DadosOrdem[idxAba].tops[idxTop].subs
    if ((dir == -1 && idxSub == 1) || (dir == 1 && idxSub == subsRef.Length))
        return

    temp := subsRef[idxSub]
    subsRef[idxSub] := subsRef[idxSub + dir]
    subsRef[idxSub + dir] := temp

    LB_Ord_Subs.Delete()
    for s in subsRef
        LB_Ord_Subs.Add([s.tit])
    LB_Ord_Subs.Choose(idxSub + dir)
}

SalvarDadosOrdem(*) {
    Global Drop_Ord_Arq, DadosOrdem, DirAnalise, DirExigencias
    sel := Drop_Ord_Arq.Text
    isExig := InStr(sel, "[Exigência]")
    arqNome := Trim(SubStr(sel, InStr(sel, "]")+1))
    caminho := isExig ? (DirExigencias "\" arqNome) : (DirAnalise "\" arqNome)

    NovoConteudo := ""
    for a in DadosOrdem {
        if (a.nome != "[Geral]")
            NovoConteudo .= "`n" a.nome "`n"
        if (Trim(a.header) != "")
            NovoConteudo .= Trim(a.header, "`n`r") "`n"

        for t in a.tops {
            NovoConteudo .= "TITULO::" t.tit "`n"
            NovoConteudo .= Trim(t.txtPrincipal, "`n`r") "`n"
            for s in t.subs {
                NovoConteudo .= "SUBTITULO::" s.tit "`n"
                NovoConteudo .= Trim(s.txt, "`n`r") "`n"
            }
            NovoConteudo .= "`n"
        }
    }

    NovoConteudo := RegExReplace(NovoConteudo, "\n{3,}", "`n`n")
    FileDelete(caminho)
    FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminho, "UTF-8")

    MsgBox("Nova ordem salva com sucesso!", "Concluído", "Iconi T3")
    RecarregarDadosGerais()
}

; ---- FUNÇÕES DE GESTÃO: NOVO TÓPICO ----
AbrirNovoTopico(*) {
    Global G_NovoT, Drop_NT_Arq, Drop_NT_Aba, Edit_NT_Tit, Edit_NT_Txt, DirAnalise, DirExigencias

    if IsSet(G_NovoT) && G_NovoT
        G_NovoT.Destroy()

    G_NovoT := Gui("", "Criar Novo Tópico")
    G_NovoT.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_NovoT.SetFont("s10", "Segoe UI")

    G_NovoT.Add("Text", "w500", "1. Onde deseja salvar? (Arquivo):")
    listaArqs := []
    Loop Files, DirExigencias "\*.txt"
        listaArqs.Push("[Exigência] " A_LoopFileName)
    Loop Files, DirAnalise "\*.txt"
        listaArqs.Push("[Análise] " A_LoopFileName)

    Drop_NT_Arq := G_NovoT.Add("DropDownList", "w500 Choose1", listaArqs)
    Drop_NT_Arq.OnEvent("Change", AtualizarAbasNovoTopico)

    G_NovoT.Add("Text", "w500 y+10", "2. Em qual Categoria/Aba? (Apenas para Análise):")
    Drop_NT_Aba := G_NovoT.Add("ComboBox", "w500", ["[Geral]"])

    G_NovoT.Add("Text", "w500 y+10", "3. Título do Novo Tópico:")
    Edit_NT_Tit := G_NovoT.Add("Edit", "w500")

    G_NovoT.Add("Text", "w500 y+10", "4. Texto do Tópico:")
    Edit_NT_Txt := G_NovoT.Add("Edit", "w500 h150")

    BtnSalvarNT := G_NovoT.Add("Button", "w500 h45 y+15 Default", "💾 ADICIONAR TÓPICO")
    BtnSalvarNT.OnEvent("Click", SalvarNovoTopico)

    AtualizarAbasNovoTopico()
    G_NovoT.Show("AutoSize Center")
}

AtualizarAbasNovoTopico(*) {
    Global Drop_NT_Arq, Drop_NT_Aba, DirAnalise, DirExigencias
    sel := Drop_NT_Arq.Text
    isExig := InStr(sel, "[Exigência]")
    arqNome := Trim(SubStr(sel, InStr(sel, "]")+1))

    Drop_NT_Aba.Delete()
    if (isExig) {
        Drop_NT_Aba.Add(["[Não se aplica para Exigências]"])
        Drop_NT_Aba.Choose(1)
        Drop_NT_Aba.Enabled := false
    } else {
        Drop_NT_Aba.Enabled := true
        Conteudo := FileRead(DirAnalise "\" arqNome, "UTF-8")
        abas := []
        Loop Parse, Conteudo, "`n", "`r" {
            if RegExMatch(Trim(A_LoopField), "^(\[.*\])$", &Match)
                abas.Push(Match[1])
        }
        if (abas.Length == 0)
            abas.Push("[Geral]")
        Drop_NT_Aba.Add(abas)
        Drop_NT_Aba.Choose(1)
    }
}

SalvarNovoTopico(*) {
    Global G_NovoT, Drop_NT_Arq, Drop_NT_Aba, Edit_NT_Tit, Edit_NT_Txt, DirAnalise, DirExigencias

    sel := Drop_NT_Arq.Text
    isExig := InStr(sel, "[Exigência]")
    arqNome := Trim(SubStr(sel, InStr(sel, "]")+1))
    abaSel := Trim(Drop_NT_Aba.Text)
    tit := Trim(Edit_NT_Tit.Value)
    txt := Trim(Edit_NT_Txt.Value)

    if (tit == "")
        return MsgBox("O título não pode ficar em branco!", "Erro", "Icon!")

    caminho := isExig ? (DirExigencias "\" arqNome) : (DirAnalise "\" arqNome)
    Conteudo := FileRead(caminho, "UTF-8")

    if (isExig) {
        FileAppend("`nTITULO::" tit "`n" txt "`n", caminho, "UTF-8")
    } else {
        if (!RegExMatch(abaSel, "^\[.*\]$"))
            abaSel := "[" abaSel "]"

        NovoConteudo := "", inseriu := false, abaEncontrada := false
        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            NovoConteudo .= linha "`n"
            if (!inseriu && linha == abaSel) {
                NovoConteudo .= "TITULO::" tit "`n" txt "`n`n"
                inseriu := true
                abaEncontrada := true
            }
        }
        if (!abaEncontrada)
            NovoConteudo .= "`n" abaSel "`nTITULO::" tit "`n" txt "`n"

        NovoConteudo := RegExReplace(NovoConteudo, "\n{3,}", "`n`n")
        FileDelete(caminho)
        FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminho, "UTF-8")
    }

    MsgBox("Novo tópico adicionado!", "Sucesso", "Iconi")
    G_NovoT.Destroy()
    RecarregarDadosGerais()
    FiltrarTitulos_Editor()
}

; ---- FUNÇÕES DE GESTÃO: CLONAR SERVIÇO ----
AbrirClonarServico(*) {
    Global G_Clone, Drop_Cl_Origem, Chk_Cl_Abas, Edit_Cl_Novo, DirAnalise, DirExigencias

    if IsSet(G_Clone) && G_Clone
        G_Clone.Destroy()

    G_Clone := Gui("", "Clonar Serviço Existente")
    G_Clone.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Clone.SetFont("s10", "Segoe UI")

    G_Clone.Add("Text", "w400", "1. Qual serviço base deseja copiar?")
    listaArqs := []
    Loop Files, DirExigencias "\*.txt"
        listaArqs.Push("[Exigência] " A_LoopFileName)
    Loop Files, DirAnalise "\*.txt"
        listaArqs.Push("[Análise] " A_LoopFileName)

    Drop_Cl_Origem := G_Clone.Add("DropDownList", "w400 Choose1", listaArqs)

    Chk_Cl_Abas := G_Clone.Add("Checkbox", "w400 y+10", "Copiar APENAS a estrutura de Abas/Categorias (Vazio)")

    G_Clone.Add("Text", "w400 y+10", "2. Nome do NOVO Serviço (sem '.txt'):")
    Edit_Cl_Novo := G_Clone.Add("Edit", "w400")

    BtnSalvar := G_Clone.Add("Button", "w400 h45 y+15 Default", "📋 CLONAR SERVIÇO")
    BtnSalvar.OnEvent("Click", ExecutarClone)

    G_Clone.Show("AutoSize Center")
}

ExecutarClone(*) {
    Global Drop_Cl_Origem, Chk_Cl_Abas, Edit_Cl_Novo, DirAnalise, DirExigencias, G_Clone
    origem := Drop_Cl_Origem.Text
    apenasAbas := Chk_Cl_Abas.Value
    novoNome := Trim(Edit_Cl_Novo.Value)

    if (novoNome == "")
        return MsgBox("Digite o nome do novo serviço!", "Erro", "Icon!")

    isExig := InStr(origem, "[Exigência]")
    arqNome := Trim(SubStr(origem, InStr(origem, "]")+1))

    caminhoOrigem := isExig ? (DirExigencias "\" arqNome) : (DirAnalise "\" arqNome)
    caminhoDestino := isExig ? (DirExigencias "\" novoNome ".txt") : (DirAnalise "\" novoNome ".txt")

    if FileExist(caminhoDestino)
        return MsgBox("Já existe um arquivo com este nome!", "Erro", "Icon!")

    Conteudo := FileRead(caminhoOrigem, "UTF-8")

    if (apenasAbas) {
        NovoConteudo := ""
        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if RegExMatch(linha, "^\[.*\]$")
                NovoConteudo .= linha "`n`n"
        }
        FileAppend(Trim(NovoConteudo, "`n`r ") "`n", caminhoDestino, "UTF-8")
    } else {
        FileCopy(caminhoOrigem, caminhoDestino)
    }

    MsgBox("Serviço clonado com sucesso!", "Sucesso", "Iconi")
    G_Clone.Destroy()
    RecarregarDadosGerais()
    AbrirEditorAmigavel()
}

; ---- FUNÇÕES DE GESTÃO: SERVIÇOS ----
CriarNovoServico(diretorioDestino) {
    tipo := (diretorioDestino == DirAnalise) ? "ANÁLISE" : "EXIGÊNCIA"
    ib := InputBox("Digite o nome do novo Serviço de " tipo " (sem '.txt'):", "Novo Serviço", "w350 h100")

    if (ib.Result == "OK" && Trim(ib.Value) != "") {
        caminho := diretorioDestino "\" Trim(ib.Value) ".txt"
        if FileExist(caminho)
            return MsgBox("Este serviço já existe!", "Erro", "Icon!")

        if (diretorioDestino == DirAnalise)
            FileAppend("[Motivos]`n`n[Outros]`n", caminho, "UTF-8")
        else
            FileAppend("", caminho, "UTF-8")

        MsgBox("Serviço de " tipo " criado com sucesso!", "Sucesso", "Iconi")
        RecarregarDadosGerais()
        AbrirEditorAmigavel()
    }
}

ExcluirServico(*) {
    Global DirAnalise, DirExigencias
    G_DelS := Gui("", "Excluir Serviço")
    G_DelS.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_DelS.SetFont("s10", "Segoe UI")
    G_DelS.Add("Text", "w350", "Selecione o Serviço para excluir:")

    lista := []
    Loop Files, DirExigencias "\*.txt"
        lista.Push("[Exigência] " A_LoopFileName)
    Loop Files, DirAnalise "\*.txt"
        lista.push("[Análise] " A_LoopFileName)

    Drop_Del := G_DelS.Add("DropDownList", "w350 Choose1", lista)
    BtnDel := G_DelS.Add("Button", "w350 h40 y+15", "🗑️ EXCLUIR PERMANENTEMENTE")
    BtnDel.OnEvent("Click", (*) => ExecutarDelServico(Drop_Del.Text, G_DelS))
    G_DelS.Show("AutoSize Center")
}

ExecutarDelServico(selecao, janela) {
    Global DirAnalise, DirExigencias
    isExig := InStr(selecao, "[Exigência]")
    arqNome := Trim(SubStr(selecao, InStr(selecao, "]")+1))
    caminho := isExig ? (DirExigencias "\" arqNome) : (DirAnalise "\" arqNome)

    resp := MsgBox("Certeza que deseja excluir o arquivo `n" arqNome "?", "Confirmação", "YesNo Icon!")
    if (resp == "Yes") {
        FileDelete(caminho)
        MsgBox("Serviço excluído!", "Sucesso", "Iconi")
        janela.Destroy()
        RecarregarDadosGerais()
        AbrirEditorAmigavel()
    }
}

; ==========================================
; MÓDULO 4: CONFIGURADOR DE REGRAS
; ==========================================
AbrirConfigMarcacoes(*) {
    Global G_Conf, Busca_Conf, LV_Gatilhos, LV_Alvos, Edit_RegrasAtuais, ArqRegras

    G_Conf := Gui("", "Gerenciador de Marcações Automáticas")
    G_Conf.OnEvent("Escape", (gui, *) => gui.Minimize())
    G_Conf.SetFont("s10", "Segoe UI")

    G_Conf.Add("Text", "w700", "🔎 Buscar (Filtra Gatilhos e Alvos simultaneamente):")
    Busca_Conf := G_Conf.Add("Edit", "w700")
    Busca_Conf.OnEvent("Change", FiltrarConfig)

    G_Conf.Add("Text", "w700 y+10", "1. Escolha o GATILHO (Clique na linha):")
    LV_Gatilhos := G_Conf.Add("ListView", "w700 r5 -Multi", ["Gatilho (O que você clica)"])
    LV_Gatilhos.ModifyCol(1, 670)
    LV_Gatilhos.OnEvent("Click", AoSelecionarGatilho)

    G_Conf.Add("Text", "w700 y+10", "2. Marque os ALVOS (O que marca sozinho):")
    LV_Alvos := G_Conf.Add("ListView", "w700 r8 Checked -Multi", ["Alvos (O que será marcado)"])
    LV_Alvos.ModifyCol(1, 670)

    BtnSalvarRegra := G_Conf.Add("Button", "w700 h40 y+10 Default", "💾 SALVAR / ATUALIZAR REGRA")
    BtnSalvarRegra.OnEvent("Click", SalvarRegra)

    G_Conf.Add("Text", "w700 y+15", "📜 REGRAS ATUAIS (Transparência):")
    Edit_RegrasAtuais := G_Conf.Add("Edit", "w700 h80 ReadOnly BackgroundF0F0F0")

    BtnVoltarC := G_Conf.Add("Button", "w700 h35 y+5", "⬅️ VOLTAR AO MENU")
    BtnVoltarC.OnEvent("Click", (*) => (G_Conf.Destroy(), AbrirMenuPrincipal()))

    G_Conf.Show("AutoSize Center")
    FiltrarConfig()
    AtualizarPainelRegras()
}

FiltrarConfig(*) {
    Global LV_Gatilhos, LV_Alvos, Busca_Conf, TitulosUnicos
    LV_Gatilhos.Delete()
    LV_Alvos.Delete()

    termo := Busca_Conf.Value
    for tit in TitulosUnicos {
        if (termo == "" || InStr(tit, termo, false)) {
            LV_Gatilhos.Add(, tit)
            LV_Alvos.Add(, tit)
        }
    }
}

AoSelecionarGatilho(ctrl, Item, *) {
    Global LV_Gatilhos, LV_Alvos, RegrasAutoCheck
    if (Item == 0)
        return

    gatilhoSel := LV_Gatilhos.GetText(Item)

    Loop LV_Alvos.GetCount()
        LV_Alvos.Modify(A_Index, "-Check")

    if RegrasAutoCheck.Has(gatilhoSel) {
        alvos := RegrasAutoCheck[gatilhoSel]
        Loop LV_Alvos.GetCount() {
            textoItem := LV_Alvos.GetText(A_Index)
            for alvo in alvos {
                if (textoItem == alvo)
                    LV_Alvos.Modify(A_Index, "Check")
            }
        }
    }
}

SalvarRegra(*) {
    Global LV_Gatilhos, LV_Alvos, RegrasAutoCheck, ArqRegras
    linhaGatilho := LV_Gatilhos.GetNext(0)

    if (linhaGatilho == 0)
        return MsgBox("Selecione um GATILHO na primeira lista!", "Aviso", "Icon!")

    gatilho := LV_Gatilhos.GetText(linhaGatilho)
    novosAlvos := []

    RowPos := 0
    Loop {
        RowPos := LV_Alvos.GetNext(RowPos, "Checked")
        if (RowPos = 0)
            break
        novosAlvos.Push(LV_Alvos.GetText(RowPos))
    }

    if (novosAlvos.Length > 0)
        RegrasAutoCheck[gatilho] := novosAlvos
    else
        if RegrasAutoCheck.Has(gatilho)
            RegrasAutoCheck.Delete(gatilho)

    TextoRegras := ""
    for gat, alvs in RegrasAutoCheck {
        linha := gat "|"
        for a in alvs
            linha .= a "|"
        TextoRegras .= RTrim(linha, "|") "`n"
    }

    if FileExist(ArqRegras)
        FileDelete(ArqRegras)
    if (TextoRegras != "")
        FileAppend(Trim(TextoRegras, "`n`r "), ArqRegras, "UTF-8")

    MsgBox("Regra gravada/atualizada!", "Sucesso", "Iconi T3")
    AtualizarPainelRegras()
}

AtualizarPainelRegras() {
    Global Edit_RegrasAtuais, RegrasAutoCheck
    txt := ""
    for gat, alvs in RegrasAutoCheck {
        txt .= "SE MARCAR: [" gat "] >> MARCA JUNTO: "
        for a in alvs
            txt .= "[" a "], "
        txt := RTrim(txt, ", ") "`n`n"
    }
    if (txt == "")
        txt := "Nenhuma regra configurada no momento."
    Edit_RegrasAtuais.Value := txt
}

AtualizarRegrasRenomeadas(antigo, novo) {
    Global RegrasAutoCheck, ArqRegras
    mudouAlgo := false, NovasRegras := Map()
    for gat, alvs in RegrasAutoCheck {
        novoGat := (gat == antigo) ? novo : gat
        novosAlvs := []
        for a in alvs {
            if (a == antigo) {
                novosAlvs.Push(novo)
                mudouAlgo := true
            } else {
                novosAlvs.Push(a)
            }
        }
        if (gat == antigo)
            mudouAlgo := true
        NovasRegras[novoGat] := novosAlvs
    }
    if (mudouAlgo) {
        RegrasAutoCheck := NovasRegras
        TextoRegras := ""
        for gat, alvs in RegrasAutoCheck {
            linha := gat "|"
            for a in alvs
                linha .= a "|"
            TextoRegras .= RTrim(linha, "|") "`n"
        }
        if FileExist(ArqRegras)
            FileDelete(ArqRegras)
        if (TextoRegras != "")
            FileAppend(Trim(TextoRegras, "`n`r "), ArqRegras, "UTF-8")
    }
}

RemoverRegraExcluida(alvo) {
    Global RegrasAutoCheck, ArqRegras
    mudouAlgo := false, NovasRegras := Map()
    for gat, alvs in RegrasAutoCheck {
        if (gat == alvo) {
            mudouAlgo := true
            continue
        }
        novosAlvs := []
        for a in alvs {
            if (a == alvo)
                mudouAlgo := true
            else
                novosAlvs.Push(a)
        }
        if (novosAlvs.Length > 0)
            NovasRegras[gat] := novosAlvs
    }
    if (mudouAlgo) {
        RegrasAutoCheck := NovasRegras
        TextoRegras := ""
        for gat, alvs in RegrasAutoCheck {
            linha := gat "|"
            for a in alvs
                linha .= a "|"
            TextoRegras .= RTrim(linha, "|") "`n"
        }
        if FileExist(ArqRegras)
            FileDelete(ArqRegras)
        if (TextoRegras != "")
            FileAppend(Trim(TextoRegras, "`n`r "), ArqRegras, "UTF-8")
    }
}

; ==========================================
; MOTOR CENTRAL DE CARREGAMENTO DE DADOS
; ==========================================
RecarregarDadosGerais() {
    Global BancoExigencias := Map(), ListaServicosExig := []
    Global BancoServicos := Map(), ListaServicos := []
    Global TitulosUnicos := [], TitulosMapArquivos := Map()

    LerArqExigencias()
    LerArqAnalise()
    LerRegrasAutoCheck()
}

AdicionarAoMapaTitulos(tit, caminho) {
    Global TitulosUnicos, TitulosMapArquivos
    jaTem := false
    for t in TitulosUnicos {
        if (t == tit)
            jaTem := true
    }
    if (!jaTem)
        TitulosUnicos.Push(tit)

    if !TitulosMapArquivos.Has(tit)
        TitulosMapArquivos[tit] := []

    jaTemArquivo := false
    for arq in TitulosMapArquivos[tit] {
        if (arq == caminho)
            jaTemArquivo := true
    }
    if (!jaTemArquivo)
        TitulosMapArquivos[tit].Push(caminho)
}

LerArqExigencias() {
    Global BancoExigencias, ListaServicosExig, DirExigencias
    Loop Files, DirExigencias "\*.txt" {
        cServ := RegExReplace(A_LoopFileName, "\.txt$")
        BancoExigencias[cServ] := []
        ListaServicosExig.Push(cServ)

        caminho := A_LoopFileFullPath
        Conteudo := FileRead(caminho, "UTF-8")

        cTit := "", cTxt := "", cSubs := [], isSub := false, curSub := unset
        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if linha = ""
                continue

            if InStr(linha, "TITULO::") == 1 {
                if (cTit != "") {
                    if (isSub && IsSet(curSub)) {
                        cSubs.Push(curSub)
                        isSub := false
                    }
                    BancoExigencias[cServ].Push({t: cTit, c: Trim(cTxt, "`n`r "), subs: cSubs})
                }
                cTit := Trim(SubStr(linha, 9))
                cTxt := ""
                cSubs := []
                isSub := false
                AdicionarAoMapaTitulos(cTit, caminho)
                continue
            }
            if InStr(linha, "SUBTITULO::") == 1 {
                if (isSub && IsSet(curSub)) {
                    cSubs.Push(curSub)
                }
                curSub := {t: Trim(SubStr(linha, 12)), c: ""}
                isSub := true
                continue
            }

            if (isSub && IsSet(curSub))
                curSub.c .= linha "`n"
            else if (cTit != "")
                cTxt .= linha "`n"
        }
        if (cTit != "") {
            if (isSub && IsSet(curSub)) {
                cSubs.Push(curSub)
            }
            BancoExigencias[cServ].Push({t: cTit, c: Trim(cTxt, "`n`r "), subs: cSubs})
        }
    }
}

LerArqAnalise() {
    Global BancoServicos, ListaServicos, DirAnalise
    Loop Files, DirAnalise "\*.txt" {
        cServ := RegExReplace(A_LoopFileName, "\.txt$")
        BancoServicos[cServ] := []
        ListaServicos.Push(cServ)

        caminho := A_LoopFileFullPath
        Conteudo := FileRead(caminho, "UTF-8")
        cAba := unset, cTit := "", cTxt := "", cSubs := [], isSub := false, curSub := unset

        Loop Parse, Conteudo, "`n", "`r" {
            linha := Trim(A_LoopField)
            if linha = ""
                continue

            if RegExMatch(linha, "^\[(.*)\]$", &Match) {
                SalvarUltimoAn(&cServ, &cAba, &cTit, &cTxt, &cSubs)
                nomeAba := Trim(Match[1])
                novaAba := {nome: nomeAba, itens: []}
                BancoServicos[cServ].Push(novaAba)
                cAba := novaAba
                isSub := false
                continue
            }

            if InStr(linha, "TITULO::") == 1 {
                SalvarUltimoAn(&cServ, &cAba, &cTit, &cTxt, &cSubs)
                cTit := Trim(SubStr(linha, 9))
                cTxt := ""
                cSubs := []
                isSub := false
                AdicionarAoMapaTitulos(cTit, caminho)
                continue
            }

            if InStr(linha, "SUBTITULO::") == 1 {
                if (isSub && IsSet(curSub))
                    cSubs.Push(curSub)
                curSub := {t: Trim(SubStr(linha, 12)), c: ""}
                isSub := true
                continue
            }

            if (isSub && IsSet(curSub))
                curSub.c .= linha "`n"
            else if (cTit != "")
                cTxt .= linha "`n"
        }
        if (isSub && IsSet(curSub))
            cSubs.Push(curSub)
        SalvarUltimoAn(&cServ, &cAba, &cTit, &cTxt, &cSubs)
    }
}

SalvarUltimoAn(&serv, &abaObj, &tit, &txt, &subs) {
    if (serv != "" && IsSet(abaObj) && tit != "") {
        abaObj.itens.Push({t: tit, c: Trim(txt, "`n`r "), subs: subs})
        tit := ""
        txt := ""
        subs := []
    }
}

LerRegrasAutoCheck() {
    Global RegrasAutoCheck, ArqRegras
    RegrasAutoCheck := Map()
    if FileExist(ArqRegras) {
        Conteudo := FileRead(ArqRegras, "UTF-8")
        Loop Parse, Conteudo, "`n", "`r" {
            partes := StrSplit(A_LoopField, "|")
            if (partes.Length > 1) {
                gatilho := partes[1]
                alvos := []
                Loop partes.Length - 1
                    alvos.Push(partes[A_Index + 1])
                RegrasAutoCheck[gatilho] := alvos
            }
        }
    }
}

CriarPadraoExigencias() {
    FileAppend("", DirExigencias "\exigencias_inss.txt", "UTF-8")
}

CriarPadraoAnalise() {
    DirCreate(DirAnalise)
}

GetIndex(arr, val, checkOnly := false) {
    for i, v in arr {
        if (v == val)
            return i
    }
    return checkOnly ? false : 1
}

; ==========================================
; MOTOR DO TOOLTIP (BALÃO EXPLICATIVO)
; ==========================================
ControleTooltip(wParam, lParam, msg, hwnd) {
    static hwndHover := 0
    if (hwnd == hwndHover)
        return
    hwndHover := hwnd
    try {
        ctrl := GuiCtrlFromHwnd(hwnd)
        if (ctrl && ctrl.HasProp("Dica"))
            ToolTip(ctrl.Dica)
        else
            ToolTip()
    } catch {
        ToolTip()
    }
}
