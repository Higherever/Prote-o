package ui

import (
	"github.com/gotk3/gotk3/glib"
	"github.com/gotk3/gotk3/gtk"
)

// Configuração da tela de boas-vindas
const (
	// Mensagem de boas-vindas (placeholder — será configurado depois)
	MensagemBoasVindas = "Bem-vindo ao Proteção"
	// Duração da tela de boas-vindas em milissegundos
	DuracaoBoasVindas = 5000
	// Passos do fade-out (quanto menor, mais suave)
	PassosFadeOut = 20
)

// TelaBoasVindas gerencia a fase 1 da aplicação
type TelaBoasVindas struct {
	label      *gtk.Label
	container  *gtk.Box
	aoFinalizar func() // Callback chamado quando a tela desaparece
}

// NovaTelaBoasVindas cria a tela de boas-vindas centralizada
func NovaTelaBoasVindas(aoFinalizar func()) *TelaBoasVindas {
	tela := &TelaBoasVindas{
		aoFinalizar: aoFinalizar,
	}

	// Container vertical centralizado
	container, _ := gtk.BoxNew(gtk.ORIENTATION_VERTICAL, 0)
	container.SetVAlign(gtk.ALIGN_CENTER)
	container.SetHAlign(gtk.ALIGN_CENTER)
	container.SetVExpand(true)
	container.SetHExpand(true)

	// Label de boas-vindas
	label, _ := gtk.LabelNew(MensagemBoasVindas)
	label.SetName("texto-boas-vindas")
	label.SetHAlign(gtk.ALIGN_CENTER)

	container.PackStart(label, false, false, 0)

	tela.label = label
	tela.container = container

	return tela
}

// ObterWidget retorna o widget principal da tela
func (t *TelaBoasVindas) ObterWidget() *gtk.Box {
	return t.container
}

// Iniciar começa o timer de 5 segundos e depois faz fade-out
func (t *TelaBoasVindas) Iniciar() {
	t.container.ShowAll()

	// Após 5 segundos, inicia o fade-out
	glib.TimeoutAdd(uint(DuracaoBoasVindas), func() bool {
		t.iniciarFadeOut()
		return false // Executa apenas uma vez
	})
}

// iniciarFadeOut reduz a opacidade gradualmente até esconder o widget
func (t *TelaBoasVindas) iniciarFadeOut() {
	opacidade := 1.0
	passo := 1.0 / float64(PassosFadeOut)

	glib.TimeoutAdd(30, func() bool {
		opacidade -= passo
		if opacidade <= 0 {
			t.container.SetOpacity(0)
			t.container.Hide()
			// Chama o callback para mostrar a próxima fase
			if t.aoFinalizar != nil {
				t.aoFinalizar()
			}
			return false // Para o timer
		}
		t.container.SetOpacity(opacidade)
		return true // Continua o timer
	})
}
