package ui

import (
	"log"

	"github.com/gotk3/gotk3/glib"
	"github.com/gotk3/gotk3/gtk"

	"protecao-gui/polkit"
	"protecao-gui/script"
)

// Definição das opções disponíveis (placeholder — nomes serão definidos posteriormente)
var Opcoes = []struct {
	Nome   string // Nome exibido no botão
	Funcao string // Nome da função Bash a ser chamada
}{
	{Nome: "Opção 1 — Segurança", Funcao: "instalar_seguranca"},
	{Nome: "Opção 2 — Jogos", Funcao: "instalar_jogos"},
	{Nome: "Opção 3 — Configuração Completa", Funcao: "configuracao_completa"},
}

// TelaOpcoes gerencia a fase 2 da aplicação
type TelaOpcoes struct {
	container    *gtk.Box
	botoes       []*gtk.Button
	aoEscolher   func(funcao string) // Callback ao escolher uma opção
}

// NovaTelaOpcoes cria a tela com os três botões de opção
func NovaTelaOpcoes(aoEscolher func(funcao string)) *TelaOpcoes {
	tela := &TelaOpcoes{
		aoEscolher: aoEscolher,
	}

	// Container vertical centralizado
	container, _ := gtk.BoxNew(gtk.ORIENTATION_VERTICAL, 16)
	container.SetVAlign(gtk.ALIGN_CENTER)
	container.SetHAlign(gtk.ALIGN_CENTER)
	container.SetVExpand(true)
	container.SetHExpand(true)

	// Cria os botões de opção
	for _, opcao := range Opcoes {
		btn, _ := gtk.ButtonNewWithLabel(opcao.Nome)

		// Aplica classe CSS
		ctx, _ := btn.GetStyleContext()
		ctx.AddClass("btn-opcao")

		// Captura a função para o closure
		funcao := opcao.Funcao
		btn.Connect("clicked", func() {
			tela.aoClicar(funcao)
		})

		container.PackStart(btn, false, false, 4)
		tela.botoes = append(tela.botoes, btn)
	}

	tela.container = container
	return tela
}

// ObterWidget retorna o widget principal da tela
func (t *TelaOpcoes) ObterWidget() *gtk.Box {
	return t.container
}

// Mostrar exibe a tela com fade-in
func (t *TelaOpcoes) Mostrar() {
	t.container.SetOpacity(0)
	t.container.ShowAll()

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
}

// aoClicar processa o clique em um botão — solicita autenticação via Polkit
func (t *TelaOpcoes) aoClicar(funcao string) {
	// Desabilita os botões enquanto aguarda autenticação
	for _, btn := range t.botoes {
		btn.SetSensitive(false)
	}

	// Solicita autenticação via Polkit em goroutine separada
	go func() {
		autorizado, err := polkit.SolicitarAutorizacao()
		// Retorna à thread principal do GTK para atualizar a UI
		glib.IdleAdd(func() {
			if err != nil {
				log.Println("Erro ao solicitar Polkit:", err)
				t.reabilitarBotoes()
				return
			}

			if !autorizado {
				log.Println("Autenticação negada pelo usuário")
				t.reabilitarBotoes()
				return
			}

			// Autenticação bem-sucedida — executa o script em segundo plano
			log.Println("Autenticação Polkit concedida. Executando função:", funcao)

			// Inicia execução do script
			script.ExecutarFuncao(funcao)

			// Chama callback para transição para tela de progresso
			if t.aoEscolher != nil {
				t.aoEscolher(funcao)
			}
		})
	}()
}

// reabilitarBotoes restaura o estado dos botões após falha de autenticação
func (t *TelaOpcoes) reabilitarBotoes() {
	for _, btn := range t.botoes {
		btn.SetSensitive(true)
	}
}

// Esconder oculta a tela com fade-out
func (t *TelaOpcoes) Esconder() {
	opacidade := 1.0
	glib.TimeoutAdd(30, func() bool {
		opacidade -= 0.05
		if opacidade <= 0 {
			t.container.SetOpacity(0)
			t.container.Hide()
			return false
		}
		t.container.SetOpacity(opacidade)
		return true
	})
}
