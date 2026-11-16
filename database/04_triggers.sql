/* ============================================================
   CEICONTROL - 04. TRIGGERS
   Bloco A (Requisito 13): triggers de validação/automação
   Bloco B (Requisito 14): triggers que acionam FUNÇÕES/PROCEDURES
   ============================================================ */

USE ceicontrol;

DROP TRIGGER IF EXISTS trg_produtos_bu_valida_estoque;
DROP TRIGGER IF EXISTS trg_mov_ai_atualiza_saldo;
DROP TRIGGER IF EXISTS trg_frequencias_bi_valida;
DROP TRIGGER IF EXISTS trg_mensagens_bi_valida;
DROP TRIGGER IF EXISTS trg_usuarios_bd_protege_admin;
DROP TRIGGER IF EXISTS trg_criancas_bi_valida;
DROP TRIGGER IF EXISTS trg_criancas_ad_auditoria;
DROP TRIGGER IF EXISTS trg_responsaveis_bi_valida_cpf;
DROP TRIGGER IF EXISTS trg_matriculas_bi_valida;
DROP TRIGGER IF EXISTS trg_matriculas_ai_auditoria;
DROP TRIGGER IF EXISTS trg_matriculas_bu_valida;
DROP TRIGGER IF EXISTS trg_matriculas_au_auditoria;
DROP TRIGGER IF EXISTS trg_medicamentos_bi_valida;
DROP TRIGGER IF EXISTS trg_produtos_au_alerta;

DELIMITER $$

/* ------------------------------------------------------------
   BLOCO A - Requisito 13 (validação, automação)
   ------------------------------------------------------------ */

-- A1. Validação: o estoque de um insumo nunca pode ficar negativo
CREATE TRIGGER trg_produtos_bu_valida_estoque
BEFORE UPDATE ON produtos
FOR EACH ROW
BEGIN
    DECLARE v_msg VARCHAR(255);
    IF NEW.quantidade < 0 THEN
        SET v_msg = CONCAT('Estoque insuficiente de "', OLD.nome, '": saldo ', OLD.quantidade,
                           ', saída solicitada ', OLD.quantidade - NEW.quantidade, '.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- A2. Automação: cada movimentação atualiza o saldo do produto
CREATE TRIGGER trg_mov_ai_atualiza_saldo
AFTER INSERT ON movimentacoes_estoque
FOR EACH ROW
BEGIN
    UPDATE produtos
       SET quantidade = quantidade + IF(NEW.tipo = 'Entrada', NEW.quantidade, -NEW.quantidade)
     WHERE id = NEW.produto_id;
END$$

-- A3. Validação: frequência só em dia útil, nunca no futuro e só para matrícula ativa
CREATE TRIGGER trg_frequencias_bi_valida
BEFORE INSERT ON frequencias
FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    IF NEW.data_aula > CURDATE() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não é permitido lançar frequência em data futura.';
    END IF;
    IF DAYOFWEEK(NEW.data_aula) IN (1, 7) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não há atendimento aos sábados e domingos.';
    END IF;

    SELECT status INTO v_status FROM matriculas WHERE id = NEW.matricula_id;
    IF v_status <> 'Ativa' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Frequência só pode ser lançada para matrícula ativa.';
    END IF;

    IF NEW.presente = 1 THEN
        SET NEW.justificativa = NULL;
    END IF;
END$$

-- A4. Validação do chat: sem mensagem vazia e sem enviar para si mesmo
CREATE TRIGGER trg_mensagens_bi_valida
BEFORE INSERT ON mensagens
FOR EACH ROW
BEGIN
    IF NEW.remetente_id = NEW.destinatario_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Remetente e destinatário não podem ser o mesmo usuário.';
    END IF;
    IF TRIM(NEW.mensagem) = '' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A mensagem não pode ser vazia.';
    END IF;
    SET NEW.mensagem = TRIM(NEW.mensagem);
END$$

-- A5. Proteção: o último administrador do sistema não pode ser excluído
CREATE TRIGGER trg_usuarios_bd_protege_admin
BEFORE DELETE ON usuarios
FOR EACH ROW
BEGIN
    IF OLD.perfil = 'admin'
       AND (SELECT COUNT(*) FROM usuarios WHERE perfil = 'admin') <= 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Não é possível excluir o último administrador.';
    END IF;
END$$

/* ------------------------------------------------------------
   BLOCO B - Requisito 14 (triggers que acionam funções/procedures)
   ------------------------------------------------------------ */

-- B1. Crianças: valida CPF e data de nascimento  -> fn_valida_cpf, fn_idade_meses
CREATE TRIGGER trg_criancas_bi_valida
BEFORE INSERT ON criancas
FOR EACH ROW
BEGIN
    SET NEW.nome = TRIM(NEW.nome);
    IF fn_idade_meses(NEW.data_nascimento, CURDATE()) < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Data de nascimento no futuro.';
    END IF;
    IF NEW.cpf IS NOT NULL AND fn_valida_cpf(NEW.cpf) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF da criança inválido.';
    END IF;
END$$

-- B2. Crianças: auditoria de exclusão  -> CALL sp_registrar_auditoria
CREATE TRIGGER trg_criancas_ad_auditoria
AFTER DELETE ON criancas
FOR EACH ROW
BEGIN
    CALL sp_registrar_auditoria('criancas', 'DELETE', OLD.id,
        CONCAT('Cadastro removido: ', OLD.nome, ' (nasc. ', DATE_FORMAT(OLD.data_nascimento, '%d/%m/%Y'), ')'));
END$$

-- B3. Responsáveis: CPF obrigatório e válido  -> fn_valida_cpf
CREATE TRIGGER trg_responsaveis_bi_valida_cpf
BEFORE INSERT ON responsaveis
FOR EACH ROW
BEGIN
    IF fn_valida_cpf(NEW.cpf) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'CPF do responsável inválido.';
    END IF;
END$$

-- B4. Matrícula: vaga, faixa etária e ano letivo  -> fn_vagas_disponiveis, fn_idade_compativel
CREATE TRIGGER trg_matriculas_bi_valida
BEFORE INSERT ON matriculas
FOR EACH ROW
BEGIN
    DECLARE v_ano_turma YEAR;

    SELECT ano_letivo INTO v_ano_turma FROM turmas WHERE id = NEW.turma_id;
    IF NEW.ano_letivo <> v_ano_turma THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ano letivo da matrícula diferente do ano da turma.';
    END IF;
    IF NEW.status = 'Ativa' AND fn_vagas_disponiveis(NEW.turma_id) <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma sem vagas disponíveis.';
    END IF;
    IF fn_idade_compativel(NEW.crianca_id, NEW.turma_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Idade da criança fora da faixa etária da turma.';
    END IF;
END$$

-- B5. Matrícula: auditoria de inclusão  -> CALL sp_registrar_auditoria
CREATE TRIGGER trg_matriculas_ai_auditoria
AFTER INSERT ON matriculas
FOR EACH ROW
BEGIN
    CALL sp_registrar_auditoria('matriculas', 'INSERT', NEW.id,
        CONCAT('Criança ', NEW.crianca_id, ' matriculada na turma ', NEW.turma_id,
               ' (', NEW.ano_letivo, ') com status ', NEW.status));
END$$

-- B6. Matrícula: fluxo de status e vaga na transferência  -> fn_vagas_disponiveis, fn_idade_compativel
CREATE TRIGGER trg_matriculas_bu_valida
BEFORE UPDATE ON matriculas
FOR EACH ROW
BEGIN
    IF OLD.status IN ('Cancelada', 'Concluída') AND NEW.status <> OLD.status THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula cancelada/concluída não pode ser reaberta.';
    END IF;

    IF NEW.status = 'Ativa'
       AND (NEW.turma_id <> OLD.turma_id OR OLD.status <> 'Ativa')
       AND fn_vagas_disponiveis(NEW.turma_id) <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma de destino sem vagas disponíveis.';
    END IF;

    IF NEW.turma_id <> OLD.turma_id AND fn_idade_compativel(NEW.crianca_id, NEW.turma_id) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Idade da criança fora da faixa etária da turma de destino.';
    END IF;
END$$

-- B7. Matrícula: auditoria de alterações  -> CALL sp_registrar_auditoria
CREATE TRIGGER trg_matriculas_au_auditoria
AFTER UPDATE ON matriculas
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status OR NEW.turma_id <> OLD.turma_id THEN
        CALL sp_registrar_auditoria('matriculas', 'UPDATE', NEW.id,
            CONCAT('Status: ', OLD.status, ' -> ', NEW.status,
                   ' | Turma: ', OLD.turma_id, ' -> ', NEW.turma_id));
    END IF;
END$$

-- B8. Medicamentos: intervalo mínimo de 4h entre doses e quem pode administrar
--     -> fn_intervalo_dose_minutos
CREATE TRIGGER trg_medicamentos_bi_valida
BEFORE INSERT ON medicamentos_dispensas
FOR EACH ROW
BEGIN
    DECLARE v_intervalo INT;
    DECLARE v_perfil VARCHAR(20);
    DECLARE v_msg VARCHAR(255);

    SELECT perfil INTO v_perfil FROM usuarios WHERE id = NEW.administrado_por;
    IF v_perfil = 'cliente' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Somente funcionários do CEI podem administrar medicamentos.';
    END IF;

    SET v_intervalo = fn_intervalo_dose_minutos(NEW.crianca_id, NEW.medicamento, NEW.data_hora);
    IF v_intervalo IS NOT NULL AND v_intervalo < 240 THEN
        SET v_msg = CONCAT('Intervalo mínimo de 4h entre doses não respeitado (', v_intervalo, ' min).');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
END$$

-- B9. Estoque: alerta quando o insumo entra em nível crítico/esgotado
--     -> fn_situacao_estoque + CALL sp_registrar_auditoria
CREATE TRIGGER trg_produtos_au_alerta
AFTER UPDATE ON produtos
FOR EACH ROW
BEGIN
    IF fn_situacao_estoque(NEW.quantidade, NEW.estoque_minimo) IN ('Crítico', 'Esgotado')
       AND fn_situacao_estoque(OLD.quantidade, OLD.estoque_minimo) NOT IN ('Crítico', 'Esgotado') THEN
        CALL sp_registrar_auditoria('produtos', 'ALERTA', NEW.id,
            CONCAT('Estoque ', fn_situacao_estoque(NEW.quantidade, NEW.estoque_minimo),
                   ' de "', NEW.nome, '": ', NEW.quantidade, ' un. (mínimo ', NEW.estoque_minimo, ')'));
    END IF;
END$$

DELIMITER ;
