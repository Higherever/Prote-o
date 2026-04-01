package ui

import (
	"log"

	"github.com/gotk3/gotk3/gdk"
	"github.com/gotk3/gotk3/gtk"
)

// CSS global da aplicação — cantos arredondados, fundo preto, estilização dos botões
const cssGlobal = `
/* Janela principal — fundo preto com cantos arredondados */
#janela-principal {
	background-color: #000000;
	border-radius: 12px;
}

/* Barra de título personalizada */
#barra-titulo {
	background-color: #111111;
	border-radius: 12px 12px 0 0;
	padding: 4px 8px;
}

/* Botões da barra de título */
.btn-titulo {
	background: transparent;
	border: none;
	color: #cccccc;
	font-size: 14px;
	padding: 4px 10px;
	border-radius: 4px;
	min-width: 30px;
	min-height: 30px;
}

.btn-titulo:hover {
	background-color: #333333;
}

.btn-fechar:hover {
	background-color: #e81123;
	color: #ffffff;
}

/* Texto de boas-vindas */
#texto-boas-vindas {
	color: #ffffff;
	font-size: 28px;
	font-weight: bold;
}

/* Botões de opção estilizados */
.btn-opcao {
	background-color: #1a1a2e;
	color: #ffffff;
	border: 1px solid #333366;
	border-radius: 8px;
	padding: 16px 32px;
	font-size: 16px;
	font-weight: bold;
	min-width: 280px;
	min-height: 50px;

}

.btn-opcao:hover {
	background-color: #16213e;
	border-color: #0f3460;
	box-shadow: 0 0 12px rgba(100, 200, 255, 0.3);
}

/* Barra de progresso */
#barra-progresso trough {
	background-color: #1a1a1a;
	border-radius: 6px;
	min-height: 20px;
}

#barra-progresso progress {
	background-color: #4CAF50;
	border-radius: 6px;
	min-height: 20px;
}

/* Texto de progresso */
#texto-progresso {
	color: #ffffff;
	font-size: 18px;
}

/* Label do hipopótamo (placeholder) */
#hippo-label {
	color: #888888;
	font-size: 72px;
}
`

// AplicarCSS carrega e aplica o CSS global na tela padrão
func AplicarCSS() {
	provider, err := gtk.CssProviderNew()
	if err != nil {
		log.Println("Erro ao criar CssProvider:", err)
		return
	}

	err = provider.LoadFromData(cssGlobal)
	if err != nil {
		log.Println("Erro ao carregar CSS:", err)
		return
	}

	screen, err := gdk.ScreenGetDefault()
	if err != nil {
		log.Println("Erro ao obter tela padrão:", err)
		return
	}

	gtk.AddProviderForScreen(screen, provider, gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
}
