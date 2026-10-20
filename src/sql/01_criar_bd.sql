-- =====================================================================
-- hacampo - base de dados do TP1 (PostgreSQL)
-- Corre automaticamente no inicio do job (entrada "Preparar base de dados (SQL)").
-- Pode ser corrido varias vezes (CREATE ... IF NOT EXISTS / ON CONFLICT).
-- O mesmo SQL esta copiado dentro do job (para os acentos serem lidos em UTF-8).
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS hacampo;

-- ---------------------------------------------------------------------
-- Dados mestre (fonte "base de dados relacional")
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hacampo.clubes (
    codigo      VARCHAR(5)   PRIMARY KEY,
    nome        VARCHAR(80)  NOT NULL,
    cidade      VARCHAR(40),
    latitude    NUMERIC(8,5) NOT NULL,
    longitude   NUMERIC(8,5) NOT NULL,
    abertura    INTEGER      NOT NULL,   -- hora a que abre (ex.: 8)
    fecho       INTEGER      NOT NULL,   -- hora a que fecha (ex.: 22)
    origem      VARCHAR(20)  NOT NULL    -- como o clube regista as marcacoes
);

CREATE TABLE IF NOT EXISTS hacampo.campos (
    clube       VARCHAR(5)  NOT NULL REFERENCES hacampo.clubes(codigo),
    campo       VARCHAR(5)  NOT NULL,
    piso        VARCHAR(30),
    coberto     BOOLEAN     NOT NULL,
    iluminacao  BOOLEAN     NOT NULL,
    PRIMARY KEY (clube, campo)
);

INSERT INTO hacampo.clubes VALUES
 ('CTV', 'Clube de Ténis do Vale',        'Braga',     41.55030, -8.42010,  8, 22, 'caderno (CSV)'),
 ('TCN', 'Ténis Clube Norte',             'Guimarães', 41.44430, -8.29620,  8, 23, 'app (JSON)'),
 ('CDM', 'Complexo Desportivo Municipal', 'Famalicão', 41.40790, -8.51980,  9, 21, 'agenda (XML)')
ON CONFLICT (codigo) DO UPDATE SET nome = EXCLUDED.nome, cidade = EXCLUDED.cidade,
  latitude = EXCLUDED.latitude, longitude = EXCLUDED.longitude, abertura = EXCLUDED.abertura, fecho = EXCLUDED.fecho;

INSERT INTO hacampo.campos VALUES
 ('CTV', '1', 'piso rápido',     TRUE,  TRUE),
 ('CTV', '2', 'terra batida',    FALSE, TRUE),
 ('CTV', '3', 'terra batida',    FALSE, FALSE),
 ('TCN', '1', 'piso rápido',     FALSE, TRUE),
 ('TCN', '2', 'piso rápido',     FALSE, TRUE),
 ('TCN', '3', 'relva sintética', FALSE, FALSE),
 ('TCN', '4', 'piso rápido',     TRUE,  TRUE),
 ('CDM', '1', 'piso rápido',     FALSE, TRUE),
 ('CDM', '2', 'piso rápido',     FALSE, TRUE),
 ('CDM', '3', 'piso rápido',     TRUE,  TRUE)
ON CONFLICT (clube, campo) DO UPDATE SET piso = EXCLUDED.piso, coberto = EXCLUDED.coberto, iluminacao = EXCLUDED.iluminacao;

-- ---------------------------------------------------------------------
-- Staging: as 3 transformacoes de entrada escrevem aqui no mesmo formato
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hacampo.stg_reservas (
    origem           VARCHAR(20) NOT NULL,
    clube            VARCHAR(5)  NOT NULL,
    campo            VARCHAR(5),
    data             DATE        NOT NULL,
    inicio_min       INTEGER     NOT NULL,   -- minutos desde a meia-noite (18:30 -> 1110)
    fim_min          INTEGER     NOT NULL,
    tipo             VARCHAR(20),
    cliente_hash     VARCHAR(64),            -- SHA-256 do contacto (anonimizado)
    contacto_valido  BOOLEAN
);

-- Previsao do tempo por clube e por hora (Open-Meteo)
CREATE TABLE IF NOT EXISTS hacampo.meteo_hora (
    clube        VARCHAR(5)  NOT NULL,
    data_hora    VARCHAR(16) NOT NULL,       -- 2026-10-21T18:00
    prob_chuva   INTEGER,
    e_dia        INTEGER,                    -- 1 = dia, 0 = noite
    PRIMARY KEY (clube, data_hora)
);

-- ---------------------------------------------------------------------
-- Resultado final
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS hacampo.ocupacao_slot (
    clube         VARCHAR(5)  NOT NULL,
    campo         VARCHAR(5)  NOT NULL,
    data          DATE        NOT NULL,
    hora          VARCHAR(5)  NOT NULL,      -- inicio do bloco de 30 min
    nr_reservas   INTEGER     NOT NULL,      -- >1 = conflito
    conflito      BOOLEAN,
    coberto       BOOLEAN,
    prob_chuva    INTEGER,
    risco_chuva   BOOLEAN,
    precisa_luz   BOOLEAN,
    sem_luz       BOOLEAN,
    PRIMARY KEY (clube, campo, data, hora)
);

CREATE TABLE IF NOT EXISTS hacampo.ocupacao_diaria (
    clube            VARCHAR(5) NOT NULL,
    campo            VARCHAR(5) NOT NULL,
    data             DATE       NOT NULL,
    slots_ocupados   INTEGER,
    slots_totais     INTEGER,
    taxa_ocupacao    NUMERIC(5,1),
    PRIMARY KEY (clube, campo, data)
);

-- Cada execucao recomeca a staging do zero
TRUNCATE TABLE hacampo.stg_reservas;
