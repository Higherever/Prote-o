package polkit

import (
	"fmt"
	"os"

	"github.com/godbus/dbus/v5"
)

// ID da ação Polkit — usar a ação genérica do pkexec para executar como root
// Pode ser substituído por uma ação personalizada no futuro
const AcaoPolkit = "org.freedesktop.policykit.exec"

// Solicitar Autorizacao solicita elevação de privilégios via Polkit usando D-Bus
// Retorna true se o usuário foi autenticado com sucesso
func SolicitarAutorizacao() (bool, error) {
	// Conecta ao barramento do sistema via D-Bus
	conn, err := dbus.SystemBus()
	if err != nil {
		return false, fmt.Errorf("erro ao conectar ao D-Bus do sistema: %w", err)
	}

	// Objeto do Polkit Authority
	obj := conn.Object(
		"org.freedesktop.PolicyKit1",
		"/org/freedesktop/PolicyKit1/Authority",
	)

	// Monta o "subject" — identifica o processo que está pedindo autorização
	pid := uint32(os.Getpid())
	subject := struct {
		Kind    string
		Details map[string]dbus.Variant
	}{
		Kind: "unix-process",
		Details: map[string]dbus.Variant{
			"pid":        dbus.MakeVariant(pid),
			"start-time": dbus.MakeVariant(uint64(0)),
		},
	}

	// Flags do CheckAuthorization:
	// 1 = AllowUserInteraction (mostra diálogo de senha se necessário)
	flags := uint32(1)

	// Chama o método CheckAuthorization do Polkit
	var resultado struct {
		IsAuthorized bool
		IsChallenge  bool
		Details      map[string]dbus.Variant
	}

	// Detalhes passados como a{ss} (map[string]string) — Polkit espera a{ss} para o
	// parâmetro 'details' na chamada CheckAuthorization
	detalhes := map[string]string{}

	// Faz a chamada ao método e inspeciona o corpo da resposta manualmente
	call := obj.Call(
		"org.freedesktop.PolicyKit1.Authority.CheckAuthorization",
		0,
		subject,
		AcaoPolkit,
		detalhes,
		flags,
		"",
	)

	if call.Err != nil {
		return false, fmt.Errorf("erro ao chamar CheckAuthorization: %w", call.Err)
	}

	// A resposta pode vir em duas formas comuns:
	// 1) body = [ is_authorized(bool), is_challenge(bool), details(a{sv}) ]
	// 2) body = [ [ is_authorized, is_challenge, details ] ] (aninhado)
	var body []interface{}
	if len(call.Body) == 1 {
		// tenta descompactar caso o primeiro elemento seja um slice (aninhado)
		switch v := call.Body[0].(type) {
		case []interface{}:
			body = v
		default:
			body = call.Body
		}
	} else {
		body = call.Body
	}

	if len(body) < 2 {
		return false, fmt.Errorf("resposta inesperada do CheckAuthorization: %v", call.Body)
	}

	// Extrai is_authorized e is_challenge robustamente (suporta dbus.Variant indireto)
	var isAuth bool
	var isChallenge bool

	// helper para extrair boolean de interface{}
	extractBool := func(v interface{}) (bool, bool) {
		if b, ok := v.(bool); ok {
			return b, true
		}
		if dv, ok := v.(dbus.Variant); ok {
			if b2, ok2 := dv.Value().(bool); ok2 {
				return b2, true
			}
		}
		return false, false
	}

	if b, ok := extractBool(body[0]); ok {
		isAuth = b
	} else {
		return false, fmt.Errorf("tipo inesperado para is_authorized: %T (body=%v)", body[0], call.Body)
	}

	if b, ok := extractBool(body[1]); ok {
		isChallenge = b
	} else {
		return false, fmt.Errorf("tipo inesperado para is_challenge: %T (body=%v)", body[1], call.Body)
	}

	// O terceiro valor (se presente) é geralmente um a{sv} (map[string]Variant)
	if len(body) >= 3 {
		switch v := body[2].(type) {
		case map[string]dbus.Variant:
			resultado.Details = v
		case map[string]interface{}:
			m := make(map[string]dbus.Variant)
			for k, val := range v {
				m[k] = dbus.MakeVariant(val)
			}
			resultado.Details = m
		case map[string]string:
			m := make(map[string]dbus.Variant)
			for k, val := range v {
				m[k] = dbus.MakeVariant(val)
			}
			resultado.Details = m
		case dbus.Variant:
			// Se vier como um Variant contendo um mapa
			if inner, ok := v.Value().(map[string]dbus.Variant); ok {
				resultado.Details = inner
			} else {
				resultado.Details = map[string]dbus.Variant{}
			}
		default:
			resultado.Details = map[string]dbus.Variant{}
		}
	}

	resultado.IsAuthorized = isAuth
	resultado.IsChallenge = isChallenge

	return resultado.IsAuthorized, nil
}
