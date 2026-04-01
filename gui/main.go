package main

import (
	"log"
	"os"

	"github.com/gotk3/gotk3/glib"
	"github.com/gotk3/gotk3/gtk"

	"protecao-gui/ui"
)

func main() {
	// Inicializa GTK
	gtk.Init(&os.Args)

	// Cria a aplicação GTK
	app, err := gtk.ApplicationNew("com.protecao.gui", glib.APPLICATION_FLAGS_NONE)
	if err != nil {
		log.Fatal("Erro ao criar aplicação GTK:", err)
	}

	// Conecta o sinal "activate" para criar a janela principal
	app.Connect("activate", func() {
		ui.CriarJanelaPrincipal(app)
	})

	// Executa a aplicação
	os.Exit(app.Run(os.Args))
}
