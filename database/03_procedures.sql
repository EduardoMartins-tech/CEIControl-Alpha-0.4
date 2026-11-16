/* ============================================================
   CEICONTROL - 03. STORED PROCEDURES (Requisito 11)
   Automação de processos da creche. As que alteram várias
   linhas usam transação com ROLLBACK automático em erro
   (também contam para o Requisito 15).
   ============================================================ */

USE ceicontrol;

DROP PROCEDURE IF EXISTS sp_registrar_auditoria;
DROP PROCEDURE IF EXISTS sp_matricular_crianca;
DROP PROCEDURE IF EXISTS sp_transferir_turma;
DROP PROCEDURE IF EXISTS sp_registrar_chamada;
DROP PROCEDURE IF EXISTS sp_movimentar_estoque;
DROP PROCEDURE IF EXISTS sp_baixa_insumos_cardapio;
DROP PROCEDURE IF EXISTS sp_relatorio_frequencia_turma;
DROP PROCEDURE IF EXISTS sp_alerta_estoque_baixo;

DELIMITER $$

-- P1. Grava um registro na trilha de auditoria (chamada pelos triggers)
CREATE PROCEDURE sp_registrar_auditoria(
    IN p_tabela      VARCHAR(64),
    IN p_operacao    VARCHAR(10),
    IN p_registro_id INT,
    IN p_detalhes    VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    INSERT INTO auditoria (tabela, operacao, registro_id, detalhes, usuario_bd)
    VALUES (p_tabela, p_operacao, p_registro_id, LEFT(p_detalhes, 500), USER());
END$$

-- P2. Matricula uma criança numa turma (transação + validação via trigger)
CREATE PROCEDURE sp_matricular_crianca(
    IN  p_crianca_id     INT,
    IN  p_turma_id       INT,
    IN  p_data_matricula DATE,
    OUT p_matricula_id   INT,
    OUT p_mensagem       VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_ano YEAR;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_mensagem = MESSAGE_TEXT;
        ROLLBACK;
        SET p_matricula_id = NULL;
        SET p_mensagem = CONCAT('Matrícula NÃO realizada: ', p_mensagem);
    END;

    START TRANSACTION;

    -- trava a turma para que duas matrículas simultâneas não estourem a capacidade
    SELECT ano_letivo INTO v_ano FROM turmas WHERE id = p_turma_id FOR UPDATE;
    IF v_ano IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Turma inexistente.';
    END IF;

    INSERT INTO matriculas (crianca_id, turma_id, ano_letivo, data_matricula, status)
    VALUES (p_crianca_id, p_turma_id, v_ano, p_data_matricula, 'Ativa');
    SET p_matricula_id = LAST_INSERT_ID();

    UPDATE criancas SET ativo = 1 WHERE id = p_crianca_id;

    COMMIT;
    SET p_mensagem = CONCAT('Matrícula ', p_matricula_id, ' realizada com sucesso.');
END$$

-- P3. Transfere uma matrícula ativa para outra turma (transação)
CREATE PROCEDURE sp_transferir_turma(
    IN  p_matricula_id   INT,
    IN  p_nova_turma_id  INT,
    OUT p_mensagem       VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_turma_atual INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_mensagem = MESSAGE_TEXT;
        ROLLBACK;
        SET p_mensagem = CONCAT('Transferência NÃO realizada: ', p_mensagem);
    END;

    START TRANSACTION;

    SELECT turma_id INTO v_turma_atual
      FROM matriculas
     WHERE id = p_matricula_id AND status = 'Ativa'
       FOR UPDATE;

    IF v_turma_atual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Matrícula inexistente ou não está ativa.';
    END IF;
    IF v_turma_atual = p_nova_turma_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A criança já está nesta turma.';
    END IF;

    SELECT id INTO v_turma_atual FROM turmas WHERE id = p_nova_turma_id FOR UPDATE;

    -- trg_matriculas_bu_valida confere vagas e faixa etária da nova turma
    UPDATE matriculas SET turma_id = p_nova_turma_id WHERE id = p_matricula_id;

    COMMIT;
    SET p_mensagem = 'Transferência realizada com sucesso.';
END$$

-- P4. Abre a chamada do dia: lança presença para todas as matrículas
--     ativas da turma que ainda não têm registro na data.
CREATE PROCEDURE sp_registrar_chamada(
    IN  p_turma_id   INT,
    IN  p_data_aula  DATE,
    IN  p_usuario_id INT,
    OUT p_inseridos  INT
)
MODIFIES SQL DATA
BEGIN
    INSERT INTO frequencias (matricula_id, data_aula, presente, registrado_por)
    SELECT m.id, p_data_aula, 1, p_usuario_id
      FROM matriculas m
     WHERE m.turma_id = p_turma_id
       AND m.status = 'Ativa'
       AND NOT EXISTS (SELECT 1 FROM frequencias f
                        WHERE f.matricula_id = m.id AND f.data_aula = p_data_aula);
    SET p_inseridos = ROW_COUNT();
END$$

-- P5. Registra entrada/saída de insumo (o saldo é atualizado pelo trigger)
CREATE PROCEDURE sp_movimentar_estoque(
    IN p_produto_id    INT,
    IN p_tipo          VARCHAR(10),
    IN p_quantidade    INT,
    IN p_fornecedor_id INT,
    IN p_usuario_id    INT,
    IN p_motivo        VARCHAR(150)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_preco DECIMAL(10,2);

    IF p_tipo NOT IN ('Entrada', 'Saída') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tipo de movimentação inválido (use Entrada ou Saída).';
    END IF;

    -- o preço é lido antes: o INSERT não pode referenciar produtos, que
    -- será alterada pelo trigger trg_mov_ai_atualiza_saldo (erro 1442)
    SELECT preco INTO v_preco FROM produtos WHERE id = p_produto_id;

    INSERT INTO movimentacoes_estoque
        (produto_id, fornecedor_id, usuario_id, tipo, quantidade, valor_unitario, motivo)
    VALUES
        (p_produto_id, p_fornecedor_id, p_usuario_id, p_tipo, p_quantidade, v_preco, p_motivo);
END$$

-- P6. Dá baixa no estoque de todos os insumos de uma refeição do cardápio.
--     Tudo ou nada: se faltar qualquer insumo, nenhuma saída é gravada.
CREATE PROCEDURE sp_baixa_insumos_cardapio(
    IN  p_cardapio_id INT,
    IN  p_usuario_id  INT,
    OUT p_mensagem    VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_ja_baixado TINYINT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_mensagem = MESSAGE_TEXT;
        ROLLBACK;
        SET p_mensagem = CONCAT('Baixa cancelada (ROLLBACK): ', p_mensagem);
    END;

    START TRANSACTION;

    SELECT baixa_estoque INTO v_ja_baixado FROM cardapios WHERE id = p_cardapio_id FOR UPDATE;
    IF v_ja_baixado IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cardápio inexistente.';
    ELSEIF v_ja_baixado = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Os insumos desta refeição já foram baixados.';
    END IF;

    -- o SELECT lê apenas cardapio_insumos/cardapios, pois o trigger
    -- trg_mov_ai_atualiza_saldo precisa alterar a tabela produtos
    INSERT INTO movimentacoes_estoque (produto_id, usuario_id, tipo, quantidade, motivo)
    SELECT ci.produto_id, p_usuario_id, 'Saída', ci.quantidade_utilizada,
           CONCAT('Cardápio #', c.id, ' - ', c.tipo_refeicao, ' ', DATE_FORMAT(c.data_refeicao, '%d/%m/%Y'))
      FROM cardapio_insumos ci
     INNER JOIN cardapios c ON c.id = ci.cardapio_id
     WHERE ci.cardapio_id = p_cardapio_id;

    UPDATE cardapios SET baixa_estoque = 1 WHERE id = p_cardapio_id;

    COMMIT;
    SET p_mensagem = 'Baixa de insumos concluída.';
END$$

-- P7. Relatório de frequência por turma num período
CREATE PROCEDURE sp_relatorio_frequencia_turma(
    IN p_turma_id INT,
    IN p_inicio   DATE,
    IN p_fim      DATE
)
READS SQL DATA
BEGIN
    SELECT t.nome AS turma,
           c.nome AS crianca,
           SUM(f.presente)              AS presencas,
           SUM(1 - f.presente)          AS faltas,
           fn_percentual_frequencia(m.id, p_inicio, p_fim) AS percentual,
           IF(fn_percentual_frequencia(m.id, p_inicio, p_fim) < 75, 'ATENÇÃO', 'OK') AS situacao
      FROM matriculas m
     INNER JOIN criancas c    ON c.id = m.crianca_id
     INNER JOIN turmas t      ON t.id = m.turma_id
     INNER JOIN frequencias f ON f.matricula_id = m.id
     WHERE m.turma_id = p_turma_id
       AND f.data_aula BETWEEN p_inicio AND p_fim
     GROUP BY t.nome, c.nome, m.id
     ORDER BY percentual;
END$$

-- P8. Lista de compras: insumos abaixo do mínimo com sugestão de reposição
CREATE PROCEDURE sp_alerta_estoque_baixo()
READS SQL DATA
BEGIN
    SELECT p.nome AS produto,
           p.categoria,
           p.quantidade,
           p.estoque_minimo,
           fn_situacao_estoque(p.quantidade, p.estoque_minimo) AS situacao,
           (p.estoque_minimo * 2) - p.quantidade AS sugestao_compra,
           f.nome AS fornecedor,
           f.telefone
      FROM produtos p
     INNER JOIN fornecedores f ON f.id = p.fornecedor_id
     WHERE p.quantidade < p.estoque_minimo
     ORDER BY p.quantidade;
END$$

DELIMITER ;
