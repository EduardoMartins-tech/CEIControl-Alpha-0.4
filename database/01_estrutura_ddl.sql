/* ============================================================
   CEICONTROL - 01. ESTRUTURA (DDL) + ÍNDICES
   Requisitos atendidos: 2 (DDL com PK/FK/NOT NULL/UNIQUE/CHECK)
                         10 (índices explícitos)
   Pré-requisito: tabelas.sql (raiz do projeto) já executado.
   Compatível com MySQL 8.0.16+ e MariaDB 10.4+.
   ============================================================ */

USE ceicontrol;

-- ------------------------------------------------------------
-- Ajustes nas tabelas existentes (produtos passa a se relacionar
-- com fornecedores e ganha controle de estoque mínimo)
-- ------------------------------------------------------------
ALTER TABLE produtos
    ADD COLUMN categoria ENUM('Alimento','Higiene','Pedagógico','Limpeza','Escritório')
        NOT NULL DEFAULT 'Pedagógico' AFTER descricao,
    ADD COLUMN estoque_minimo INT NOT NULL DEFAULT 10 AFTER quantidade,
    ADD COLUMN fornecedor_id INT NULL AFTER estoque_minimo,
    ADD CONSTRAINT fk_produtos_fornecedor
        FOREIGN KEY (fornecedor_id) REFERENCES fornecedores(id) ON DELETE SET NULL,
    ADD CONSTRAINT ck_produtos_quantidade CHECK (quantidade >= 0),
    ADD CONSTRAINT ck_produtos_estoque_minimo CHECK (estoque_minimo >= 0);

-- ------------------------------------------------------------
-- 7. Turmas
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS turmas (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    nome             VARCHAR(60)  NOT NULL,
    periodo          ENUM('Integral','Manhã','Tarde') NOT NULL,
    idade_min_meses  INT          NOT NULL,
    idade_max_meses  INT          NOT NULL,
    capacidade       INT          NOT NULL,
    ano_letivo       YEAR         NOT NULL,
    sala             VARCHAR(30)  NOT NULL,
    educador_id      INT          NULL,
    CONSTRAINT uq_turmas_nome_ano UNIQUE (nome, ano_letivo),
    CONSTRAINT ck_turmas_faixa CHECK (idade_min_meses >= 0 AND idade_min_meses < idade_max_meses),
    CONSTRAINT ck_turmas_capacidade CHECK (capacidade BETWEEN 1 AND 40),
    CONSTRAINT fk_turmas_educador FOREIGN KEY (educador_id)
        REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 8. Crianças
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criancas (
    id                   INT AUTO_INCREMENT PRIMARY KEY,
    nome                 VARCHAR(100) NOT NULL,
    data_nascimento      DATE         NOT NULL,
    cpf                  VARCHAR(14)  NULL,
    sexo                 ENUM('F','M') NOT NULL,
    alergias             VARCHAR(255) NULL,
    restricao_alimentar  VARCHAR(255) NULL,
    ativo                TINYINT(1)   NOT NULL DEFAULT 1,
    data_cadastro        DATE         NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT uq_criancas_cpf UNIQUE (cpf)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 9. Responsáveis (pode ou não ter login no sistema)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS responsaveis (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id  INT          NULL,
    nome        VARCHAR(100) NOT NULL,
    cpf         VARCHAR(14)  NOT NULL,
    telefone    VARCHAR(20)  NOT NULL,
    email       VARCHAR(100) NULL,
    CONSTRAINT uq_responsaveis_cpf UNIQUE (cpf),
    CONSTRAINT uq_responsaveis_usuario UNIQUE (usuario_id),
    CONSTRAINT fk_responsaveis_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 10. Criança x Responsável (associativa N:N)
--     'Avó/Avô' é um valor só: no MySQL 8 a collation padrão ignora
--     acentos, e 'Avó' e 'Avô' no mesmo ENUM seriam duplicados.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS crianca_responsavel (
    crianca_id         INT NOT NULL,
    responsavel_id     INT NOT NULL,
    parentesco         ENUM('Mãe','Pai','Avó/Avô','Tio(a)','Outro') NOT NULL,
    autorizado_buscar  TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (crianca_id, responsavel_id),
    CONSTRAINT fk_cr_crianca FOREIGN KEY (crianca_id)
        REFERENCES criancas(id) ON DELETE CASCADE,
    CONSTRAINT fk_cr_responsavel FOREIGN KEY (responsavel_id)
        REFERENCES responsaveis(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 11. Matrículas (criança N:1 turma, por ano letivo)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS matriculas (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    crianca_id      INT  NOT NULL,
    turma_id        INT  NOT NULL,
    ano_letivo      YEAR NOT NULL,
    data_matricula  DATE NOT NULL,
    status          ENUM('Ativa','Trancada','Cancelada','Concluída') NOT NULL DEFAULT 'Ativa',
    CONSTRAINT uq_matriculas_crianca_ano UNIQUE (crianca_id, ano_letivo),
    CONSTRAINT fk_matriculas_crianca FOREIGN KEY (crianca_id)
        REFERENCES criancas(id) ON DELETE RESTRICT,
    CONSTRAINT fk_matriculas_turma FOREIGN KEY (turma_id)
        REFERENCES turmas(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 12. Frequência diária
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS frequencias (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    matricula_id    INT          NOT NULL,
    data_aula       DATE         NOT NULL,
    presente        TINYINT(1)   NOT NULL,
    justificativa   VARCHAR(255) NULL,
    registrado_por  INT          NULL,
    CONSTRAINT uq_frequencias_matricula_dia UNIQUE (matricula_id, data_aula),
    CONSTRAINT fk_frequencias_matricula FOREIGN KEY (matricula_id)
        REFERENCES matriculas(id) ON DELETE CASCADE,
    CONSTRAINT fk_frequencias_usuario FOREIGN KEY (registrado_por)
        REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 13. Cardápio (refeições planejadas)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cardapios (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    data_refeicao  DATE NOT NULL,
    tipo_refeicao  ENUM('Café da manhã','Almoço','Lanche da tarde','Jantar') NOT NULL,
    descricao      VARCHAR(255) NOT NULL,
    calorias       INT NULL,
    baixa_estoque  TINYINT(1) NOT NULL DEFAULT 0,
    CONSTRAINT uq_cardapios_dia_tipo UNIQUE (data_refeicao, tipo_refeicao),
    CONSTRAINT ck_cardapios_calorias CHECK (calorias IS NULL OR calorias > 0)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 14. Insumos do cardápio (associativa cardápio N:N produto)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cardapio_insumos (
    cardapio_id           INT NOT NULL,
    produto_id            INT NOT NULL,
    quantidade_utilizada  INT NOT NULL,
    PRIMARY KEY (cardapio_id, produto_id),
    CONSTRAINT ck_ci_quantidade CHECK (quantidade_utilizada > 0),
    CONSTRAINT fk_ci_cardapio FOREIGN KEY (cardapio_id)
        REFERENCES cardapios(id) ON DELETE CASCADE,
    CONSTRAINT fk_ci_produto FOREIGN KEY (produto_id)
        REFERENCES produtos(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 15. Dispensa (administração) de medicamentos
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS medicamentos_dispensas (
    id                INT AUTO_INCREMENT PRIMARY KEY,
    crianca_id        INT          NOT NULL,
    medicamento       VARCHAR(100) NOT NULL,
    dosagem           VARCHAR(50)  NOT NULL,
    data_hora         DATETIME     NOT NULL,
    administrado_por  INT          NOT NULL,
    receita_medica    TINYINT(1)   NOT NULL DEFAULT 0,
    observacao        VARCHAR(255) NULL,
    CONSTRAINT uq_med_crianca_horario UNIQUE (crianca_id, medicamento, data_hora),
    CONSTRAINT fk_med_crianca FOREIGN KEY (crianca_id)
        REFERENCES criancas(id) ON DELETE RESTRICT,
    CONSTRAINT fk_med_usuario FOREIGN KEY (administrado_por)
        REFERENCES usuarios(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 16. Movimentações de estoque (entradas/saídas de insumos)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS movimentacoes_estoque (
    id                 INT AUTO_INCREMENT PRIMARY KEY,
    produto_id         INT NOT NULL,
    fornecedor_id      INT NULL,
    usuario_id         INT NULL,
    tipo               ENUM('Entrada','Saída') NOT NULL,
    quantidade         INT NOT NULL,
    valor_unitario     DECIMAL(10,2) NULL,
    data_movimentacao  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    motivo             VARCHAR(150) NOT NULL,
    CONSTRAINT ck_mov_quantidade CHECK (quantidade > 0),
    CONSTRAINT fk_mov_produto FOREIGN KEY (produto_id)
        REFERENCES produtos(id) ON DELETE RESTRICT,
    CONSTRAINT fk_mov_fornecedor FOREIGN KEY (fornecedor_id)
        REFERENCES fornecedores(id) ON DELETE SET NULL,
    CONSTRAINT fk_mov_usuario FOREIGN KEY (usuario_id)
        REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 17. Auditoria (alimentada por triggers)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auditoria (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    tabela       VARCHAR(64)  NOT NULL,
    operacao     ENUM('INSERT','UPDATE','DELETE','ALERTA') NOT NULL,
    registro_id  INT          NOT NULL,
    detalhes     VARCHAR(500) NOT NULL,
    usuario_bd   VARCHAR(100) NOT NULL,
    data_hora    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- ÍNDICES EXPLÍCITOS (Requisito 10)
-- Cada índice atende a um filtro/ordenação frequente do sistema.
-- ============================================================

-- Busca de crianças pelo nome (tela de cadastro / chamada)
CREATE INDEX idx_criancas_nome ON criancas (nome);

-- Contagem de vagas: WHERE turma_id = ? AND status = 'Ativa'
CREATE INDEX idx_matriculas_turma_status ON matriculas (turma_id, status);

-- Relatórios de frequência por período: WHERE data_aula BETWEEN ? AND ?
CREATE INDEX idx_frequencias_data_presente ON frequencias (data_aula, presente);

-- Extrato do estoque por produto e período
CREATE INDEX idx_mov_produto_data ON movimentacoes_estoque (produto_id, data_movimentacao);

-- Histórico de medicamentos da criança (e regra do intervalo entre doses)
CREATE INDEX idx_med_crianca_medicamento_data ON medicamentos_dispensas (crianca_id, medicamento, data_hora);

-- Agenda: listagem por data e filtro de público-alvo (EventoModel::listarPorPerfil)
CREATE INDEX idx_agenda_data_publico ON agenda (data_evento, publico_alvo);

-- Painel de estoque: produtos por categoria abaixo do mínimo
CREATE INDEX idx_produtos_categoria_qtd ON produtos (categoria, quantidade);

-- Conversa do chat: WHERE remetente_id = ? AND destinatario_id = ? ORDER BY data_envio
CREATE INDEX idx_mensagens_conversa ON mensagens (remetente_id, destinatario_id, data_envio);

-- Consulta da trilha de auditoria por tabela/data
CREATE INDEX idx_auditoria_tabela_data ON auditoria (tabela, data_hora);
