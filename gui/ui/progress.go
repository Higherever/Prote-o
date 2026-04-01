package ui

import (
	"fmt"
	"log"
	"os"

	"github.com/gotk3/gotk3/glib"
	"github.com/gotk3/gotk3/gtk"

	"protecao-gui/script"
)

// TelaProgresso gerencia a fase 3 da aplicação — exibe o progresso da instalação
type TelaProgresso struct {
	container    *gtk.Box
	hippoLabel   *gtk.Label       // Placeholder para o ícone de hipopótamo
	barraProgresso *gtk.ProgressBar
	textoStatus  *gtk.Label
	progresso    float64
}

// NovaTelaProgresso cria a tela de progresso com hipopótamo e barra
func NovaTelaProgresso() *TelaProgresso {
	tela := &TelaProgresso{}

	// Container vertical centralizado
	container, _ := gtk.BoxNew(gtk.ORIENTATION_VERTICAL, 12)
	container.SetVAlign(gtk.ALIGN_CENTER)
	container.SetHAlign(gtk.ALIGN_CENTER)
	container.SetVExpand(true)
	container.SetHExpand(true)

	// Tenta carregar a animação enviada pelo usuário (assets/loading.webm).
	// Se não existir ou não puder ser carregada, usa o placeholder do hipopótamo.
	var animWidget *gtk.Image
	animPath := "assets/loading.webm"
	if _, err := os.Stat(animPath); err == nil {
		// Tenta criar uma GtkImage a partir do arquivo (suporta GIF/PNG; para WebM
		// a capacidade depende do sistema — GdkPixbuf costuma não reproduzir WebM).
		if img, err := gtk.ImageNewFromFile(animPath); err == nil {
			animWidget = img
		} else {
			log.Println("Não foi possível carregar a animação (gtk.Image):", err)
		}
	}

	if animWidget != nil {
		container.PackStart(animWidget, false, false, 20)
	} else {
		// Placeholder do hipopótamo (será substituído por imagem real depois)
		// Usando emoji como placeholder visual
		hippoLabel, _ := gtk.LabelNew("🦛")
		hippoLabel.SetName("hippo-label")
		hippoLabel.SetHAlign(gtk.ALIGN_CENTER)
		container.PackStart(hippoLabel, false, false, 20)
		tela.hippoLabel = hippoLabel
	}

	// Texto de status
	textoStatus, _ := gtk.LabelNew("Instalando...")
	textoStatus.SetName("texto-progresso")
	textoStatus.SetHAlign(gtk.ALIGN_CENTER)
	container.PackStart(textoStatus, false, false, 8)

	// Barra de progresso
	barra, _ := gtk.ProgressBarNew()
	barra.SetName("barra-progresso")
	barra.SetSizeRequest(400, 24)
	barra.SetHAlign(gtk.ALIGN_CENTER)
	barra.SetFraction(0)
	barra.SetShowText(true)
	container.PackStart(barra, false, false, 8)

	tela.container = container
	tela.barraProgresso = barra
	tela.textoStatus = textoStatus
	tela.progresso = 0

	return tela
}

// ObterWidget retorna o widget principal da tela
func (t *TelaProgresso) ObterWidget() *gtk.Box {
	return t.container
}

// Mostrar exibe a tela de progresso com fade-in e inicia a animação de progresso
func (t *TelaProgresso) Mostrar() {
	t.container.SetOpacity(0)
	t.container.ShowAll()

	// Fade-in
	opacidade := 0.0
	glib.TimeoutAdd(30, func() bool {
		opacidade += 0.05
		if opacidade >= 1.0 {
			t.container.SetOpacity(1.0)
			return false
		}
		t.container.SetOpacity(opacidade)
		return true
	})

	// Inicia monitoramento do progresso
	t.iniciarMonitoramento()
}

// iniciarMonitoramento verifica periodicamente o estado do script
func (t *TelaProgresso) iniciarMonitoramento() {
	glib.TimeoutAdd(500, func() bool {
		// Verifica se o script ainda está rodando
		if script.EstaExecutando() {
			// Progresso simulado — incrementa suavemente até 90%
			// O progresso real pode ser implementado depois via parsing do output
			if t.progresso < 0.9 {
				t.progresso += 0.01
			}
			t.barraProgresso.SetFraction(t.progresso)
			t.barraProgresso.SetText(fmt.Sprintf("%.0f%%", t.progresso*100))
			return true // Continua monitorando
		}

		// Script finalizado — preenche até 100%
		t.progresso = 1.0
		t.barraProgresso.SetFraction(1.0)
		t.barraProgresso.SetText("100%")

		// Verifica se houve erro
		if err := script.ObterErro(); err != nil {
			t.textoStatus.SetText("Erro durante a instalação!")
		} else {
			t.textoStatus.SetText("Instalação concluída com sucesso!")
		}

		return false // Para o monitoramento
	})
}
