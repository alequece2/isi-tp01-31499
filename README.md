# TP1 – Há campo? Integração da disponibilidade de campos de ténis de vários clubes

**Unidade curricular:** Integração de Sistemas de Informação (ISI) – 2026/27
**Curso:** Licenciatura em Engenharia de Sistemas Informáticos (pós-laboral) – IPCA
**Autor:** Alexandre Magalhães Martins Machado – n.º 31499 (trabalho individual)
**Docentes:** Luís Ferreira e Óscar Ribeiro

**Vídeo de demonstração:** _(link a colocar aqui)_
**Repositório Git:** https://github.com/alequece2/isi-tp01-31499

---

## O que faz

Três clubes de ténis (fictícios) registam as marcações dos campos de formas diferentes:

| Clube | Como regista | Ficheiro |
|---|---|---|
| CTV – Clube de Ténis do Vale | caderno do bar passado para Excel | `data/input/clube_a_caderno.csv` |
| TCN – Ténis Clube Norte | app de sócios que exporta JSON | `data/input/clube_b_app.json` |
| CDM – Complexo Desportivo Municipal | agenda municipal em XML (com XSD) | `data/input/clube_c_agenda.xml` |

O processo ETL, feito em **Pentaho Data Integration (Kettle) 10.2** com **PostgreSQL 17**:

1. **Extrai** as reservas dos 3 ficheiros, os dados dos clubes e campos da base de dados, e a previsão do tempo hora a hora da **API REST Open-Meteo**.
2. **Transforma**: normaliza com expressões regulares (datas, horas, campos, telefones), valida, remove duplicados e repetidos, anonimiza (SHA-256), faz lookups aos campos e horários, parte as reservas em blocos de 30 min, cruza com a meteorologia, deteta conflitos e calcula a taxa de ocupação.
3. **Carrega**: tabelas no PostgreSQL, quadro público em JSON e XML (sem dados pessoais), relatórios CSV (erros, duplicados, rejeitadas, conflitos, alertas, ocupação) e log.

O resultado é o quadro "livre/ocupado" do projeto **hacampo**: `src/quadro/index.html` lê o `disponibilidade.json` gerado pelo Kettle.

## Ficheiros

```
tp01-31499/
├── README.md
├── doc/
│   ├── 31499_doc.pdf              relatório final
│   ├── relatorio.html             fonte do relatório
│   └── figuras/                   diagramas das transformações e do job
├── dataintegration/
│   ├── j_hacampo.kjb              JOB principal (corre tudo pela ordem certa)
│   ├── t0_meteo_api.ktr           API Open-Meteo (JSON) -> meteo_hora
│   ├── t1_clube_a_csv.ktr         CSV -> limpeza com regex -> staging
│   ├── t2_clube_b_json.ktr        JSON -> limpeza -> staging
│   ├── t3_clube_c_xml.ktr         XML (XPath) -> limpeza -> staging
│   └── t4_consolidar_publicar.ktr staging -> blocos, meteo, conflitos -> BD, JSON, XML, CSV
├── data/
│   ├── input/                     ficheiros de entrada (+ XSD da agenda municipal)
│   └── output/                    exemplos das saídas de uma execução + execucao.log
└── src/
    ├── sql/01_criar_bd.sql        esquema e dados mestre (também embutido no job)
    └── quadro/index.html          página do quadro público que lê o JSON
```

## Como executar

**Requisitos**
- Pentaho Data Integration 10.2 (Kettle) com Java 11.
- PostgreSQL (testado com a 17) em `localhost:5432`, base de dados `postgres`, utilizador `postgres`. A palavra-passe de teste usada é `isi2026`. Se for outra, altere-a na ligação `hacampo_pg` no Spoon (separador *View → Database connections*).
- Internet para a API do tempo (sem internet o job avisa e continua com a última previsão guardada).

Não é preciso criar tabelas à mão: a primeira entrada do job cria o esquema `hacampo` e insere os clubes e campos.

**No Spoon**
1. Abrir `dataintegration/j_hacampo.kjb`.
2. Carregar em *Run* (▶). Os parâmetros podem ser alterados na janela de execução:
   - `DATA_INICIO` / `DATA_FIM`: semana pedida à API (por defeito 2026-10-21 a 2026-10-27).
   - `LIMITE_CHUVA`: % de chuva a partir da qual há alerta (por defeito 50).

**Na linha de comandos (Windows)**
```bat
cd C:\pdi\data-integration
Kitchen.bat -file="<caminho>\tp01-31499\dataintegration\j_hacampo.kjb" -level=Basic "-logfile=<caminho>\tp01-31499\data\output\execucao.log"
```

**Ver o quadro**
```bat
cd <caminho>\tp01-31499
python -m http.server 8765
```
Abrir http://localhost:8765/src/quadro/ (o browser não deixa ler ficheiros locais diretamente; também é possível abrir o `index.html` e escolher o `disponibilidade.json` à mão).

## Saídas (`data/output/`)

| Ficheiro | Conteúdo |
|---|---|
| `disponibilidade.json` / `.xml` | blocos de 30 min ocupados por clube/campo/dia, com conflito, chuva e luz (sem dados pessoais) |
| `erros_clube_a.csv` | linhas do caderno que não se conseguem ler (sem hora, data sem ano) |
| `repetidas_clube_b.csv` | registos que a app enviou 2 vezes (mesmo id) |
| `duplicados.csv` | a mesma reserva escrita 2 vezes |
| `rejeitadas.csv` | campo que não existe ou reserva fora do horário do clube |
| `conflitos.csv` | 2 reservas no mesmo campo à mesma hora |
| `alertas.csv` | jogo à noite num campo sem luz, ou chuva prevista num campo descoberto |
| `ocupacao_diaria.csv` | taxa de ocupação por campo e dia |
| `execucao.log` | log do Kitchen |

Tabelas no PostgreSQL (esquema `hacampo`): `clubes`, `campos`, `stg_reservas`, `meteo_hora`, `ocupacao_slot`, `ocupacao_diaria`.

## Notas

- Os dados dos clubes são inventados (com erros de propósito, para haver o que limpar). A previsão do tempo é real.
- Uso de IA: declarado no relatório (secção "Declaração de utilização de IA").
