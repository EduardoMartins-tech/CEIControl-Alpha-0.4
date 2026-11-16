/* ============================================================
   CEICONTROL - 08. VIEWS (Requisito 7) e CONSULTAS NAS VIEWS
   (Requisito 8: COUNT, SUM, AVG, MIN, MAX, IN, BETWEEN)
   Todas as views são baseadas em INNER JOIN.
   ============================================================ */

USE ceicontrol;

-- V1. Crianças x matrícula x turma
CREATE OR REPLACE VIEW vw_criancas_turmas AS
SELECT m.id              AS matricula_id,
       c.id              AS crianca_id,
       c.nome            AS crianca,
       c.data_nascimento,
       fn_idade_meses(c.data_nascimento, CURDATE()) AS idade_meses,
       c.sexo,
       c.alergias,
       t.id              AS turma_id,
       t.nome            AS turma,
       t.periodo,
       t.sala,
       m.ano_letivo,
       m.data_matricula,
       m.status
  FROM matriculas m
 INNER JOIN criancas c ON c.id = m.crianca_id
 INNER JOIN turmas t   ON t.id = m.turma_id;

-- V2. Frequência diária detalhada
CREATE OR REPLACE VIEW vw_frequencia_detalhada AS
SELECT f.id         AS frequencia_id,
       f.data_aula,
       f.presente,
       f.justificativa,
       c.nome       AS crianca,
       t.nome       AS turma,
       t.periodo,
       m.id         AS matricula_id
  FROM frequencias f
 INNER JOIN matriculas m ON m.id = f.matricula_id
 INNER JOIN criancas c   ON c.id = m.crianca_id
 INNER JOIN turmas t     ON t.id = m.turma_id;

-- V3. Posição de estoque com fornecedor
CREATE OR REPLACE VIEW vw_estoque_fornecedor AS
SELECT p.id                                      AS produto_id,
       p.nome                                    AS produto,
       p.categoria,
       p.quantidade,
       p.estoque_minimo,
       p.preco,
       p.quantidade * p.preco                    AS valor_em_estoque,
       fn_situacao_estoque(p.quantidade, p.estoque_minimo) AS situacao,
       f.nome                                    AS fornecedor,
       f.telefone                                AS telefone_fornecedor
  FROM produtos p
 INNER JOIN fornecedores f ON f.id = p.fornecedor_id;

-- V4. Extrato das movimentações de estoque
CREATE OR REPLACE VIEW vw_movimentacoes AS
SELECT me.id                 AS movimentacao_id,
       me.data_movimentacao,
       me.tipo,
       p.nome                AS produto,
       p.categoria,
       me.quantidade,
       COALESCE(me.valor_unitario, p.preco)                 AS valor_unitario,
       me.quantidade * COALESCE(me.valor_unitario, p.preco) AS valor_total,
       u.nome                AS responsavel,
       me.motivo
  FROM movimentacoes_estoque me
 INNER JOIN produtos p ON p.id = me.produto_id
 INNER JOIN usuarios u ON u.id = me.usuario_id;

-- V5. Medicamentos administrados
CREATE OR REPLACE VIEW vw_medicamentos_administrados AS
SELECT md.id           AS dispensa_id,
       md.data_hora,
       c.nome          AS crianca,
       md.medicamento,
       md.dosagem,
       md.receita_medica,
       u.nome          AS funcionario
  FROM medicamentos_dispensas md
 INNER JOIN criancas c ON c.id = md.crianca_id
 INNER JOIN usuarios u ON u.id = md.administrado_por;

-- V6. Custo dos insumos de cada refeição
CREATE OR REPLACE VIEW vw_cardapio_custos AS
SELECT c.id                              AS cardapio_id,
       c.data_refeicao,
       c.tipo_refeicao,
       c.descricao,
       p.nome                            AS insumo,
       p.categoria,
       ci.quantidade_utilizada,
       p.preco,
       ci.quantidade_utilizada * p.preco AS custo
  FROM cardapios c
 INNER JOIN cardapio_insumos ci ON ci.cardapio_id = c.id
 INNER JOIN produtos p          ON p.id = ci.produto_id;

-- V7. Ocupação das turmas (somente matrículas ativas)
CREATE OR REPLACE VIEW vw_ocupacao_turmas AS
SELECT t.id                 AS turma_id,
       t.nome               AS turma,
       t.periodo,
       u.nome               AS educador,
       t.capacidade,
       COUNT(m.id)          AS matriculados,
       ROUND(COUNT(m.id) * 100 / t.capacidade, 1) AS ocupacao_percentual
  FROM turmas t
 INNER JOIN usuarios u   ON u.id = t.educador_id
 INNER JOIN matriculas m ON m.turma_id = t.id AND m.status = 'Ativa'
 GROUP BY t.id, t.nome, t.periodo, u.nome, t.capacidade;

-- V8. Contatos dos responsáveis por criança
CREATE OR REPLACE VIEW vw_contatos_responsaveis AS
SELECT c.id        AS crianca_id,
       c.nome      AS crianca,
       r.nome      AS responsavel,
       cr.parentesco,
       cr.autorizado_buscar,
       r.telefone,
       r.email
  FROM criancas c
 INNER JOIN crianca_responsavel cr ON cr.crianca_id = c.id
 INNER JOIN responsaveis r         ON r.id = cr.responsavel_id;

/* ============================================================
   CONSULTAS A PARTIR DAS VIEWS
   ============================================================ */

-- C1. [COUNT + IN] Quantidade de matrículas por turma e status
SELECT turma, status, COUNT(*) AS total
  FROM vw_criancas_turmas
 WHERE status IN ('Ativa', 'Trancada')
 GROUP BY turma, status
 ORDER BY turma;

-- C2. [AVG + MIN + MAX] Idade média, mínima e máxima (em meses) por turma
SELECT turma,
       ROUND(AVG(idade_meses), 1) AS idade_media_meses,
       MIN(idade_meses)           AS idade_minima,
       MAX(idade_meses)           AS idade_maxima
  FROM vw_criancas_turmas
 WHERE status = 'Ativa'
 GROUP BY turma
 ORDER BY idade_media_meses;

-- C3. [SUM + COUNT + AVG + BETWEEN + IN] Presença por turma na 1ª quinzena de setembro
SELECT turma,
       COUNT(*)                          AS registros,
       SUM(presente)                     AS presencas,
       ROUND(AVG(presente) * 100, 2)     AS taxa_presenca
  FROM vw_frequencia_detalhada
 WHERE data_aula BETWEEN '2026-09-01' AND '2026-09-15'
   AND periodo IN ('Integral', 'Manhã')
 GROUP BY turma
 ORDER BY taxa_presenca, turma;

-- C4. [SUM + MIN + MAX + IN] Valor imobilizado em estoque por categoria
SELECT categoria,
       COUNT(*)                AS itens,
       SUM(valor_em_estoque)   AS valor_total,
       MIN(preco)              AS menor_preco,
       MAX(preco)              AS maior_preco
  FROM vw_estoque_fornecedor
 WHERE categoria IN ('Alimento', 'Higiene', 'Pedagógico')
 GROUP BY categoria
 ORDER BY categoria;

-- C5. [SUM + BETWEEN] Gasto com compras por produto em setembro/2026
SELECT produto,
       SUM(quantidade)  AS unidades_compradas,
       SUM(valor_total) AS gasto
  FROM vw_movimentacoes
 WHERE tipo = 'Entrada'
   AND data_movimentacao BETWEEN '2026-09-01 00:00:00' AND '2026-09-30 23:59:59'
 GROUP BY produto
 ORDER BY gasto DESC;

-- C6. [COUNT + MIN + MAX + BETWEEN] Doses por medicamento no mês
SELECT medicamento,
       COUNT(*)       AS doses,
       MIN(data_hora) AS primeira_dose,
       MAX(data_hora) AS ultima_dose
  FROM vw_medicamentos_administrados
 WHERE data_hora BETWEEN '2026-09-01' AND '2026-09-30 23:59:59'
 GROUP BY medicamento
 ORDER BY doses DESC, medicamento;

-- C7. [SUM + AVG + BETWEEN] Custo diário da alimentação na semana
SELECT data_refeicao,
       SUM(custo)           AS custo_dia,
       ROUND(AVG(custo), 2) AS custo_medio_por_insumo
  FROM vw_cardapio_custos
 WHERE data_refeicao BETWEEN '2026-09-28' AND '2026-10-02'
 GROUP BY data_refeicao
 ORDER BY data_refeicao;

-- C8. [MAX + AVG + SUM + IN] Turmas mais ocupadas por período
SELECT periodo,
       MAX(ocupacao_percentual)           AS maior_ocupacao,
       ROUND(AVG(ocupacao_percentual), 1) AS ocupacao_media,
       SUM(matriculados)                  AS criancas
  FROM vw_ocupacao_turmas
 WHERE periodo IN ('Integral', 'Manhã', 'Tarde')
 GROUP BY periodo
 ORDER BY periodo;

-- C9. [COUNT + IN] Crianças com menos de 2 responsáveis autorizados (pendência de cadastro)
SELECT crianca, COUNT(*) AS autorizados
  FROM vw_contatos_responsaveis
 WHERE autorizado_buscar IN (1)
 GROUP BY crianca_id, crianca
HAVING COUNT(*) < 2
 ORDER BY crianca;
