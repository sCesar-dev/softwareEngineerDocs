# Software Engineer Docs — Engenharia de Programas (2026.2)

> Repositório oficial de documentação, experimentos práticos e relatórios técnicos da disciplina de **Engenharia de Programas**  
> **Universidade do Estado da Bahia (UNEB) — Departamento de Ciências Exatas e da Terra (DCET I)**  
> **Docente Responsável:** Prof. Dr. Diego Gervasio Frias Suarez  
> **Equipe BIG O:** Samuel Cesar ([@sCesar-dev](https://github.com/sCesar-dev)), Pedro Henrique e Pedro Lucas  

---

## 📌 Sumário do Repositório

O repositório reúne implementações, bancos de dados amostrais, cadernos interativos Jupyter, medições de bancada física e relatórios científicos desenvolvidos ao longo dos Créditos da disciplina, orientados pela **Metodologia F.O.C.A.** e controle empírico rigoroso de execução computacional.

```
softwareEngineerDocs/
├── docs/
│   ├── trabalho01/        # Crédito 1: Validação de Setup Computacional e Estabilidade
│   ├── trabalho02/        # Crédito 1/2: Estimativa de Tempo BIG O & Primitivas F.O.C.A.
│   ├── trabalho03/        # Crédito 2: Algoritmo FCM Puro & Restrições Arquiteturais
│   ├── samuca_files/      # Scripts de bancada, experimentadores e cadernos de aula
│   └── images/            # Recursos visuais e gráficos gerados
├── src/                   # Scripts basilares e explorações iniciais de tempo
├── requirements.txt       # Dependências Python do ecossistema do projeto
└── LICENSE                # Licença MIT
```

---

## 📂 Módulos e Trabalhos

### 🔹 [Trabalho 01 — Validação de Setup Computacional](docs/trabalho01/)
- **Objetivo:** Validação do ambiente de teste físico e calibração de latências básicas perante ruídos do Sistema Operacional.
- **Métricas:** Estabilidade por repetições amostrais ($R = 30$), análise de dispersão e validação com Coeficiente de Variação ($CV < 0.15$).
- **Ambiente:** Processador AMD Ryzen™ 7 5700U com fixação de afinidade (`taskset -c 13`).
- **Arquivos:** [`RTA - Validação de Setup Computacional V3.docx`](docs/trabalho01/RTA%20-%20Valida%C3%A7%C3%A3o%20de%20Setup%20Computacional%20V3.docx) e [`RTA_BigOTeam.ipynb`](docs/trabalho01/RTA_BigOTeam.ipynb).

### 🔹 [Trabalho 02 — Estimativa de Tempo BIG O & Macro-Primitivas F.O.C.A.](docs/trabalho02/)
- **Objetivo:** Decomposição analítica e medição experimental dos custos temporais das 4 macro-primitivas:
  - Atribuições ($\tau_a$)
  - Comparações ($\tau_c$)
  - Operações Matemáticas ($\tau_o$)
  - Chamadas de Função ($\tau_f$)
- **Arquivos:** [`estimativa_tempo_BIG_O.ipynb`](docs/trabalho02/estimativa_tempo_BIG_O.ipynb) e scripts em `scripts/`.

### 🔹 [Trabalho 03 — Algoritmo Fuzzy C-Means (FCM) & Restrições Arquiteturais](docs/trabalho03/README.md)
- **Objetivo:** Implementação do algoritmo FCM puro (*from scratch*), respeitando as diretrizes do tribunal arquitetural e aplicando intervenções cirúrgicas de microarquitetura (*Memory Flattening*, *Fixed-Point*, *Structure of Arrays*, *Loop Unrolling*, *Early Exit*, *Loop Fission*).
- **Modelagem Empírica:** Levantamento e ajuste polinomial da função tempo:
  $$T_{exp}(n, K) = \alpha \cdot (n \cdot K) + \beta \cdot n + \gamma \cdot K + \delta$$
- **Documentação Detalhada:** Consulte o [README do Trabalho 03](docs/trabalho03/README.md).
- **Relatório Técnico:** [`docs/trabalho03/Relatório_Credito2_EP/main.tex`](docs/trabalho03/Relat%C3%B3rio_Credito2_EP/main.tex).

---

## 🛠️ Configuração do Ambiente e Instalação

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/sCesar-dev/softwareEngineerDocs.git
   cd softwareEngineerDocs
   ```

2. **Crie e ative o ambiente virtual Python:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```

3. **Instale as dependências:**
   ```bash
   pip install -r requirements.txt
   ```

---

## ⚡ Execução Rápida

- **Executar a bancada do FCM baseline (Trabalho 03):**
  ```bash
  cd docs/trabalho03
  python FCM_PURO_v3.py
  ```

- **Executar a bancada com isolamento de CPU:**
  ```bash
  taskset -c 13 python docs/samuca_files/scripts/experimentador_EP_2026.2.py
  ```

---

## 📄 Licença

Este projeto é distribuído sob os termos da licença MIT. Consulte o arquivo [LICENSE](LICENSE) para mais informações.

