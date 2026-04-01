package ui

import (
	"math"
	"math/rand"

	"github.com/gotk3/gotk3/cairo"
	"github.com/gotk3/gotk3/glib"
	"github.com/gotk3/gotk3/gtk"
)

// Vagalume representa uma partícula luminosa flutuante
type Vagalume struct {
	X, Y       float64 // Posição atual
	VX, VY     float64 // Velocidade (direção)
	Raio       float64 // Tamanho da partícula
	Opacidade  float64 // Opacidade atual (0.0 a 1.0)
	OpacDir    float64 // Direção da mudança de opacidade (+1 ou -1)
}

// MotorVagalumes gerencia a animação dos vagalumes
type MotorVagalumes struct {
	vagalumes []Vagalume
	area      *gtk.DrawingArea
	largura   float64
	altura    float64
}

// NovoMotorVagalumes cria e inicializa o motor de animação dos vagalumes
func NovoMotorVagalumes(area *gtk.DrawingArea, quantidade int) *MotorVagalumes {
	motor := &MotorVagalumes{
		area:      area,
		vagalumes: make([]Vagalume, quantidade),
		largura:   800,
		altura:    600,
	}

	// Inicializa cada vagalume com posição e velocidade aleatórias
	for i := range motor.vagalumes {
		motor.vagalumes[i] = Vagalume{
			X:         rand.Float64() * motor.largura,
			Y:         rand.Float64() * motor.altura,
			VX:        (rand.Float64() - 0.5) * 0.8, // Velocidade lenta
			VY:        (rand.Float64() - 0.5) * 0.8,
			Raio:      1.5 + rand.Float64()*2.5,
			Opacidade: 0.1 + rand.Float64()*0.4,
			OpacDir:   1.0,
		}
	}

	return motor
}

// Iniciar começa a animação dos vagalumes com um timer de ~30 FPS
func (m *MotorVagalumes) Iniciar() {
	// Conecta o evento de desenho
	m.area.Connect("draw", m.desenhar)

	// Timer para atualizar a posição dos vagalumes (~33ms = ~30 FPS)
	glib.TimeoutAdd(33, func() bool {
		m.atualizar()
		m.area.QueueDraw()
		return true // Continua o timer
	})
}

// atualizar move cada vagalume e ajusta opacidade
func (m *MotorVagalumes) atualizar() {
	// Obtém dimensões atuais da área de desenho
	alloc := m.area.GetAllocation()
	m.largura = float64(alloc.GetWidth())
	m.altura = float64(alloc.GetHeight())

	for i := range m.vagalumes {
		v := &m.vagalumes[i]

		// Move o vagalume
		v.X += v.VX
		v.Y += v.VY

		// Recalcula direção aleatoriamente (movimento orgânico)
		v.VX += (rand.Float64() - 0.5) * 0.1
		v.VY += (rand.Float64() - 0.5) * 0.1

		// Limita a velocidade máxima
		maxVel := 1.0
		v.VX = math.Max(-maxVel, math.Min(maxVel, v.VX))
		v.VY = math.Max(-maxVel, math.Min(maxVel, v.VY))

		// Mantém dentro da janela (wrap around)
		if v.X < 0 {
			v.X = m.largura
		} else if v.X > m.largura {
			v.X = 0
		}
		if v.Y < 0 {
			v.Y = m.altura
		} else if v.Y > m.altura {
			v.Y = 0
		}

		// Pulsa a opacidade suavemente
		v.Opacidade += v.OpacDir * 0.005
		if v.Opacidade >= 0.5 {
			v.OpacDir = -1.0
		} else if v.Opacidade <= 0.05 {
			v.OpacDir = 1.0
		}
	}
}

// desenhar renderiza os vagalumes no canvas Cairo
func (m *MotorVagalumes) desenhar(area *gtk.DrawingArea, cr *cairo.Context) {
	for _, v := range m.vagalumes {
		// Cor verde-amarelada suave: rgba(180, 255, 100, opacidade)
		cr.SetSourceRGBA(180.0/255.0, 1.0, 100.0/255.0, v.Opacidade)

		// Desenha um gradiente radial simulado (círculo preenchido)
		cr.Arc(v.X, v.Y, v.Raio, 0, 2*math.Pi)
		cr.Fill()

		// Halo externo mais suave
		cr.SetSourceRGBA(180.0/255.0, 1.0, 100.0/255.0, v.Opacidade*0.3)
		cr.Arc(v.X, v.Y, v.Raio*2.5, 0, 2*math.Pi)
		cr.Fill()
	}
}
