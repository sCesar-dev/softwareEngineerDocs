#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE BENCHMARKING DE ALTA ESTABILIDADE (METODOLOGIA F.O.C.A.)
# ==============================================================================
# Finalidade: Configurar a máquina (hardware, kernel Linux e ambiente Python)
# para eliminar variações térmicas, concorrência de SMT e jitter do escalonador,
# garantindo que o Coeficiente de Variação (CV) se mantenha < 0.15.
#
# Processador Alvo: AMD Ryzen 7 5700U (8 cores / 16 threads)
# Núcleo Isolado Alvo: CPU 13 (Core 6)
# ==============================================================================

set -euo pipefail

# Diretório base do script e caminhos principais
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_VENV="/home/s-cesar/codes/softwareEngineerDocs/.venv/bin/python"
PYTHON_SCRIPT="experimentador_EP_2026.2.py"
LOGS_DIR="$SCRIPT_DIR/logs"
PID_FILE="$SCRIPT_DIR/benchmark.pid"
LOCK_FILE="$SCRIPT_DIR/benchmark.lock"
ESTADO_ENV="/var/tmp/foca_estado_original.env"

# Configurações de CPU
TARGET_CPU=13
CLOCK_FIXO_KHZ=1800000 # 1.80 GHz
RT_PRIORITY=10         # Prioridade FIFO moderada para evitar starvation do kernel

# Cores para exibição no terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ==============================================================================
# Função Auxiliar: obter_irmao_smt
# ------------------------------------------------------------------------------
# Objetivo: Descobrir dinamicamente o thread irmão SMT do núcleo alvo via sysfs.
# Proteção: Nunca desativa a CPU 0 nem a CPU alvo.
# ==============================================================================
obter_irmao_smt() {
    local target="$1"
    local siblings_file="/sys/devices/system/cpu/cpu${target}/topology/thread_siblings_list"
    if [ ! -f "$siblings_file" ]; then
        echo ""
        return 0
    fi

    local raw
    raw=$(cat "$siblings_file" 2>/dev/null || true)
    local sibling=""
    local parts=()
    IFS=',' read -ra parts <<< "$raw"
    for part in "${parts[@]}"; do
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local s="${BASH_REMATCH[1]}"
            local e="${BASH_REMATCH[2]}"
            for ((i=s; i<=e; i++)); do
                if [ "$i" -ne "$target" ]; then
                    sibling="$i"
                    break 2
                fi
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            if [ "$part" -ne "$target" ]; then
                sibling="$part"
                break
            fi
        fi
    done

    # Proteção estrita: nunca desativar CPU 0 nem a CPU alvo
    if [ -n "$sibling" ]; then
        if [ "$sibling" -eq 0 ] || [ "$sibling" -eq "$target" ]; then
            sibling=""
        fi
    fi

    echo "$sibling"
}

# ==============================================================================
# Subfunção 1: verificar_privilegios
# ------------------------------------------------------------------------------
# Objetivo: Garantir permissões de superusuário para ajuste de CPU e sysfs.
# ==============================================================================
verificar_privilegios() {
    echo -e "${BLUE}[1/8] Verificando privilégios de execução...${NC}"
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Este script requer privilégios de superusuário para ajustar a CPU.${NC}"
        echo -e "${YELLOW}Elevando execução com sudo...${NC}"
        exec sudo --preserve-env=PATH,USER,HOME bash "$0" "$@"
    fi
    echo -e "${GREEN}✓ Privilégios administrativos confirmados.${NC}"
}

# ==============================================================================
# Subfunção 2: verificar_dependencias_e_seguranca
# ------------------------------------------------------------------------------
# Objetivo: Validar ferramentas, interpretador e checar sched_rt_runtime_us.
# ==============================================================================
verificar_dependencias_e_seguranca() {
    echo -e "${BLUE}[2/8] Validando ferramentas, ambiente Python e segurança do kernel...${NC}"
    local dependencias=("cpupower" "chrt" "setarch" "taskset")
    for dep in "${dependencias[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${RED}Erro: A ferramenta '$dep' não foi encontrada no PATH.${NC}" >&2
            exit 1
        fi
    done

    if [ ! -x "$PYTHON_VENV" ]; then
        echo -e "${RED}Erro: Interpretador Python não encontrado em: $PYTHON_VENV${NC}" >&2
        exit 1
    fi

    if [ ! -f "$SCRIPT_DIR/$PYTHON_SCRIPT" ]; then
        echo -e "${RED}Erro: Script Python não encontrado em: $SCRIPT_DIR/$PYTHON_SCRIPT${NC}" >&2
        exit 1
    fi

    # Validação do RT Throttling do Kernel (sched_rt_runtime_us)
    local rt_file="/proc/sys/kernel/sched_rt_runtime_us"
    if [ -f "$rt_file" ]; then
        local rt_val
        rt_val=$(cat "$rt_file" 2>/dev/null || echo "0")
        if [ "$rt_val" -eq -1 ]; then
            echo -e "${RED}Erro de Segurança: $rt_file está configurado como -1.${NC}" >&2
            echo -e "${RED}O RT Throttling está desativado no kernel, o que geraria risco de congelamento do sistema.${NC}" >&2
            exit 1
        fi
        echo -e "${GREEN}✓ RT Throttling ativo no kernel (${rt_val} µs).${NC}"
    fi

    echo -e "${GREEN}✓ Todas as ferramentas e dependências foram validadas com sucesso.${NC}"
}

# ==============================================================================
# Subfunção 3: verificar_alimentacao_ac
# ------------------------------------------------------------------------------
# Objetivo: Alertar se o notebook estiver operando na bateria.
# ==============================================================================
verificar_alimentacao_ac() {
    echo -e "${BLUE}[3/8] Verificando fonte de alimentação de energia...${NC}"
    local on_ac=false
    for ps in /sys/class/power_supply/*; do
        if [ -f "$ps/online" ]; then
            local val
            val=$(cat "$ps/online" 2>/dev/null || echo "0")
            if [ "$val" -eq 1 ]; then
                on_ac=true
                break
            fi
        elif [ -f "$ps/type" ] && [ -f "$ps/status" ]; then
            local type status
            type=$(cat "$ps/type" 2>/dev/null || true)
            status=$(cat "$ps/status" 2>/dev/null || true)
            if [ "$type" = "Mains" ] || [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
                on_ac=true
                break
            fi
        fi
    done

    if [ "$on_ac" = false ]; then
        echo -e "${RED}==================================================================${NC}"
        echo -e "${RED}${BOLD} [!] ALERTA CRÍTICO: NOTEBOOK DESCONECTADO DA TOMADA (BATERIA)   ${NC}"
        echo -e "${RED}==================================================================${NC}"
        echo -e "${YELLOW}Executar na bateria causará flutuações de tensão e throttling,   ${NC}"
        echo -e "${YELLOW}comprometendo o critério de estabilidade CV < 0.15 (F.O.C.A.).   ${NC}"
        echo -e "${YELLOW}Conecte a fonte de alimentação AC imediatamente!                ${NC}\n"
    else
        echo -e "${GREEN}✓ Notebook conectado à fonte AC de alimentação.${NC}"
    fi
}

# ==============================================================================
# Subfunção 4: salvar_estado_original
# ------------------------------------------------------------------------------
# Objetivo: Salvar o estado original do hardware em /var/tmp/foca_estado_original.env
# antes de qualquer alteração de clock, boost ou SMT.
# ==============================================================================
salvar_estado_original() {
    local sibling="$1"
    echo -e "${BLUE}[4/8] Gravando snapshot do estado original do hardware...${NC}"

    if [ -f "$ESTADO_ENV" ]; then
        echo -e "${YELLOW}Aviso: Arquivo $ESTADO_ENV já existe. Preservando snapshot anterior.${NC}"
        return 0
    fi

    local orig_boost=""
    local orig_gov=""
    local orig_min=""
    local orig_max=""
    local orig_sibling_online="1"

    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        orig_boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo "1")
    fi

    if [ -f "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_governor" ]; then
        orig_gov=$(cat "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_governor" 2>/dev/null || echo "powersave")
    fi

    if [ -f "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_min_freq" ]; then
        orig_min=$(cat "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_min_freq" 2>/dev/null || echo "411000")
    fi

    if [ -f "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_max_freq" ]; then
        orig_max=$(cat "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_max_freq" 2>/dev/null || echo "4373000")
    fi

    if [ -n "$sibling" ] && [ -f "/sys/devices/system/cpu/cpu${sibling}/online" ]; then
        orig_sibling_online=$(cat "/sys/devices/system/cpu/cpu${sibling}/online" 2>/dev/null || echo "1")
    fi

    cat <<EOF > "$ESTADO_ENV"
# Snapshot do estado de hardware antes do benchmark F.O.C.A.
# Gerado em: $(date)
TARGET_CPU="${TARGET_CPU}"
SIBLING_CPU="${sibling}"
ORIG_BOOST="${orig_boost}"
ORIG_GOVERNOR="${orig_gov}"
ORIG_MIN_FREQ="${orig_min}"
ORIG_MAX_FREQ="${orig_max}"
ORIG_SIBLING_ONLINE="${orig_sibling_online}"
EOF

    chmod 644 "$ESTADO_ENV"
    echo -e "${GREEN}✓ Estado original registrado em $ESTADO_ENV:${NC}"
    echo -e "   Boost: $orig_boost | Governor: $orig_gov | Min: ${orig_min}kHz | Max: ${orig_max}kHz | Sibling (${sibling}): online=$orig_sibling_online"
}

# ==============================================================================
# Subfunção 5: desativar_turbo_boost
# ------------------------------------------------------------------------------
# Objetivo: Desabilitar o Precision Boost / Turbo Core da CPU com verificação.
# ==============================================================================
desativar_turbo_boost() {
    echo -e "${BLUE}[5/8] Desativando AMD Turbo Boost...${NC}"
    local boost_file="/sys/devices/system/cpu/cpufreq/boost"
    if [ ! -f "$boost_file" ]; then
        echo -e "${RED}Erro: Arquivo $boost_file não encontrado.${NC}" >&2
        exit 1
    fi

    if ! echo 0 > "$boost_file"; then
        echo -e "${RED}Erro: Falha ao escrever em $boost_file.${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}✓ Turbo Boost desativado via $boost_file.${NC}"
}

# ==============================================================================
# Subfunção 6: travar_frequencia_cpu
# ------------------------------------------------------------------------------
# Objetivo: Configurar governor 'performance' e fixar clock nominal (1.80 GHz).
# ==============================================================================
travar_frequencia_cpu() {
    echo -e "${BLUE}[6/8] Travando frequência da CPU no clock nominal de 1.80 GHz...${NC}"
    if ! cpupower frequency-set -g performance >/dev/null; then
        echo -e "${RED}Erro: Falha ao definir governor 'performance' com cpupower.${NC}" >&2
        exit 1
    fi

    if ! cpupower frequency-set -u "$CLOCK_FIXO_KHZ" -d "$CLOCK_FIXO_KHZ" >/dev/null; then
        echo -e "${RED}Erro: Falha ao travar clock em ${CLOCK_FIXO_KHZ}kHz com cpupower.${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}✓ Governor configurado para 'performance' e clock travado em 1.80 GHz.${NC}"
}

# ==============================================================================
# Subfunção 7: isolar_nucleo_smt
# ------------------------------------------------------------------------------
# Objetivo: Desativar a thread irmã SMT dinamicamente identificada.
# ==============================================================================
isolar_nucleo_smt() {
    local sibling="$1"
    echo -e "${BLUE}[7/8] Isolando núcleo físico para a CPU ${TARGET_CPU}...${NC}"
    if [ -z "$sibling" ]; then
        echo -e "${YELLOW}Aviso: Nenhuma thread irmã SMT válida identificada para desativação.${NC}"
        return 0
    fi

    local online_file="/sys/devices/system/cpu/cpu${sibling}/online"
    if [ ! -f "$online_file" ]; then
        echo -e "${YELLOW}Aviso: $online_file não encontrado. SMT pode não ser dinâmico.${NC}"
        return 0
    fi

    if ! echo 0 > "$online_file"; then
        echo -e "${RED}Erro: Falha ao colocar CPU ${sibling} offline via $online_file.${NC}" >&2
        exit 1
    fi
    echo -e "${GREEN}✓ CPU ${sibling} desativada (offline). CPU ${TARGET_CPU} possui acesso exclusivo ao núcleo físico.${NC}"
}

# ==============================================================================
# Subfunção 8: configurar_variaveis_ambiente
# ------------------------------------------------------------------------------
# Objetivo: Travar bibliotecas numéricas em 1 thread, fixar hash seed e backend Agg.
# ==============================================================================
configurar_variaveis_ambiente() {
    echo -e "${BLUE}[8/8] Ajustando variáveis de ambiente (Threads=1, Seed=0, Backend=Agg)...${NC}"
    export OMP_NUM_THREADS=1
    export OPENBLAS_NUM_THREADS=1
    export MKL_NUM_THREADS=1
    export VECLIB_MAXIMUM_THREADS=1
    export NUMEXPR_NUM_THREADS=1
    export PYTHONHASHSEED=0
    export MPLBACKEND=Agg
    echo -e "${GREEN}✓ Variáveis exportadas: threads travadas em 1, seed=0 e MPLBACKEND=Agg.${NC}"
}

# ==============================================================================
# Subfunção de Restauração: restaurar_configuracoes_sistema
# ------------------------------------------------------------------------------
# Objetivo: Reverter as alterações de hardware usando o arquivo de snapshot.
# ==============================================================================
restaurar_configuracoes_sistema() {
    echo -e "\n${YELLOW}==================================================================${NC}"
    echo -e "${YELLOW}   RESTAURANDO CONFIGURAÇÕES ORIGINAIS DO SISTEMA                ${NC}"
    echo -e "${YELLOW}==================================================================${NC}"

    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}A restauração exige permissões administrativas. Elevando com sudo...${NC}"
        exec sudo --preserve-env=PATH,USER,HOME bash "$0" "restore"
    fi

    if [ -f "$ESTADO_ENV" ]; then
        echo -e "${BLUE}Carregando snapshot de: $ESTADO_ENV${NC}"
        # shellcheck disable=SC1090
        source "$ESTADO_ENV"
    else
        echo -e "${YELLOW}Aviso: $ESTADO_ENV não encontrado. Aplicando padrões seguros de fábrica.${NC}"
        TARGET_CPU=13
        SIBLING_CPU=$(obter_irmao_smt "$TARGET_CPU")
        ORIG_BOOST="1"
        ORIG_GOVERNOR="powersave"
        ORIG_MIN_FREQ="411000"
        ORIG_MAX_FREQ="4373000"
        ORIG_SIBLING_ONLINE="1"
    fi

    # 1. Reativa a CPU irmã se estava online
    if [ -n "${SIBLING_CPU:-}" ] && [ -f "/sys/devices/system/cpu/cpu${SIBLING_CPU}/online" ]; then
        if [ "${ORIG_SIBLING_ONLINE:-1}" = "1" ]; then
            echo 1 > "/sys/devices/system/cpu/cpu${SIBLING_CPU}/online" 2>/dev/null || true
            echo -e "${GREEN}✓ CPU ${SIBLING_CPU} reativada (online).${NC}"
        fi
    fi

    # 2. Restaura o Turbo Boost
    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        echo "${ORIG_BOOST:-1}" > /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
        echo -e "${GREEN}✓ Turbo Boost restaurado (${ORIG_BOOST:-1}).${NC}"
    fi

    # 3. Restaura Governor e Frequências
    local gov="${ORIG_GOVERNOR:-powersave}"
    local min="${ORIG_MIN_FREQ:-411000}"
    local max="${ORIG_MAX_FREQ:-4373000}"

    cpupower frequency-set -g "$gov" >/dev/null 2>&1 || true
    cpupower frequency-set -u "$max" -d "$min" >/dev/null 2>&1 || true
    echo -e "${GREEN}✓ Governor restaurado para '$gov' e limites dinâmicos reativados (${min} - ${max} kHz).${NC}"

    rm -f "$ESTADO_ENV"
    echo -e "${GREEN}✓ Snapshot $ESTADO_ENV removido. Sistema normalizado com sucesso.${NC}\n"
}

# ==============================================================================
# Subfunção: exibir_status
# ------------------------------------------------------------------------------
# Objetivo: Exibir estado atual do benchmark, PID, CPU 13 e CPU irmã.
# ==============================================================================
exibir_status() {
    echo -e "\n${BLUE}==================================================================${NC}"
    echo -e "${BLUE}   STATUS DO BENCHMARK F.O.C.A.                                   ${NC}"
    echo -e "${BLUE}==================================================================${NC}"

    local sibling
    sibling=$(obter_irmao_smt "$TARGET_CPU")

    # Informações do Processo
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}● Status: EM EXECUÇÃO (PID: ${pid})${NC}"
            ps -p "$pid" -o pid,user,%cpu,%mem,etime,cmd --headers || true
            echo -e "Afinidade (taskset): $(taskset -cp "$pid" 2>/dev/null || echo "N/A")"
            echo -e "Escalonamento (chrt): $(chrt -p "$pid" 2>/dev/null || echo "N/A")"
        else
            echo -e "${YELLOW}○ Status: INATIVO (Arquivo PID existe, mas processo $pid não está rodando).${NC}"
        fi
    else
        echo -e "${YELLOW}○ Status: INATIVO (Nenhum PID registrado em $PID_FILE).${NC}"
    fi

    # Informações de Hardware
    echo -e "\n${BOLD}Estado Atual do Hardware:${NC}"
    if [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        local boost
        boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo "N/A")
        echo -e " - Turbo Boost: $([ "$boost" = "0" ] && echo -e "${GREEN}Desativado (0)${NC}" || echo -e "${YELLOW}Ativado ($boost)${NC}")"
    fi

    if [ -f "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_cur_freq" ]; then
        local cur_freq gov
        cur_freq=$(cat "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_cur_freq" 2>/dev/null || echo "N/A")
        gov=$(cat "/sys/devices/system/cpu/cpu${TARGET_CPU}/cpufreq/scaling_governor" 2>/dev/null || echo "N/A")
        echo -e " - CPU ${TARGET_CPU} Governor: $gov"
        echo -e " - CPU ${TARGET_CPU} Frequência Atual: ${cur_freq} kHz"
    fi

    if [ -n "$sibling" ] && [ -f "/sys/devices/system/cpu/cpu${sibling}/online" ]; then
        local sib_online
        sib_online=$(cat "/sys/devices/system/cpu/cpu${sibling}/online" 2>/dev/null || echo "N/A")
        echo -e " - CPU ${sibling} (Irmão SMT): $([ "$sib_online" = "0" ] && echo -e "${GREEN}Offline (0 - Isolado)${NC}" || echo -e "${YELLOW}Online ($sib_online)${NC}")"
    fi

    if [ -f "$ESTADO_ENV" ]; then
        echo -e " - Snapshot Ativo: ${GREEN}Sim ($ESTADO_ENV)${NC}"
    else
        echo -e " - Snapshot Ativo: ${YELLOW}Não (Sistema nas configurações padrão)${NC}"
    fi
    echo -e "==================================================================\n"
}

# ==============================================================================
# Subfunção: exibir_logs
# ------------------------------------------------------------------------------
# Objetivo: Acompanhar o arquivo de log mais recente em logs/.
# ==============================================================================
exibir_logs() {
    if [ ! -d "$LOGS_DIR" ]; then
        echo -e "${YELLOW}Diretório de logs não encontrado ($LOGS_DIR).${NC}"
        return 0
    fi

    local latest_log
    latest_log=$(find "$LOGS_DIR" -maxdepth 1 -name "benchmark_*.log" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n 1 | awk '{print $2}')
    if [ -n "$latest_log" ] && [ -f "$latest_log" ]; then
        echo -e "${BLUE}Exibindo tail de: $latest_log (Pressione Ctrl+C para sair)${NC}\n"
        tail -n 30 -f "$latest_log"
    else
        echo -e "${YELLOW}Nenhum arquivo de log encontrado em $LOGS_DIR.${NC}"
    fi
}

# ==============================================================================
# Subfunção: parar_benchmark
# ------------------------------------------------------------------------------
# Objetivo: Enviar sinal de interrupção limpo para o processo de benchmark.
# ==============================================================================
parar_benchmark() {
    if [ ! -f "$PID_FILE" ]; then
        echo -e "${YELLOW}Nenhum benchmark em execução registrado em $PID_FILE.${NC}"
        return 0
    fi

    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${YELLOW}Processo $pid não está em execução. Limpando arquivo de PID.${NC}"
        rm -f "$PID_FILE"
        return 0
    fi

    echo -e "${YELLOW}Enviando SIGTERM para o processo do benchmark (PID: $pid)...${NC}"
    kill -TERM "$pid" 2>/dev/null || true

    local count=0
    while kill -0 "$pid" 2>/dev/null && [ "$count" -lt 5 ]; do
        sleep 1
        count=$((count + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}Processo não respondeu ao SIGTERM. Enviando SIGKILL...${NC}"
        kill -KILL "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    echo -e "${GREEN}✓ Benchmark encerrado com sucesso.${NC}"
    echo -e "${YELLOW}Lembrete: O hardware continua configurado em modo benchmark.${NC}"
    echo -e "${YELLOW}Para restaurar as configurações originais, execute:${NC}"
    echo -e "   sudo $0 restore\n"
}

# ==============================================================================
# Subfunção: executar_dry_run
# ------------------------------------------------------------------------------
# Objetivo: Simular toda a preparação e execução sem aplicar qualquer comando.
# ==============================================================================
executar_dry_run() {
    echo -e "\n${GREEN}==================================================================${NC}"
    echo -e "${GREEN}   MODO DRY-RUN (SIMULAÇÃO SEM ALTERAR O SISTEMA)                ${NC}"
    echo -e "${GREEN}==================================================================${NC}"

    verificar_dependencias_e_seguranca
    verificar_alimentacao_ac

    local sibling
    sibling=$(obter_irmao_smt "$TARGET_CPU")
    echo -e "\n${BOLD}[Simulação de Parâmetros Identificados]:${NC}"
    echo -e " - CPU Alvo: ${TARGET_CPU}"
    echo -e " - CPU Irmã SMT detectada: ${sibling:-Nenhuma}"
    echo -e " - Clock Nominal Alvo: ${CLOCK_FIXO_KHZ} kHz (1.80 GHz)"
    echo -e " - Prioridade Real-Time: SCHED_FIFO 10"

    echo -e "\n${BOLD}[Comandos que seriam executados no hardware]:${NC}"
    echo -e " 1. Salvar snapshot em: ${ESTADO_ENV}"
    echo -e " 2. echo 0 > /sys/devices/system/cpu/cpufreq/boost"
    echo -e " 3. cpupower frequency-set -g performance"
    echo -e " 4. cpupower frequency-set -u ${CLOCK_FIXO_KHZ} -d ${CLOCK_FIXO_KHZ}"
    if [ -n "$sibling" ]; then
        echo -e " 5. echo 0 > /sys/devices/system/cpu/cpu${sibling}/online"
    fi
    echo -e " 6. export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 PYTHONHASHSEED=0 MPLBACKEND=Agg"

    local inhibit_desc="systemd-inhibit --why=\"Benchmark FOCA\" --what=sleep:idle:handle-lid-switch --mode=block"
    echo -e " 7. Execução do experimento:"
    echo -e "    $inhibit_desc setarch $(uname -m) -R chrt -f ${RT_PRIORITY} \\"
    echo -e "        ${PYTHON_VENV} -u -O -B ${SCRIPT_DIR}/${PYTHON_SCRIPT}"

    echo -e "\n${BOLD}[Restauração Manual]:${NC}"
    echo -e " - Comando para reverter: sudo $0 restore (ou ./restaurar_sistema.sh)"
    echo -e "${GREEN}Simulação concluída com sucesso. Nenhuma alteração foi efetuada.${NC}\n"
}

# ==============================================================================
# Subfunção: executar_background
# ------------------------------------------------------------------------------
# Objetivo: Executar o benchmark em segundo plano, imune ao fechamento do terminal.
# ==============================================================================
executar_background() {
    echo -e "${BLUE}Preparando execução em segundo plano (nohup/setsid)...${NC}"
    mkdir -p "$LOGS_DIR"

    # Verificar lock / processo existente
    if [ -f "$PID_FILE" ]; then
        local old_pid
        old_pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
            echo -e "${RED}Erro: Já existe um benchmark em execução com PID ${old_pid}.${NC}" >&2
            echo -e "${YELLOW}Acompanhe com: $0 status ou $0 logs${NC}" >&2
            exit 1
        fi
    fi

    local data_hora
    data_hora=$(date +%Y%m%d_%H%M%S)
    local log_file="$LOGS_DIR/benchmark_${data_hora}.log"

    local inhibit_cmd=()
    if command -v systemd-inhibit &>/dev/null; then
        inhibit_cmd=(systemd-inhibit --why="Benchmark FOCA de alta estabilidade" --what=sleep:idle:handle-lid-switch --mode=block)
    fi

    # Script wrapper executado em segundo plano imune a SIGHUP
    local runner_cmd=(
        "${inhibit_cmd[@]}"
        setarch "$(uname -m)" -R
        chrt -f "$RT_PRIORITY"
        "$PYTHON_VENV" -u -O -B "$SCRIPT_DIR/$PYTHON_SCRIPT"
    )

    echo -e "${BLUE}Disparando processo desvinculado de sessão (setsid nohup)...${NC}"
    
    # Executa com nohup/setsid registrando stdout e stderr diretamente no log
    (
        cd "$SCRIPT_DIR"
        setsid nohup "${runner_cmd[@]}" > "$log_file" 2>&1 &
        echo $! > "$PID_FILE"
    )

    sleep 1

    local new_pid
    new_pid=$(cat "$PID_FILE" 2>/dev/null || true)
    if [ -n "$new_pid" ] && kill -0 "$new_pid" 2>/dev/null; then
        echo -e "\n${GREEN}==================================================================${NC}"
        echo -e "${GREEN}${BOLD}   BENCHMARK INICIADO COM SUCESSO EM SEGUNDO PLANO                ${NC}"
        echo -e "${GREEN}==================================================================${NC}"
        echo -e " - ${BOLD}PID do Processo:${NC} ${new_pid}"
        echo -e " - ${BOLD}Arquivo de Log:${NC} ${log_file}"
        echo -e " - ${BOLD}Afinidade de CPU:${NC} CPU ${TARGET_CPU} (via os.sched_setaffinity)"
        echo -e " - ${BOLD}Prioridade Real-Time:${NC} FIFO ${RT_PRIORITY}"
        echo -e " - ${BOLD}Inibição de Suspensão:${NC} $([ ${#inhibit_cmd[@]} -gt 0 ] && echo "Ativa (systemd-inhibit)" || echo "Inativa")"
        echo -e "\n${YELLOW}IMPORTANTE: O sistema PERMANECERÁ em modo benchmark mesmo após o fim da execução.${NC}"
        echo -e "${YELLOW}Comandos úteis para gerenciar a execução:${NC}"
        echo -e "   Ver status:       ${BOLD}$0 status${NC}"
        echo -e "   Ver logs ao vivo: ${BOLD}$0 logs${NC}"
        echo -e "   Interromper:      ${BOLD}$0 stop${NC}"
        echo -e "   Restaurar padrão: ${BOLD}sudo $0 restore${NC} (ou ./restaurar_sistema.sh)\n"
    else
        echo -e "${RED}Erro: O processo não permaneceu em execução. Verifique o log em: $log_file${NC}" >&2
        cat "$log_file" >&2
        exit 1
    fi
}

# ==============================================================================
# Subfunção: executar_foreground
# ------------------------------------------------------------------------------
# Objetivo: Executar o benchmark diretamente no terminal atual.
# ==============================================================================
executar_foreground() {
    echo -e "${BLUE}Iniciando experimento em primeiro plano...${NC}"
    cd "$SCRIPT_DIR"

    local inhibit_cmd=()
    if command -v systemd-inhibit &>/dev/null; then
        inhibit_cmd=(systemd-inhibit --why="Benchmark FOCA de alta estabilidade" --what=sleep:idle:handle-lid-switch --mode=block)
    fi

    echo -e "\n${YELLOW}AVISO: Sem restauração automática ao final.${NC}"
    echo -e "${YELLOW}Ao concluir, execute 'sudo $0 restore' para reverter o sistema.${NC}\n"

    "${inhibit_cmd[@]}" \
        setarch "$(uname -m)" -R \
        chrt -f "$RT_PRIORITY" \
        "$PYTHON_VENV" -u -O -B "$PYTHON_SCRIPT"

    echo -e "\n${GREEN}Benchmark concluído.${NC}"
    echo -e "${YELLOW}Lembrete: O sistema continua com clock fixo e SMT isolado.${NC}"
    echo -e "${YELLOW}Para normalizar, execute: sudo $0 restore${NC}\n"
}

# ==============================================================================
# Fluxo de Controle e Tratamento de Argumentos
# ==============================================================================
main() {
    local cmd="${1:-}"

    case "$cmd" in
        "status")
            exibir_status
            exit 0
            ;;
        "logs")
            exibir_logs
            exit 0
            ;;
        "stop")
            parar_benchmark
            exit 0
            ;;
        "restore")
            restaurar_configuracoes_sistema
            exit 0
            ;;
        "--dry-run")
            executar_dry_run
            exit 0
            ;;
        "--background"|"")
            # Fluxo de execução do benchmark (foreground ou background)
            echo -e "${GREEN}==================================================================${NC}"
            echo -e "${GREEN}   INICIALIZAÇÃO DO AMBIENTE ESTÁVEL DE BENCHMARK (F.O.C.A.)      ${NC}"
            echo -e "${GREEN}==================================================================${NC}"

            verificar_privilegios "$@"
            verificar_dependencias_e_seguranca
            verificar_alimentacao_ac

            local sibling
            sibling=$(obter_irmao_smt "$TARGET_CPU")

            salvar_estado_original "$sibling"
            desativar_turbo_boost
            travar_frequencia_cpu
            isolar_nucleo_smt "$sibling"
            configurar_variaveis_ambiente

            if [ "$cmd" = "--background" ]; then
                executar_background
            else
                executar_foreground
            fi
            ;;
        *)
            echo "Uso: $0 [--background | --dry-run | status | logs | stop | restore]"
            exit 1
            ;;
    esac
}

main "$@"
