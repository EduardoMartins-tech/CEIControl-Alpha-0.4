/* ============================================================
   CEICONTROL - 06. UPDATE (Requisito 4) e DELETE (Requisito 5)
   Todos com WHERE. Os DELETEs seguem a ordem filho -> pai para
   respeitar a integridade referencial.
   ============================================================ */

USE ceicontrol;

/* ============================================================
   UPDATE (9 comandos com condições variadas)
   ============================================================ */

-- U1. Igualdade + IS NULL: turma da manhã sem educador recebe a Renata
UPDATE turmas
   SET educador_id = (SELECT id FROM usuarios WHERE email = 'renata.alves@cei.com')
 WHERE educador_id IS NULL
   AND periodo = 'Manhã';

-- U2. LIKE: Maternal II da tarde recebe a Carla
UPDATE turmas
   SET educador_id = (SELECT id FROM usuarios WHERE email = 'carla.mendes@cei.com')
 WHERE educador_id IS NULL
   AND nome LIKE 'Maternal II%';

-- U3. IN + subquery: reajuste de 5% nos alimentos de dois fornecedores
UPDATE produtos
   SET preco = ROUND(preco * 1.05, 2)
 WHERE categoria = 'Alimento'
   AND fornecedor_id IN (SELECT id FROM fornecedores
                          WHERE nome LIKE 'Cerealista%' OR nome LIKE 'Laticínios%');

-- U4. Subquery escalar: matrícula da Luísa trancada (gera auditoria via trigger)
UPDATE matriculas
   SET status = 'Trancada'
 WHERE crianca_id = (SELECT id FROM criancas WHERE cpf = '786.666.176-67')
   AND ano_letivo = 2026;

-- U5. Matrícula do Pedro cancelada (mudança de cidade)
UPDATE matriculas
   SET status = 'Cancelada'
 WHERE crianca_id = (SELECT id FROM criancas WHERE cpf = '031.372.159-94')
   AND status = 'Ativa';

-- U6. Data exata + subquery com JOIN: atestado do Arthur na sexta 18/09
UPDATE frequencias
   SET presente = 0,
       justificativa = 'Atestado médico - consulta'
 WHERE data_aula = '2026-09-18'
   AND matricula_id = (SELECT m.id
                         FROM matriculas m
                        INNER JOIN criancas c ON c.id = m.crianca_id
                        WHERE c.cpf = '996.030.824-30' AND m.ano_letivo = 2026);

-- U7. UPDATE com JOIN + BETWEEN: faltas sem justificativa das turmas
--     integrais na 2ª quinzena viram "responsável notificado"
UPDATE frequencias f
 INNER JOIN matriculas m ON m.id = f.matricula_id
 INNER JOIN turmas t     ON t.id = m.turma_id
   SET f.justificativa = 'Falta não justificada - responsável notificado'
 WHERE f.presente = 0
   AND f.justificativa = 'Falta não justificada'
   AND t.periodo = 'Integral'
   AND f.data_aula BETWEEN '2026-09-16' AND '2026-09-30';

-- U8. NOT IN: crianças sem matrícula ativa ficam inativas no cadastro
UPDATE criancas
   SET ativo = 0
 WHERE id NOT IN (SELECT crianca_id FROM matriculas WHERE status = 'Ativa');

-- U9. BETWEEN de datas + LIKE: reunião de pais de outubro muda de local/horário
UPDATE agenda
   SET local = 'Auditório da EMEF vizinha',
       hora_evento = '19:00:00'
 WHERE titulo LIKE 'Reunião de Pais%'
   AND data_evento BETWEEN '2026-10-01' AND '2026-10-31';

/* ============================================================
   DELETE (9 comandos respeitando a integridade referencial)
   ============================================================ */

-- D1. Tabela associativa (sem dependentes): remove vínculos "Outro"
--     não autorizados a buscar a criança
DELETE FROM crianca_responsavel
 WHERE autorizado_buscar = 0
   AND parentesco = 'Outro';

-- D2. Política de retenção do chat: mensagens anteriores a 09/09/2026
DELETE FROM mensagens
 WHERE data_envio < '2026-09-09 00:00:00';

-- D3 a D6. Exclusão do cadastro do Pedro (matrícula cancelada).
-- matriculas e medicamentos_dispensas referenciam criancas com
-- ON DELETE RESTRICT, então a ordem precisa ser filho -> pai.
-- (Tentar "DELETE FROM criancas" primeiro gera o erro 1451.)
SET @crianca_excluir = (SELECT id FROM criancas WHERE cpf = '031.372.159-94');

-- D3. Netos: frequências das matrículas canceladas
DELETE FROM frequencias
 WHERE matricula_id IN (SELECT id FROM matriculas
                         WHERE crianca_id = @crianca_excluir AND status = 'Cancelada');

-- D4. Filhos: histórico de medicamentos
DELETE FROM medicamentos_dispensas
 WHERE crianca_id = @crianca_excluir;

-- D5. Filhos: a matrícula cancelada
DELETE FROM matriculas
 WHERE crianca_id = @crianca_excluir
   AND status = 'Cancelada';

-- D6. Pai: a criança (crianca_responsavel sai por ON DELETE CASCADE;
--     trg_criancas_ad_auditoria registra a exclusão)
DELETE FROM criancas
 WHERE id = @crianca_excluir
   AND NOT EXISTS (SELECT 1 FROM matriculas WHERE crianca_id = @crianca_excluir);

-- D7. Serviço avulso de baixo valor já executado
DELETE FROM servicos
 WHERE preco < 100.00
   AND data_cadastro < '2026-05-01';

-- D8. Usuário sem vínculos (estágio encerrado). Os FKs para usuarios
--     usam SET NULL/CASCADE; trg_usuarios_bd_protege_admin impede
--     que o último administrador seja apagado.
DELETE FROM usuarios
 WHERE email = 'lucas.estagio@cei.com'
   AND perfil = 'usuario';

-- D9. Retenção da auditoria (registros com mais de 5 anos)
DELETE FROM auditoria
 WHERE data_hora < DATE_SUB(NOW(), INTERVAL 5 YEAR);

-- Exemplo do que a integridade referencial BLOQUEIA (não executar):
-- DELETE FROM turmas WHERE nome = 'Infantil I';
-- ERROR 1451: Cannot delete or update a parent row: a foreign key constraint fails
--             (matriculas.fk_matriculas_turma)
