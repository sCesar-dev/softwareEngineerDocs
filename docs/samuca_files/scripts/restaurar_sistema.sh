#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE RESTAURAÇÃO MANUAL DO SISTEMA (BENCHMARK F.O.C.A.)
# ==============================================================================
# Lê o snapshot salvo em /var/tmp/foca_estado_original.env e reverte todas as
# alterações de hardware e kernel feitas pelo script de benchmark.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/executar_benchmark_otimizado.sh" "restore" "$@"
