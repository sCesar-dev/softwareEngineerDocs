"""
Análise de Distribuição de Tempos de Execução
================================================
Este script:
  1. Coleta R repetições de tempo de execução para cada valor de n
     (baseado nos códigos de execution.ipynb e execution_time.py)
  2. Plota a série temporal e o histograma com linhas horizontais
     nos picos da distribuição para visualizar onde estão os vértices
  3. Define valores de corte (IQR) para eliminar outliers/picos
  4. Calcula média, desvio padrão e coeficiente de variação
     antes e depois da filtragem
"""

from time import time
import numpy as np
from matplotlib import pyplot as plt

# ──────────────────────────────────────────────
# Parâmetros (mesmos do notebook e execution_time.py)
# ──────────────────────────────────────────────
lista_n = [1000, 10000, 100000]
R = 100  # repetições por valor de n

def coletar_tempos(n: int, repeticoes: int) -> list[float]:
    """Executa *repeticoes* vezes um laço de tamanho *n* e retorna os tempos."""
    tempos = []
    for _ in range(repeticoes):
        tic = time()
        for _ in range(n):
            x = 1  # noqa: F841 – operação mínima
        tac = time()
        tempos.append(tac - tic)
    return tempos

def calcular_estatisticas(tempos: list[float]) -> dict:
    """Retorna média, desvio padrão e coeficiente de variação."""
    arr = np.array(tempos)
    media = arr.mean()
    desvio = arr.std(ddof=1)  # desvio padrão amostral
    cv = (desvio / media) * 100 if media != 0 else float("inf")
    return {"media": media, "desvio_padrao": desvio, "cv_pct": cv}

def limites_iqr(tempos: list[float], fator: float = 0.5):
    """Calcula limites inferior e superior usando o IQR (Intervalo Interquartil)."""
    arr = np.array(tempos)
    q1 = np.percentile(arr, 25)
    q3 = np.percentile(arr, 75)
    iqr = q3 - q1
    lim_inf = q1 - fator * iqr
    lim_sup = q3 + fator * iqr
    return lim_inf, lim_sup

def filtrar_outliers(tempos: list[float], lim_inf: float, lim_sup: float) -> list[float]:
    """Remove valores fora do intervalo [lim_inf, lim_sup]."""
    return [t for t in tempos if lim_inf <= t <= lim_sup]


def encontrar_picos_histograma(tempos: list[float], bins: int = 30):
    """
    Retorna as posições (centros dos bins) onde ocorrem os picos
    (máximos locais) do histograma.
    """
    contagens, bordas = np.histogram(tempos, bins=bins)
    centros = (bordas[:-1] + bordas[1:]) / 2

    picos_idx = []
    for i in range(1, len(contagens) - 1):
        if contagens[i] > contagens[i - 1] and contagens[i] > contagens[i + 1]:
            picos_idx.append(i)

    # incluir extremidades se forem máximos
    if len(contagens) > 1:
        if contagens[0] > contagens[1]:
            picos_idx.insert(0, 0)
        if contagens[-1] > contagens[-2]:
            picos_idx.append(len(contagens) - 1)

    return centros[picos_idx], contagens[picos_idx], centros, contagens, bordas


# ──────────────────────────────────────────────
# Execução principal
# ──────────────────────────────────────────────
def main():
    resultados = {}  # n -> {dados_brutos, dados_filtrados, stats_bruto, stats_filtrado, ...}

    for n in lista_n:
        print(f"\n{'='*60}")
        print(f" n = {n}  |  R = {R} repetições")
        print(f"{'='*60}")

        tempos = coletar_tempos(n, R)

        # ── Estatísticas ANTES da filtragem ──
        stats_bruto = calcular_estatisticas(tempos)
        print(f"\n  [ANTES da filtragem]")
        print(f"    Média .............. {stats_bruto['media']:.6e} s")
        print(f"    Desvio padrão ...... {stats_bruto['desvio_padrao']:.6e} s")
        print(f"    Coef. de variação .. {stats_bruto['cv_pct']:.2f} %")

        # ── Identificar picos ──
        picos_x, picos_y, centros, contagens, bordas = encontrar_picos_histograma(tempos)

        # ── Limites de corte (IQR) ──
        lim_inf, lim_sup = limites_iqr(tempos)
        print(f"\n  Limites de corte (IQR × 1.5):")
        print(f"    Inferior ........... {lim_inf:.6e} s")
        print(f"    Superior ........... {lim_sup:.6e} s")

        # ── Filtrar ──
        tempos_filtrados = filtrar_outliers(tempos, lim_inf, lim_sup)
        removidos = len(tempos) - len(tempos_filtrados)
        print(f"    Pontos removidos ... {removidos}")

        # ── Estatísticas DEPOIS da filtragem ──
        stats_filtrado = calcular_estatisticas(tempos_filtrados)
        print(f"\n  [DEPOIS da filtragem]")
        print(f"    Média .............. {stats_filtrado['media']:.6e} s")
        print(f"    Desvio padrão ...... {stats_filtrado['desvio_padrao']:.6e} s")
        print(f"    Coef. de variação .. {stats_filtrado['cv_pct']:.2f} %")

        resultados[n] = {
            "bruto": tempos,
            "filtrado": tempos_filtrados,
            "stats_bruto": stats_bruto,
            "stats_filtrado": stats_filtrado,
            "lim_inf": lim_inf,
            "lim_sup": lim_sup,
        }

        # ════════════════════════════════════════
        # GRÁFICOS
        # ════════════════════════════════════════
        fig, axes = plt.subplots(2, 2, figsize=(14, 10))
        fig.suptitle(f"Análise de tempos de execução — n = {n}", fontsize=14, fontweight="bold")

        # ── (0,0) Série temporal bruta ──
        ax = axes[0, 0]
        ax.plot(tempos, marker="o", markersize=3, linewidth=0.8, color="steelblue")
        ax.axhline(stats_bruto["media"], color="red", linestyle="--", linewidth=1, label="Média")
        ax.axhline(lim_sup, color="orange", linestyle=":", linewidth=1, label=f"Corte sup ({lim_sup:.2e})")
        ax.axhline(lim_inf, color="green", linestyle=":", linewidth=1, label=f"Corte inf ({lim_inf:.2e})")
        ax.set_title("Série temporal (dados brutos)")
        ax.set_xlabel("Repetição")
        ax.set_ylabel("Tempo (s)")
        ax.ticklabel_format(axis="y", style="sci", scilimits=(0, -4))
        ax.legend(fontsize=8)

        # ── (0,1) Histograma com picos e linhas horizontais ──
        ax = axes[0, 1]
        ax.bar(centros, contagens, width=bordas[1] - bordas[0], color="skyblue", edgecolor="navy", alpha=0.7)
        # linhas horizontais nos picos
        for px, py in zip(picos_x, picos_y):
            ax.axhline(py, color="red", linestyle="--", linewidth=0.8, alpha=0.6)
            ax.plot(px, py, "rv", markersize=10)  # triângulo vermelho no pico
            ax.annotate(
                f"{px:.2e}",
                xy=(px, py),
                xytext=(5, 5),
                textcoords="offset points",
                fontsize=7,
                color="darkred",
            )
        # linhas verticais de corte
        ax.axvline(lim_inf, color="green", linestyle=":", linewidth=1.2, label="Corte inferior")
        ax.axvline(lim_sup, color="orange", linestyle=":", linewidth=1.2, label="Corte superior")
        ax.set_title("Histograma + picos + linhas de corte")
        ax.set_xlabel("Tempo (s)")
        ax.set_ylabel("Frequência")
        ax.ticklabel_format(axis="x", style="sci", scilimits=(0, -4))
        ax.legend(fontsize=8)

        # ── (1,0) Histograma dos dados FILTRADOS ──
        ax = axes[1, 0]
        if tempos_filtrados:
            ax.hist(tempos_filtrados, bins=30, color="mediumseagreen", edgecolor="darkgreen", alpha=0.8)
            ax.axvline(
                stats_filtrado["media"],
                color="red",
                linestyle="--",
                linewidth=1.2,
                label=f"Média = {stats_filtrado['media']:.2e}",
            )
        ax.set_title("Histograma filtrado (sem outliers)")
        ax.set_xlabel("Tempo (s)")
        ax.set_ylabel("Frequência")
        ax.ticklabel_format(axis="x", style="sci", scilimits=(0, -4))
        ax.legend(fontsize=8)

        # ── (1,1) Tabela resumo ──
        ax = axes[1, 1]
        ax.axis("off")
        linhas = [
            ["", "Antes", "Depois"],
            ["Média (s)", f"{stats_bruto['media']:.6e}", f"{stats_filtrado['media']:.6e}"],
            ["Desvio padrão (s)", f"{stats_bruto['desvio_padrao']:.6e}", f"{stats_filtrado['desvio_padrao']:.6e}"],
            ["Coef. variação (%)", f"{stats_bruto['cv_pct']:.2f}", f"{stats_filtrado['cv_pct']:.2f}"],
            ["Amostras", str(len(tempos)), str(len(tempos_filtrados))],
            ["Removidos", "", str(removidos)],
        ]
        tabela = ax.table(
            cellText=linhas,
            loc="center",
            cellLoc="center",
        )
        tabela.auto_set_font_size(False)
        tabela.set_fontsize(10)
        tabela.scale(1.0, 1.6)
        # cabeçalho em destaque
        for j in range(3):
            tabela[0, j].set_facecolor("#4472C4")
            tabela[0, j].set_text_props(color="white", fontweight="bold")
        ax.set_title("Resumo estatístico", fontweight="bold")

        plt.tight_layout()
        plt.savefig(f"analise_n{n}.png", dpi=150, bbox_inches="tight")
        plt.show()

    print(f"\n{'='*60}")
    print("Análise concluída. Gráficos salvos como analise_n*.png")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
