/* ============================================================
   CEICONTROL - 09. TRANSAÇÕES ACID (Requisito 15)
   T1-T5: blocos explícitos START TRANSACTION / COMMIT / ROLLBACK
   T6-T8: procedures transacionais (ROLLBACK automático em erro)
   ============================================================ */

USE ceicontrol;

SET @admin   = (SELECT id FROM usuarios WHERE email = 'admin@cei.com');
SET @gestor  = (SELECT id FROM usuarios WHERE email = 'gestor@cei.com');
SET @mariana = (SELECT id FROM usuarios WHERE email = 'usuario@cei.com');
SET @beatriz = (SELECT id FROM usuarios WHERE email = 'beatriz.nunes@cei.com');

-- ------------------------------------------------------------
-- T1. COMMIT - Recebimento de uma nota fiscal com vários itens.
-- Ou entram todos os itens da NF, ou nenhum (atomicidade).
-- ------------------------------------------------------------
START TRANSACTION;
    SET @forn = (SELECT id FROM fornecedores WHERE cnpj = '44.555.666/0001-14');
    CALL sp_movimentar_estoque((SELECT id FROM produtos WHERE nome = 'Sabonete líquido infantil (L)'), 'Entrada', 10, @forn, @gestor, 'NF 7802 - reposição');
    CALL sp_movimentar_estoque((SELECT id FROM produtos WHERE nome = 'Fralda descartável M (pct)'),     'Entrada', 15, @forn, @gestor, 'NF 7802 - reposição');
    CALL sp_movimentar_estoque((SELECT id FROM produtos WHERE nome = 'Lenço umedecido (pct)'),          'Entrada', 20, @forn, @gestor, 'NF 7802 - reposição');
COMMIT;

-- ------------------------------------------------------------
-- T2. ROLLBACK - Reajuste digitado errado (x10 em vez de +10%).
-- O ROLLBACK desfaz tudo; os preços voltam ao valor original.
-- ------------------------------------------------------------
SELECT nome, preco FROM produtos WHERE categoria = 'Alimento' ORDER BY nome;
START TRANSACTION;
    UPDATE produtos SET preco = preco * 10 WHERE categoria = 'Alimento';
    SELECT nome, preco AS preco_errado FROM produtos WHERE categoria = 'Alimento' ORDER BY nome;
ROLLBACK;
SELECT nome, preco AS preco_apos_rollback FROM produtos WHERE categoria = 'Alimento' ORDER BY nome;

-- ------------------------------------------------------------
-- T3. SAVEPOINT + ROLLBACK parcial + COMMIT - Chamada do Maternal I-A
-- A educadora marca a falta na criança errada, desfaz só esse passo
-- e corrige antes de confirmar.
-- ------------------------------------------------------------
SET @turma = (SELECT id FROM turmas WHERE nome = 'Maternal I-A' AND ano_letivo = 2026);
START TRANSACTION;
    CALL sp_registrar_chamada(@turma, '2026-10-01', @mariana, @inseridos);
    SAVEPOINT chamada_aberta;

    UPDATE frequencias f
     INNER JOIN matriculas m ON m.id = f.matricula_id
     INNER JOIN criancas c   ON c.id = m.crianca_id
       SET f.presente = 0, f.justificativa = 'Febre'
     WHERE f.data_aula = '2026-10-01' AND c.cpf = '937.865.797-41';   -- criança errada

    ROLLBACK TO SAVEPOINT chamada_aberta;

    UPDATE frequencias f
     INNER JOIN matriculas m ON m.id = f.matricula_id
     INNER JOIN criancas c   ON c.id = m.crianca_id
       SET f.presente = 0, f.justificativa = 'Febre'
     WHERE f.data_aula = '2026-10-01' AND c.cpf = '757.491.186-06';   -- criança certa
COMMIT;
SELECT crianca, presente, justificativa
  FROM vw_frequencia_detalhada
 WHERE data_aula = '2026-10-01' AND turma = 'Maternal I-A'
 ORDER BY crianca;

-- ------------------------------------------------------------
-- T4. COMMIT - Dose de medicamento + aviso ao responsável no chat.
-- As duas gravações formam uma unidade: não existe dose sem aviso.
-- ------------------------------------------------------------
START TRANSACTION;
    INSERT INTO medicamentos_dispensas (crianca_id, medicamento, dosagem, data_hora, administrado_por, receita_medica, observacao)
    VALUES ((SELECT id FROM criancas WHERE cpf = '526.018.159-06'),
            'Paracetamol gotas 200mg/ml', '8 gotas', '2026-10-01 10:00:00', @beatriz, 1, 'Febre 38ºC');

    INSERT INTO mensagens (remetente_id, destinatario_id, mensagem, data_envio)
    VALUES (@beatriz, (SELECT id FROM usuarios WHERE email = 'cliente@cei.com'),
            'A Alice teve febre (38ºC) e recebeu 8 gotas de paracetamol às 10h, conforme receita.',
            '2026-10-01 10:05:00');
COMMIT;

-- ------------------------------------------------------------
-- T5. ROLLBACK - Simulação de encerramento do ano letivo.
-- A direção confere o impacto antes de aplicar e desiste.
-- ------------------------------------------------------------
START TRANSACTION;
    UPDATE matriculas SET status = 'Concluída' WHERE ano_letivo = 2026 AND status = 'Ativa';
    SELECT status, COUNT(*) AS total FROM matriculas WHERE ano_letivo = 2026 GROUP BY status ORDER BY status;
ROLLBACK;
SELECT status, COUNT(*) AS total_apos_rollback FROM matriculas WHERE ano_letivo = 2026 GROUP BY status ORDER BY status;

-- ------------------------------------------------------------
-- T6. Procedure transacional: matrícula com regra violada -> ROLLBACK
--     (Berçário I-B tem capacidade 2 e já está lotado)
-- ------------------------------------------------------------
CALL sp_matricular_crianca((SELECT id FROM criancas WHERE cpf = '013.962.459-79'),
                           (SELECT id FROM turmas WHERE nome = 'Berçário I-B'),
                           '2026-10-01', @matricula, @msg);
SELECT @matricula AS matricula, @msg AS resultado;

--     ... e na turma com vaga -> COMMIT
CALL sp_matricular_crianca((SELECT id FROM criancas WHERE cpf = '013.962.459-79'),
                           (SELECT id FROM turmas WHERE nome = 'Berçário I-A'),
                           '2026-10-01', @matricula, @msg);
SELECT @matricula AS matricula, @msg AS resultado;

CALL sp_matricular_crianca((SELECT id FROM criancas WHERE cpf = '010.928.159-45'),
                           (SELECT id FROM turmas WHERE nome = 'Maternal I-B'),
                           '2026-10-01', @matricula, @msg);
SELECT @matricula AS matricula, @msg AS resultado;

-- ------------------------------------------------------------
-- T7. Procedure transacional: transferência de turma
--     inválida (faixa etária) -> ROLLBACK; válida -> COMMIT
-- ------------------------------------------------------------
SET @mat_arthur = (SELECT m.id FROM matriculas m INNER JOIN criancas c ON c.id = m.crianca_id
                    WHERE c.cpf = '996.030.824-30' AND m.ano_letivo = 2026);
CALL sp_transferir_turma(@mat_arthur, (SELECT id FROM turmas WHERE nome = 'Infantil II'), @msg);
SELECT @msg AS resultado;

SET @mat_laura = (SELECT m.id FROM matriculas m INNER JOIN criancas c ON c.id = m.crianca_id
                   WHERE c.cpf = '628.194.821-12' AND m.ano_letivo = 2026);
CALL sp_transferir_turma(@mat_laura, (SELECT id FROM turmas WHERE nome = 'Berçário II-A'), @msg);
SELECT @msg AS resultado;

-- ------------------------------------------------------------
-- T8. Procedure transacional: baixa de insumos do cardápio
--     1ª chamada -> COMMIT; 2ª chamada (duplicada) -> ROLLBACK
-- ------------------------------------------------------------
SET @cardapio = (SELECT id FROM cardapios WHERE data_refeicao = '2026-10-02' AND tipo_refeicao = 'Almoço');
CALL sp_baixa_insumos_cardapio(@cardapio, @admin, @msg);
SELECT @msg AS resultado;
CALL sp_baixa_insumos_cardapio(@cardapio, @admin, @msg);
SELECT @msg AS resultado;
