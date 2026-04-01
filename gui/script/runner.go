package script

import (
	"log"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
)

// CaminhoScript é o caminho para o script Bash principal
// Será calculado em relação ao binário da aplicação
var CaminhoScript string

// Estado do processo em execução (protegido por mutex)
var (
	mutex       sync.Mutex
	cmdAtual    *exec.Cmd
	executando  bool
	erroFinal   error
)

func init() {
	// Calcula o caminho do script em relação ao diretório do executável
	_, arquivo, _, _ := runtime.Caller(0)
	dir := filepath.Dir(filepath.Dir(filepath.Dir(arquivo)))
	CaminhoScript = filepath.Join(dir, "instalar.sh")
}

// ExecutarFuncao executa uma função específica do script Bash em segundo plano
// O script é chamado via pkexec para elevação de privilégios
func ExecutarFuncao(nomeFuncao string) {
	mutex.Lock()
	defer mutex.Unlock()

	if executando {
		log.Println("Já existe um script em execução")
		return
	}

	executando = true
	erroFinal = nil

	// Monta o comando: pkexec bash -c "PROTECAO_RUN_FUNC='funcao' bash '/caminho/instalar.sh'"
	// Usamos uma variável de ambiente para instruir o script a executar apenas a função
	// desejada (evita executar o menu interativo quando o script é source'd).
	comandoBash := "PROTECAO_RUN_FUNC='" + nomeFuncao + "' bash '" + CaminhoScript + "'"

	cmd := exec.Command("pkexec", "bash", "-c", comandoBash)

	// Inicia a execução em goroutine para não bloquear a UI
	go func() {
		log.Printf("Executando: pkexec bash -c \"%s\"", comandoBash)

		saida, err := cmd.CombinedOutput()
		if err != nil {
			log.Printf("Erro na execução do script: %v\nSaída: %s", err, string(saida))
		} else {
			log.Printf("Script finalizado com sucesso. Saída: %s", string(saida))
		}

		mutex.Lock()
		executando = false
		erroFinal = err
		cmdAtual = nil
		mutex.Unlock()
	}()

	cmdAtual = cmd
}

// EstaExecutando retorna true se há um script rodando no momento
func EstaExecutando() bool {
	mutex.Lock()
	defer mutex.Unlock()
	return executando
}

// ObterErro retorna o erro da última execução (nil se não houve erro)
func ObterErro() error {
	mutex.Lock()
	defer mutex.Unlock()
	return erroFinal
}
