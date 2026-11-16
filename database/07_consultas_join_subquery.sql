/* ============================================================
   CEICONTROL - 07. CONSULTAS
   Parte A: INNER JOIN (Requisito 6)
   Parte B: SUBQUERIES (Requisito 9)
   ============================================================ */

USE ceicontrol;

/* ============================================================
   PARTE A - CONSULTAS COM INNER JOIN
   ============================================================ */

-- J1. Crianças matriculadas com turma, período, sala e educador(a)
SELECT c.nome            AS crianca,
       t.nome            AS turma,
       t.periodo,
       t.sala,
       u.nome            AS educador,
       m.status
  FROM matriculas m
 INNER JOIN criancas c ON c.id = m.crianca_id
 INNER JOIN turmas t   ON t.id = m.turma_id
 INNER JOIN usuarios u ON u.id = t.educador_id
 WHERE m.ano_letivo = 2026
 ORDER BY t.nome, c.nome;

-- J2. Quem está autorizado a buscar cada criança (portaria)
SELECT c.nome      AS crianca,
       r.nome      AS responsavel,
       cr.parentesco,
       r.telefone
  FROM criancas c
 INNER JOIN crianca_responsavel cr ON cr.crianca_id = c.id
 INNER JOIN responsaveis r         ON r.id = cr.responsavel_id
 WHERE cr.autorizado_buscar = 1
 ORDER BY c.nome, cr.parentesco;

-- J3. Faltas por turma em setembro/2026
SELECT t.nome                AS turma,
       COUNT(*)              AS registros,
       SUM(f.presente = 0)   AS faltas
  FROM frequencias f
 INNER JOIN matriculas m ON m.id = f.matricula_id
 INNER JOIN turmas t     ON t.id = m.turma_id
 WHERE f.data_aula BETWEEN '2026-09-01' AND '2026-09-30'
 GROUP BY t.nome
 ORDER BY faltas DESC, t.nome;

-- J4. Histórico de medicamentos com criança, turma e quem administrou
SELECT md.data_hora,
       c.nome          AS crianca,
       t.nome          AS turma,
       md.medicamento,
       md.dosagem,
       u.nome          AS administrado_por,
       IF(md.receita_medica = 1, 'Sim', 'Não') AS com_receita
  FROM medicamentos_dispensas md
 INNER JOIN criancas c   ON c.id = md.crianca_id
 INNER JOIN matriculas m ON m.crianca_id = c.id AND m.ano_letivo = 2026
 INNER JOIN turmas t     ON t.id = m.turma_id
 INNER JOIN usuarios u   ON u.id = md.administrado_por
 ORDER BY md.data_hora DESC;

-- J5. Entradas de estoque com produto, fornecedor e quem recebeu
SELECT me.data_movimentacao,
       p.nome         AS produto,
       f.nome         AS fornecedor,
       me.quantidade,
       me.valor_unitario,
       me.quantidade * me.valor_unitario AS valor_total,
       u.nome         AS recebido_por
  FROM movimentacoes_estoque me
 INNER JOIN produtos p     ON p.id = me.produto_id
 INNER JOIN fornecedores f ON f.id = me.fornecedor_id
 INNER JOIN usuarios u     ON u.id = me.usuario_id
 WHERE me.tipo = 'Entrada'
 ORDER BY me.data_movimentacao, p.nome;

-- J6. Lista de insumos do cardápio da semana x estoque atual
SELECT c.data_refeicao,
       c.tipo_refeicao,
       p.nome                  AS insumo,
       ci.quantidade_utilizada,
       p.quantidade            AS estoque_atual,
       f.nome                  AS fornecedor
  FROM cardapios c
 INNER JOIN cardapio_insumos ci ON ci.cardapio_id = c.id
 INNER JOIN produtos p          ON p.id = ci.produto_id
 INNER JOIN fornecedores f      ON f.id = p.fornecedor_id
 WHERE c.data_refeicao BETWEEN '2026-09-28' AND '2026-10-02'
 ORDER BY c.data_refeicao, c.tipo_refeicao, p.nome;

-- J7. Crianças com alergia/restrição alimentar por turma (aviso à cozinha)
SELECT t.nome AS turma, t.periodo, c.nome AS crianca, c.alergias, c.restricao_alimentar
  FROM criancas c
 INNER JOIN matriculas m ON m.crianca_id = c.id AND m.status = 'Ativa'
 INNER JOIN turmas t     ON t.id = m.turma_id
 WHERE c.alergias IS NOT NULL OR c.restricao_alimentar IS NOT NULL
 ORDER BY t.nome;

/* ============================================================
   PARTE B - SUBQUERIES
   ============================================================ */

-- S1. Subquery no WHERE com IN: crianças cujo responsável tem login no sistema
SELECT c.nome
  FROM criancas c
 WHERE c.id IN (SELECT cr.crianca_id
                  FROM crianca_responsavel cr
                 WHERE cr.responsavel_id IN (SELECT id FROM responsaveis WHERE usuario_id IS NOT NULL))
 ORDER BY c.nome;

-- S2. Subquery correlacionada no WHERE: insumos mais caros que a média da sua categoria
SELECT p.nome, p.categoria, p.preco
  FROM produtos p
 WHERE p.preco > (SELECT AVG(p2.preco) FROM produtos p2 WHERE p2.categoria = p.categoria)
 ORDER BY p.categoria, p.preco DESC;

-- S3. Subquery no FROM (tabela derivada): turmas com presença abaixo da média geral
SELECT x.turma, x.taxa_presenca
  FROM (SELECT t.nome AS turma,
               ROUND(AVG(f.presente) * 100, 2) AS taxa_presenca
          FROM frequencias f
         INNER JOIN matriculas m ON m.id = f.matricula_id
         INNER JOIN turmas t     ON t.id = m.turma_id
         GROUP BY t.nome) AS x
 WHERE x.taxa_presenca < (SELECT AVG(presente) * 100 FROM frequencias)
 ORDER BY x.taxa_presenca;

-- S4. Subqueries escalares no SELECT: ocupação de cada turma
SELECT t.nome,
       t.capacidade,
       (SELECT COUNT(*) FROM matriculas m
         WHERE m.turma_id = t.id AND m.status = 'Ativa')   AS matriculados,
       fn_vagas_disponiveis(t.id)                          AS vagas,
       (SELECT u.nome FROM usuarios u WHERE u.id = t.educador_id) AS educador
  FROM turmas t
 ORDER BY t.idade_min_meses, t.nome;

-- S5. NOT EXISTS: fila de espera (crianças cadastradas sem matrícula ativa)
SELECT c.nome, c.data_nascimento, fn_idade_meses(c.data_nascimento, CURDATE()) AS idade_meses
  FROM criancas c
 WHERE NOT EXISTS (SELECT 1 FROM matriculas m
                    WHERE m.crianca_id = c.id AND m.status = 'Ativa');

-- S6. EXISTS: fornecedores que entregaram mercadoria em setembro/2026
SELECT f.nome, f.telefone
  FROM fornecedores f
 WHERE EXISTS (SELECT 1 FROM movimentacoes_estoque me
                WHERE me.fornecedor_id = f.id
                  AND me.tipo = 'Entrada'
                  AND me.data_movimentacao BETWEEN '2026-09-01' AND '2026-09-30 23:59:59');

-- S7. Subquery com >= ALL: criança(s) com mais faltas no mês
SELECT c.nome, COUNT(*) AS faltas
  FROM frequencias f
 INNER JOIN matriculas m ON m.id = f.matricula_id
 INNER JOIN criancas c   ON c.id = m.crianca_id
 WHERE f.presente = 0
 GROUP BY c.id, c.nome
HAVING COUNT(*) >= ALL (SELECT COUNT(*) FROM frequencias f2
                         WHERE f2.presente = 0
                         GROUP BY f2.matricula_id);
