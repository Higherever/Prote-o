package ui

import (
	"log"

	"github.com/gotk3/gotk3/gdk"
	"github.com/gotk3/gotk3/gtk"
)

// Dimensões padrão da janela
const (
	LarguraJanela = 800
	AlturaJanela  = 600
)

// CriarJanelaPrincipal cria e configura a janela principal da aplicação
func CriarJanelaPrincipal(app *gtk.Application) {
	// Aplica CSS global
	AplicarCSS()

	// Cria a janela da aplicação
	win, err := gtk.ApplicationWindowNew(app)
	if err != nil {
		log.Fatal("Erro ao criar janela:", err)
	}

	win.SetTitle("Proteção")
	win.SetDefaultSize(LarguraJanela, AlturaJanela)
	win.SetName("janela-principal")

	// Remove decoração nativa do sistema (frameless)
	win.SetDecorated(false)

	// Permite redimensionamento
	win.SetResizable(true)

	// Habilita transparência para cantos arredondados via CSS
	screen := win.GetScreen()
	visual, _ := screen.GetRGBAVisual()
	if visual != nil {
		win.SetVisual(visual)
	}
	win.SetAppPaintable(true)

	// === Layout principal ===
	// Box vertical: barra de título + conteúdo
	layoutPrincipal, _ := gtk.BoxNew(gtk.ORIENTATION_VERTICAL, 0)

	// --- Barra de título personalizada (dentro de EventBox para drag) ---
	barraTitulo, evtBox := criarBarraTitulo(win)
	_ = barraTitulo
	layoutPrincipal.PackStart(evtBox, false, false, 0)

	// --- Overlay: vagalumes (fundo) + conteúdo (frente) ---
	overlay, _ := gtk.OverlayNew()
	overlay.SetVExpand(true)
	overlay.SetHExpand(true)

	// Canvas para vagalumes (fundo da janela)
	areaDesenho, _ := gtk.DrawingAreaNew()
	areaDesenho.SetVExpand(true)
	areaDesenho.SetHExpand(true)
	overlay.Add(areaDesenho)

	// Inicia animação dos vagalumes
	motorVagalumes := NovoMotorVagalumes(areaDesenho, 40) // 40 vagalumes
	motorVagalumes.Iniciar()

	// --- Container para as fases (boas-vindas → opções → progresso) ---
	containerFases, _ := gtk.BoxNew(gtk.ORIENTATION_VERTICAL, 0)
	containerFases.SetVExpand(true)
	containerFases.SetHExpand(true)

	// Cria a tela de progresso (fase 3) — inicialmente oculta
	telaProgresso := NovaTelaProgresso()
	containerFases.PackStart(telaProgresso.ObterWidget(), true, true, 0)

	// Variável para referência cruzada nos callbacks
	var telaOpcoes *TelaOpcoes

	// Cria a tela de opções (fase 2) — inicialmente oculta
	telaOpcoes = NovaTelaOpcoes(func(funcao string) {
		// Callback ao escolher uma opção — transição para tela de progresso
		log.Println("Opção escolhida:", funcao)
		telaOpcoes.Esconder()
		telaProgresso.Mostrar()
	})
	containerFases.PackStart(telaOpcoes.ObterWidget(), true, true, 0)

	// Cria a tela de boas-vindas (fase 1) — visível inicialmente
	telaBoasVindas := NovaTelaBoasVindas(func() {
		// Callback ao finalizar boas-vindas — mostra as opções
		telaOpcoes.Mostrar()
	})
	containerFases.PackStart(telaBoasVindas.ObterWidget(), true, true, 0)

	// Adiciona o container de fases no overlay (por cima dos vagalumes)
	overlay.AddOverlay(containerFases)

	layoutPrincipal.PackStart(overlay, true, true, 0)
	win.Add(layoutPrincipal)

	// Inicia a tela de boas-vindas
	telaBoasVindas.Iniciar()

	win.ShowAll()

	// Esconde fases que não devem estar visíveis no início
	telaOpcoes.ObterWidget().Hide()
	telaProgresso.ObterWidget().Hide()
}

// criarBarraTitulo cria a barra de título personalizada com botões fechar/minimizar/maximizar
// Retorna a barra e o EventBox que envolve tudo (para arrastar a janela)
func criarBarraTitulo(win *gtk.ApplicationWindow) (*gtk.Box, *gtk.EventBox) {
	barra, _ := gtk.BoxNew(gtk.ORIENTATION_HORIZONTAL, 0)
	barra.SetName("barra-titulo")

	// Título da aplicação (à esquerda)
	titulo, _ := gtk.LabelNew("Proteção")
	titulo.SetHExpand(true)
	titulo.SetHAlign(gtk.ALIGN_START)
	ctx, _ := titulo.GetStyleContext()
	ctx.AddClass("btn-titulo")
	barra.PackStart(titulo, true, true, 8)

	// Container para os botões no canto superior direito
	boxBotoes, _ := gtk.BoxNew(gtk.ORIENTATION_HORIZONTAL, 4)

	// Botão Minimizar
	btnMin, _ := gtk.ButtonNewWithLabel("—")
	ctxMin, _ := btnMin.GetStyleContext()
	ctxMin.AddClass("btn-titulo")
	btnMin.Connect("clicked", func() {
		win.Iconify()
	})
	boxBotoes.PackStart(btnMin, false, false, 0)

	// Botão Maximizar
	btnMax, _ := gtk.ButtonNewWithLabel("□")
	ctxMax, _ := btnMax.GetStyleContext()
	ctxMax.AddClass("btn-titulo")
	maximizado := false
	btnMax.Connect("clicked", func() {
		if maximizado {
			win.Unmaximize()
		} else {
			win.Maximize()
		}
		maximizado = !maximizado
	})
	boxBotoes.PackStart(btnMax, false, false, 0)

	// Botão Fechar
	btnFechar, _ := gtk.ButtonNewWithLabel("✕")
	ctxFechar, _ := btnFechar.GetStyleContext()
	ctxFechar.AddClass("btn-titulo")
	ctxFechar.AddClass("btn-fechar")
	btnFechar.Connect("clicked", func() {
		win.Close()
	})
	boxBotoes.PackStart(btnFechar, false, false, 0)

	barra.PackEnd(boxBotoes, false, false, 4)

	// Envolve a barra em EventBox para detectar arraste da janela
	evtBox, _ := gtk.EventBoxNew()
	evtBox.Add(barra)
	evtBox.SetAboveChild(false)
	evtBox.AddEvents(int(gdk.BUTTON_PRESS_MASK))
	evtBox.Connect("button-press-event", func(widget *gtk.EventBox, event *gdk.Event) bool {
		btnEvent := gdk.EventButtonNewFromEvent(event)
		if btnEvent.Button() == gdk.BUTTON_PRIMARY {
			win.BeginMoveDrag(
				gdk.Button(btnEvent.Button()),
				int(btnEvent.XRoot()),
				int(btnEvent.YRoot()),
				btnEvent.Time(),
			)
			return true
		}
		return false
	})

	return barra, evtBox
}
