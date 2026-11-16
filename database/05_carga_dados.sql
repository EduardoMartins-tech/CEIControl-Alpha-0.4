/* ============================================================
   CEICONTROL - 05. CARGA DE DADOS (Requisito 3)
   - Garante no mínimo 10 registros em TODAS as tabelas
   - INSERT com SUBSELECT: blocos marcados com [INSERT+SUBSELECT]
   Os triggers e procedures (arquivos 02-04) já estão ativos,
   então toda a carga passa pelas regras de negócio.
   Senha de todos os usuários de demonstração: 123456
   ============================================================ */

USE ceicontrol;

-- Reaproveita o hash BCrypt de "123456" gravado pelo tabelas.sql
SET @hash_123456 = (SELECT senha FROM usuarios WHERE email = 'admin@cei.com');

-- ------------------------------------------------------------
-- USUÁRIOS (3 do tabelas.sql + 11 = 14)
-- ------------------------------------------------------------
INSERT INTO usuarios (nome, email, senha, perfil) VALUES
('Gustavo Henrique Gestor', 'gestor@cei.com',            @hash_123456, 'admin'),
('Patrícia Lima',           'patricia.lima@cei.com',     @hash_123456, 'usuario'),
('Juliana Rocha',           'juliana.rocha@cei.com',     @hash_123456, 'usuario'),
('Carla Mendes',            'carla.mendes@cei.com',      @hash_123456, 'usuario'),
('Renata Alves',            'renata.alves@cei.com',      @hash_123456, 'usuario'),
('Beatriz Nunes',           'beatriz.nunes@cei.com',     @hash_123456, 'usuario'),
('Lucas Estagiário',        'lucas.estagio@cei.com',     @hash_123456, 'usuario'),
('Roberto Oliveira Costa',  'roberto.costa@email.com',   @hash_123456, 'cliente'),
('Ana Paula Rodrigues',     'anapaula@email.com',        @hash_123456, 'cliente'),
('Marcos Almeida Souza',    'marcos.souza@email.com',    @hash_123456, 'cliente'),
('Luciana Pereira Gomes',   'luciana.gomes@email.com',   @hash_123456, 'cliente');

-- ------------------------------------------------------------
-- FORNECEDORES (2 + 8 = 10)
-- ------------------------------------------------------------
INSERT INTO fornecedores (nome, cnpj, email, telefone, data_cadastro) VALUES
('Hortifruti Vale Verde Ltda',     '11.222.333/0001-81', 'vendas@valeverde.com',       '(11) 4675-1020', '2026-01-12'),
('Laticínios Serra Azul',          '22.333.444/0001-92', 'pedidos@serraazul.com',      '(11) 4675-2030', '2026-01-12'),
('Cerealista Grão de Ouro',        '33.444.555/0001-03', 'comercial@graodeouro.com',   '(11) 4675-3040', '2026-01-15'),
('Higiene Kids Distribuidora',     '44.555.666/0001-14', 'contato@higienekids.com',    '(11) 4675-4050', '2026-01-20'),
('Papelaria Criativa ME',          '55.666.777/0001-25', 'loja@papelariacriativa.com', '(11) 4675-5060', '2026-01-22'),
('Limpa Bem Produtos de Limpeza',  '66.777.888/0001-36', 'vendas@limpabem.com',        '(11) 4675-6070', '2026-02-02'),
('Frigorífico Boa Carne',          '77.888.999/0001-47', 'pedidos@boacarne.com',       '(11) 4675-7080', '2026-02-02'),
('Padaria Pão Quente',             '88.999.000/0001-58', 'padaria@paoquente.com',      '(11) 4675-8090', '2026-02-05');

-- ------------------------------------------------------------
-- PRODUTOS / INSUMOS (2 + 12 = 14)
-- Os novos entram com saldo 0; o saldo vem das movimentações.
-- [INSERT+SUBSELECT] fornecedor localizado pelo CNPJ
-- ------------------------------------------------------------
UPDATE produtos
   SET categoria = 'Escritório', estoque_minimo = 10,
       fornecedor_id = (SELECT id FROM fornecedores WHERE cnpj = '12.345.678/0001-99')
 WHERE nome = 'Resma Papel A4';

UPDATE produtos
   SET categoria = 'Pedagógico', estoque_minimo = 20,
       fornecedor_id = (SELECT id FROM fornecedores WHERE cnpj = '55.666.777/0001-25')
 WHERE nome = 'Kit Estojo Colorido';

INSERT INTO produtos (nome, descricao, categoria, preco, quantidade, estoque_minimo, fornecedor_id, data_cadastro)
SELECT x.nome, x.descricao, x.categoria, x.preco, 0, x.minimo, f.id, '2026-02-10'
  FROM (
        SELECT 'Arroz tipo 1 (kg)' AS nome, 'Arroz branco agulhinha' AS descricao, 'Alimento' AS categoria, 5.50 AS preco, 20 AS minimo, '33.444.555/0001-03' AS cnpj
        UNION ALL SELECT 'Feijão carioca (kg)', 'Feijão carioca tipo 1', 'Alimento', 8.90, 15, '33.444.555/0001-03'
        UNION ALL SELECT 'Leite integral (L)', 'Leite UHT integral', 'Alimento', 4.79, 30, '22.333.444/0001-92'
        UNION ALL SELECT 'Banana prata (kg)', 'Fruta para lanche', 'Alimento', 6.20, 10, '11.222.333/0001-81'
        UNION ALL SELECT 'Peito de frango (kg)', 'Filé de peito congelado', 'Alimento', 18.90, 10, '77.888.999/0001-47'
        UNION ALL SELECT 'Pão de forma (pct)', 'Pão de forma integral 500g', 'Alimento', 7.50, 12, '88.999.000/0001-58'
        UNION ALL SELECT 'Fralda descartável M (pct)', 'Pacote com 40 unidades', 'Higiene', 52.00, 10, '44.555.666/0001-14'
        UNION ALL SELECT 'Lenço umedecido (pct)', 'Pacote com 100 unidades', 'Higiene', 9.90, 15, '44.555.666/0001-14'
        UNION ALL SELECT 'Sabonete líquido infantil (L)', 'Hipoalergênico', 'Higiene', 14.50, 5, '44.555.666/0001-14'
        UNION ALL SELECT 'Álcool 70% (L)', 'Higienização de superfícies', 'Limpeza', 8.00, 10, '66.777.888/0001-36'
        UNION ALL SELECT 'Massinha de modelar (cx)', 'Caixa com 12 cores atóxica', 'Pedagógico', 12.00, 10, '55.666.777/0001-25'
        UNION ALL SELECT 'Tinta guache (cx)', 'Caixa com 6 cores 15ml', 'Pedagógico', 11.50, 10, '55.666.777/0001-25'
       ) AS x
 INNER JOIN fornecedores f ON f.cnpj = x.cnpj;

-- ------------------------------------------------------------
-- SERVIÇOS (2 + 9 = 11)
-- ------------------------------------------------------------
INSERT INTO servicos (nome, descricao, preco, data_cadastro) VALUES
('Dedetização semestral',           'Controle de pragas em todas as áreas',        650.00, '2026-02-01'),
('Manutenção do parquinho',         'Troca de parafusos e pintura dos brinquedos', 380.00, '2026-03-04'),
('Limpeza da caixa d''água',        'Limpeza e desinfecção com laudo',             420.00, '2026-03-10'),
('Recarga de extintores',           'Recarga e teste hidrostático (6 unidades)',   300.00, '2026-04-02'),
('Conserto de torneiras',           'Troca de reparos nos banheiros infantis',      90.00, '2026-04-15'),
('Poda de árvores',                 'Poda preventiva no pátio',                    250.00, '2026-05-06'),
('Manutenção de computadores',      'Formatação e limpeza da secretaria',          160.00, '2026-06-01'),
('Instalação de telas de proteção', 'Telas nas janelas do berçário',               780.00, '2026-06-20'),
('Manutenção do portão eletrônico', 'Troca do motor e ajuste do sensor',           210.00, '2026-08-03');

-- ------------------------------------------------------------
-- AGENDA (2 + 8 = 10)  [INSERT+SUBSELECT] autor pelo e-mail
-- ------------------------------------------------------------
INSERT INTO agenda (titulo, descricao, data_evento, hora_evento, local, criado_por, publico_alvo, data_cadastro) VALUES
('Reunião de Pais - 2º Semestre', 'Apresentação do projeto pedagógico',       '2026-10-15', '18:30:00', 'Pátio Coberto',        (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),         'Pais',         '2026-09-20'),
('Semana da Criança',             'Brincadeiras e oficinas',                  '2026-10-13', '09:00:00', 'Pátio Principal',      (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'),        'Geral',        '2026-09-20'),
('Campanha de Vacinação',         'Atualização da caderneta',                 '2026-10-20', '09:00:00', 'Sala de Enfermagem',   (SELECT id FROM usuarios WHERE email = 'beatriz.nunes@cei.com'), 'Pais',         '2026-09-22'),
('Formação Pedagógica',           'BNCC na Educação Infantil',                '2026-10-23', '13:00:00', 'Sala dos Professores', (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'),        'Funcionários', '2026-09-22'),
('Mostra de Artes',               'Exposição dos trabalhos das turmas',       '2026-11-06', '15:00:00', 'Pátio Principal',      (SELECT id FROM usuarios WHERE email = 'usuario@cei.com'),       'Geral',        '2026-09-25'),
('Reunião do Conselho Escolar',   'Prestação de contas do semestre',          '2026-11-11', '17:00:00', 'Secretaria',           (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),         'Funcionários', '2026-09-25'),
('Entrega de Relatórios',         'Relatório individual de desenvolvimento', '2026-12-03', '18:00:00', 'Salas de Aula',        (SELECT id FROM usuarios WHERE email = 'usuario@cei.com'),       'Pais',         '2026-09-28'),
('Festa de Encerramento',         'Formatura do Infantil II',                 '2026-12-11', '10:00:00', 'Pátio Principal',      (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),         'Geral',        '2026-09-28');

-- ------------------------------------------------------------
-- MENSAGENS (0 + 12)  [INSERT+SUBSELECT] remetente/destinatário pelo e-mail
-- ------------------------------------------------------------
INSERT INTO mensagens (remetente_id, destinatario_id, mensagem, data_envio)
SELECT de.id, para.id, x.texto, x.enviada_em
  FROM (
        SELECT 'cliente@cei.com' AS de, 'usuario@cei.com' AS para, 'Bom dia! A Alice dormiu mal hoje, pode observar?' AS texto, '2026-09-08 07:40:00' AS enviada_em
        UNION ALL SELECT 'usuario@cei.com', 'cliente@cei.com', 'Bom dia, Fernanda! Pode deixar, aviso como foi o dia.', '2026-09-08 07:55:00'
        UNION ALL SELECT 'roberto.costa@email.com', 'admin@cei.com', 'Preciso de declaração de matrícula do Miguel.', '2026-09-09 10:12:00'
        UNION ALL SELECT 'admin@cei.com', 'roberto.costa@email.com', 'A declaração estará pronta amanhã na secretaria.', '2026-09-09 11:03:00'
        UNION ALL SELECT 'anapaula@email.com', 'beatriz.nunes@cei.com', 'A Helena está com receita de antitérmico, envio na agenda.', '2026-09-10 07:30:00'
        UNION ALL SELECT 'beatriz.nunes@cei.com', 'anapaula@email.com', 'Recebido. Só administramos com a receita anexada.', '2026-09-10 08:02:00'
        UNION ALL SELECT 'marcos.souza@email.com', 'patricia.lima@cei.com', 'O Arthur vai faltar sexta por consulta médica.', '2026-09-16 18:20:00'
        UNION ALL SELECT 'patricia.lima@cei.com', 'marcos.souza@email.com', 'Obrigada por avisar! Traga o atestado depois.', '2026-09-16 19:05:00'
        UNION ALL SELECT 'gestor@cei.com', 'usuario@cei.com', 'Favor enviar a lista de materiais do Maternal até sexta.', '2026-09-21 09:00:00'
        UNION ALL SELECT 'usuario@cei.com', 'gestor@cei.com', 'Enviado por e-mail, confira por favor.', '2026-09-24 16:45:00'
        UNION ALL SELECT 'luciana.gomes@email.com', 'juliana.rocha@cei.com', 'A Laura pode levar o brinquedo para o dia do brinquedo?', '2026-09-25 07:50:00'
        UNION ALL SELECT 'juliana.rocha@cei.com', 'luciana.gomes@email.com', 'Pode sim, desde que esteja identificado com o nome.', '2026-09-25 08:15:00'
       ) AS x
 INNER JOIN usuarios de   ON de.email   = x.de
 INNER JOIN usuarios para ON para.email = x.para;

-- ------------------------------------------------------------
-- TURMAS (10)  [INSERT+SUBSELECT] educador pelo e-mail
-- ------------------------------------------------------------
INSERT INTO turmas (nome, periodo, idade_min_meses, idade_max_meses, capacidade, ano_letivo, sala, educador_id) VALUES
('Berçário I-A',  'Integral',  4, 11, 12, 2026, 'Sala 01', (SELECT id FROM usuarios WHERE email = 'usuario@cei.com')),
('Berçário I-B',  'Manhã',     4, 11,  2, 2026, 'Sala 02', (SELECT id FROM usuarios WHERE email = 'patricia.lima@cei.com')),
('Berçário II-A', 'Integral', 12, 23, 15, 2026, 'Sala 03', (SELECT id FROM usuarios WHERE email = 'patricia.lima@cei.com')),
('Berçário II-B', 'Tarde',    12, 23, 15, 2026, 'Sala 04', (SELECT id FROM usuarios WHERE email = 'juliana.rocha@cei.com')),
('Maternal I-A',  'Integral', 24, 35, 20, 2026, 'Sala 05', (SELECT id FROM usuarios WHERE email = 'carla.mendes@cei.com')),
('Maternal I-B',  'Manhã',    24, 35, 20, 2026, 'Sala 06', NULL),
('Maternal II-A', 'Integral', 36, 47, 20, 2026, 'Sala 07', (SELECT id FROM usuarios WHERE email = 'usuario@cei.com')),
('Maternal II-B', 'Tarde',    36, 47, 20, 2026, 'Sala 08', NULL),
('Infantil I',    'Integral', 48, 59, 25, 2026, 'Sala 09', (SELECT id FROM usuarios WHERE email = 'renata.alves@cei.com')),
('Infantil II',   'Manhã',    60, 71, 25, 2026, 'Sala 10', (SELECT id FROM usuarios WHERE email = 'juliana.rocha@cei.com'));

-- ------------------------------------------------------------
-- CRIANÇAS (22)  — CPFs válidos (conferidos por fn_valida_cpf)
-- ------------------------------------------------------------
INSERT INTO criancas (nome, data_nascimento, cpf, sexo, alergias, restricao_alimentar, data_cadastro) VALUES
('Alice Ferreira Santos',     '2025-06-10', '526.018.159-06', 'F', 'Proteína do leite de vaca', 'Sem lactose', '2026-01-20'),
('Miguel Oliveira Costa',     '2025-08-22', '083.016.613-05', 'M', NULL, NULL, '2026-01-20'),
('Helena Rodrigues Lima',     '2025-05-03', '186.091.390-34', 'F', NULL, NULL, '2026-01-21'),
('Arthur Almeida Souza',      '2024-07-15', '996.030.824-30', 'M', 'Amendoim', 'Sem amendoim', '2026-01-21'),
('Laura Pereira Gomes',       '2024-11-03', '628.194.821-12', 'F', NULL, NULL, '2026-01-22'),
('Heitor Carvalho Dias',      '2025-01-20', '993.518.190-19', 'M', NULL, NULL, '2026-01-22'),
('Valentina Ribeiro Martins', '2023-05-12', '937.865.797-41', 'F', 'Dipirona', NULL, '2026-01-23'),
('Bernardo Araújo Rocha',     '2023-09-30', '543.231.948-97', 'M', NULL, NULL, '2026-01-23'),
('Sophia Barbosa Nunes',      '2024-02-14', '757.491.186-06', 'F', NULL, 'Sem glúten', '2026-01-26'),
('Davi Cardoso Pinto',        '2022-06-18', '252.760.189-87', 'M', NULL, NULL, '2026-01-26'),
('Manuela Teixeira Moura',    '2022-10-05', '555.979.711-15', 'F', 'Ovo', 'Sem ovo', '2026-01-27'),
('Gabriel Mendes Freitas',    '2023-01-27', '471.049.746-01', 'M', NULL, NULL, '2026-01-27'),
('Isabella Castro Lopes',     '2021-08-09', '507.529.170-80', 'F', NULL, NULL, '2026-01-28'),
('Lorenzo Correia Batista',   '2021-12-01', '342.366.712-55', 'M', NULL, NULL, '2026-01-28'),
('Cecília Monteiro Ramos',    '2020-07-22', '768.426.846-50', 'F', NULL, NULL, '2026-01-29'),
('Théo Vieira Campos',        '2020-11-11', '563.212.233-60', 'M', 'Corante amarelo', NULL, '2026-01-29'),
('Lívia Duarte Farias',       '2024-09-09', '079.244.026-91', 'F', NULL, NULL, '2026-01-30'),
('Samuel Pires Cunha',        '2023-07-07', '859.952.890-47', 'M', NULL, NULL, '2026-01-30'),
('Luísa Moreira Prado',       '2022-12-12', '786.666.176-67', 'F', NULL, NULL, '2026-01-30'),
('Pedro Henrique Sales',      '2021-10-10', '031.372.159-94', 'M', NULL, NULL, '2026-01-30'),
('Benício Machado Reis',      '2023-11-20', '010.928.159-45', 'M', NULL, NULL, '2026-09-28'),
('Antonella Fonseca Luz',     '2025-07-07', '013.962.459-79', 'F', NULL, 'Sem lactose', '2026-09-29');

-- ------------------------------------------------------------
-- RESPONSÁVEIS (12)  [INSERT+SUBSELECT] vínculo com o login pelo e-mail
-- ------------------------------------------------------------
INSERT INTO responsaveis (usuario_id, nome, cpf, telefone, email) VALUES
((SELECT id FROM usuarios WHERE email = 'cliente@cei.com'),         'Fernanda Ferreira Santos', '571.177.774-27', '(11) 98111-0001', 'cliente@cei.com'),
((SELECT id FROM usuarios WHERE email = 'roberto.costa@email.com'), 'Roberto Oliveira Costa',   '121.547.280-30', '(11) 98111-0002', 'roberto.costa@email.com'),
((SELECT id FROM usuarios WHERE email = 'anapaula@email.com'),      'Ana Paula Rodrigues',      '385.280.841-32', '(11) 98111-0003', 'anapaula@email.com'),
((SELECT id FROM usuarios WHERE email = 'marcos.souza@email.com'),  'Marcos Almeida Souza',     '485.253.888-31', '(11) 98111-0004', 'marcos.souza@email.com'),
((SELECT id FROM usuarios WHERE email = 'luciana.gomes@email.com'), 'Luciana Pereira Gomes',    '539.336.338-93', '(11) 98111-0005', 'luciana.gomes@email.com'),
(NULL, 'Cláudia Carvalho Dias',   '750.047.439-32', '(11) 98111-0006', NULL),
(NULL, 'Sérgio Ribeiro Martins',  '575.513.137-61', '(11) 98111-0007', 'sergio.martins@email.com'),
(NULL, 'Débora Araújo Rocha',     '353.799.075-80', '(11) 98111-0008', NULL),
(NULL, 'Tereza Barbosa',          '116.372.651-66', '(11) 98111-0009', NULL),
(NULL, 'Paulo Cardoso Pinto',     '676.122.202-88', '(11) 98111-0010', 'paulo.pinto@email.com'),
(NULL, 'Simone Teixeira Moura',   '972.997.528-08', '(11) 98111-0011', NULL),
(NULL, 'Jorge Castro Lopes',      '820.018.263-03', '(11) 98111-0012', NULL);

-- ------------------------------------------------------------
-- CRIANÇA x RESPONSÁVEL (27)  [INSERT+SUBSELECT] por CPF
-- ------------------------------------------------------------
INSERT INTO crianca_responsavel (crianca_id, responsavel_id, parentesco, autorizado_buscar)
SELECT c.id, r.id, x.parentesco, x.autorizado
  FROM (
        SELECT '526.018.159-06' AS cpf_crianca, '571.177.774-27' AS cpf_resp, 'Mãe' AS parentesco, 1 AS autorizado
        UNION ALL SELECT '526.018.159-06', '972.997.528-08', 'Outro',   0
        UNION ALL SELECT '083.016.613-05', '121.547.280-30', 'Pai',     1
        UNION ALL SELECT '342.366.712-55', '121.547.280-30', 'Pai',     1
        UNION ALL SELECT '186.091.390-34', '385.280.841-32', 'Mãe',     1
        UNION ALL SELECT '768.426.846-50', '385.280.841-32', 'Mãe',     1
        UNION ALL SELECT '996.030.824-30', '485.253.888-31', 'Pai',     1
        UNION ALL SELECT '563.212.233-60', '485.253.888-31', 'Pai',     1
        UNION ALL SELECT '628.194.821-12', '539.336.338-93', 'Mãe',     1
        UNION ALL SELECT '079.244.026-91', '539.336.338-93', 'Mãe',     1
        UNION ALL SELECT '993.518.190-19', '750.047.439-32', 'Mãe',     1
        UNION ALL SELECT '937.865.797-41', '575.513.137-61', 'Pai',     1
        UNION ALL SELECT '859.952.890-47', '575.513.137-61', 'Tio(a)',  0
        UNION ALL SELECT '543.231.948-97', '353.799.075-80', 'Mãe',     1
        UNION ALL SELECT '859.952.890-47', '353.799.075-80', 'Mãe',     1
        UNION ALL SELECT '010.928.159-45', '353.799.075-80', 'Tio(a)',  1
        UNION ALL SELECT '757.491.186-06', '116.372.651-66', 'Avó/Avô', 1
        UNION ALL SELECT '786.666.176-67', '116.372.651-66', 'Avó/Avô', 0
        UNION ALL SELECT '252.760.189-87', '676.122.202-88', 'Pai',     1
        UNION ALL SELECT '471.049.746-01', '676.122.202-88', 'Pai',     1
        UNION ALL SELECT '555.979.711-15', '972.997.528-08', 'Mãe',     1
        UNION ALL SELECT '786.666.176-67', '972.997.528-08', 'Tio(a)',  1
        UNION ALL SELECT '507.529.170-80', '820.018.263-03', 'Pai',     1
        UNION ALL SELECT '031.372.159-94', '820.018.263-03', 'Outro',   0
        UNION ALL SELECT '013.962.459-79', '571.177.774-27', 'Tio(a)',  1
        UNION ALL SELECT '993.518.190-19', '575.513.137-61', 'Outro',   0
        UNION ALL SELECT '010.928.159-45', '750.047.439-32', 'Outro',   1
       ) AS x
 INNER JOIN criancas c     ON c.cpf = x.cpf_crianca
 INNER JOIN responsaveis r ON r.cpf = x.cpf_resp;

-- ------------------------------------------------------------
-- MATRÍCULAS (20)  [INSERT+SUBSELECT] criança e turma pelo CPF/nome
-- (trg_matriculas_bi_valida confere vaga e faixa etária de cada linha;
--  trg_matriculas_ai_auditoria grava a auditoria)
-- ------------------------------------------------------------
INSERT INTO matriculas (crianca_id, turma_id, ano_letivo, data_matricula, status)
SELECT c.id, t.id, t.ano_letivo, '2026-02-02', 'Ativa'
  FROM (
        SELECT '526.018.159-06' AS cpf, 'Berçário I-A' AS turma
        UNION ALL SELECT '083.016.613-05', 'Berçário I-B'
        UNION ALL SELECT '186.091.390-34', 'Berçário I-B'
        UNION ALL SELECT '996.030.824-30', 'Berçário II-A'
        UNION ALL SELECT '993.518.190-19', 'Berçário II-A'
        UNION ALL SELECT '628.194.821-12', 'Berçário II-B'
        UNION ALL SELECT '079.244.026-91', 'Berçário II-B'
        UNION ALL SELECT '937.865.797-41', 'Maternal I-A'
        UNION ALL SELECT '757.491.186-06', 'Maternal I-A'
        UNION ALL SELECT '543.231.948-97', 'Maternal I-B'
        UNION ALL SELECT '859.952.890-47', 'Maternal I-B'
        UNION ALL SELECT '252.760.189-87', 'Maternal II-A'
        UNION ALL SELECT '471.049.746-01', 'Maternal II-A'
        UNION ALL SELECT '555.979.711-15', 'Maternal II-B'
        UNION ALL SELECT '786.666.176-67', 'Maternal II-B'
        UNION ALL SELECT '507.529.170-80', 'Infantil I'
        UNION ALL SELECT '342.366.712-55', 'Infantil I'
        UNION ALL SELECT '031.372.159-94', 'Infantil I'
        UNION ALL SELECT '768.426.846-50', 'Infantil II'
        UNION ALL SELECT '563.212.233-60', 'Infantil II'
       ) AS x
 INNER JOIN criancas c ON c.cpf = x.cpf
 INNER JOIN turmas t   ON t.nome = x.turma AND t.ano_letivo = 2026;

-- ------------------------------------------------------------
-- FREQUÊNCIAS (setembro/2026, dias úteis, todas as matrículas)
-- [INSERT+SUBSELECT] calendário gerado por tabela derivada.
-- O Heitor falta às segundas e sextas (caso de baixa frequência).
-- ------------------------------------------------------------
INSERT INTO frequencias (matricula_id, data_aula, presente, justificativa, registrado_por)
SELECT m.id,
       d.dia,
       CASE WHEN m.crianca_id = (SELECT id FROM criancas WHERE cpf = '993.518.190-19')
                 AND DAYOFWEEK(d.dia) IN (2, 6) THEN 0
            WHEN MOD(m.id + DAY(d.dia), 11) = 0 THEN 0
            ELSE 1 END,
       CASE WHEN m.crianca_id = (SELECT id FROM criancas WHERE cpf = '993.518.190-19')
                 AND DAYOFWEEK(d.dia) IN (2, 6) THEN 'Acompanhamento médico'
            WHEN MOD(m.id + DAY(d.dia), 11) = 0 THEN 'Falta não justificada'
            ELSE NULL END,
       t.educador_id
  FROM matriculas m
 INNER JOIN turmas t ON t.id = m.turma_id
 INNER JOIN (
        SELECT DATE_ADD('2026-09-01', INTERVAL (dez.n * 10 + uni.n) DAY) AS dia
          FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) AS uni
         CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2) AS dez
       ) AS d ON d.dia <= '2026-09-30'
 WHERE m.status = 'Ativa'
   AND DAYOFWEEK(d.dia) NOT IN (1, 7);

-- ------------------------------------------------------------
-- MOVIMENTAÇÕES DE ESTOQUE - compras do semestre (14 entradas)
-- O trigger trg_mov_ai_atualiza_saldo soma cada entrada ao saldo.
-- Os IDs de produto vão para variáveis porque o INSERT não pode
-- ler a tabela produtos que o trigger altera (erro 1442).
-- [INSERT+SUBSELECT] fornecedor e usuário pelo CNPJ/e-mail
-- ------------------------------------------------------------
SELECT id INTO @p_arroz    FROM produtos WHERE nome = 'Arroz tipo 1 (kg)';
SELECT id INTO @p_feijao   FROM produtos WHERE nome = 'Feijão carioca (kg)';
SELECT id INTO @p_leite    FROM produtos WHERE nome = 'Leite integral (L)';
SELECT id INTO @p_banana   FROM produtos WHERE nome = 'Banana prata (kg)';
SELECT id INTO @p_frango   FROM produtos WHERE nome = 'Peito de frango (kg)';
SELECT id INTO @p_pao      FROM produtos WHERE nome = 'Pão de forma (pct)';
SELECT id INTO @p_fralda   FROM produtos WHERE nome = 'Fralda descartável M (pct)';
SELECT id INTO @p_lenco    FROM produtos WHERE nome = 'Lenço umedecido (pct)';
SELECT id INTO @p_sabonete FROM produtos WHERE nome = 'Sabonete líquido infantil (L)';
SELECT id INTO @p_alcool   FROM produtos WHERE nome = 'Álcool 70% (L)';
SELECT id INTO @p_massinha FROM produtos WHERE nome = 'Massinha de modelar (cx)';
SELECT id INTO @p_guache   FROM produtos WHERE nome = 'Tinta guache (cx)';
SELECT id INTO @p_resma    FROM produtos WHERE nome = 'Resma Papel A4';
SELECT id INTO @p_estojo   FROM produtos WHERE nome = 'Kit Estojo Colorido';

INSERT INTO movimentacoes_estoque (produto_id, fornecedor_id, usuario_id, tipo, quantidade, valor_unitario, data_movimentacao, motivo) VALUES
(@p_arroz,    (SELECT id FROM fornecedores WHERE cnpj = '33.444.555/0001-03'), (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'), 'Entrada', 60,  5.50, '2026-09-01 08:00:00', 'NF 1021 - compra mensal'),
(@p_feijao,   (SELECT id FROM fornecedores WHERE cnpj = '33.444.555/0001-03'), (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'), 'Entrada', 40,  8.90, '2026-09-01 08:00:00', 'NF 1021 - compra mensal'),
(@p_leite,    (SELECT id FROM fornecedores WHERE cnpj = '22.333.444/0001-92'), (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'), 'Entrada', 90,  4.79, '2026-09-01 09:30:00', 'NF 552 - compra mensal'),
(@p_banana,   (SELECT id FROM fornecedores WHERE cnpj = '11.222.333/0001-81'), (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'), 'Entrada', 25,  6.20, '2026-09-25 07:30:00', 'NF 88 - hortifruti semanal'),
(@p_frango,   (SELECT id FROM fornecedores WHERE cnpj = '77.888.999/0001-47'), (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'), 'Entrada', 30, 18.90, '2026-09-02 10:00:00', 'NF 3310 - congelados'),
(@p_pao,      (SELECT id FROM fornecedores WHERE cnpj = '88.999.000/0001-58'), (SELECT id FROM usuarios WHERE email = 'gestor@cei.com'), 'Entrada', 20,  7.50, '2026-09-25 07:00:00', 'NF 145 - padaria semanal'),
(@p_fralda,   (SELECT id FROM fornecedores WHERE cnpj = '44.555.666/0001-14'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 25, 52.00, '2026-09-03 14:00:00', 'NF 7781 - higiene'),
(@p_lenco,    (SELECT id FROM fornecedores WHERE cnpj = '44.555.666/0001-14'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 40,  9.90, '2026-09-03 14:00:00', 'NF 7781 - higiene'),
(@p_sabonete, (SELECT id FROM fornecedores WHERE cnpj = '44.555.666/0001-14'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 12, 14.50, '2026-09-03 14:00:00', 'NF 7781 - higiene'),
(@p_alcool,   (SELECT id FROM fornecedores WHERE cnpj = '66.777.888/0001-36'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 20,  8.00, '2026-09-04 11:00:00', 'NF 230 - limpeza'),
(@p_massinha, (SELECT id FROM fornecedores WHERE cnpj = '55.666.777/0001-25'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 15, 12.00, '2026-09-04 15:00:00', 'NF 912 - pedagógico'),
(@p_guache,   (SELECT id FROM fornecedores WHERE cnpj = '55.666.777/0001-25'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 12, 11.50, '2026-09-04 15:00:00', 'NF 912 - pedagógico'),
(@p_resma,    (SELECT id FROM fornecedores WHERE cnpj = '12.345.678/0001-99'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 10, 25.90, '2026-09-05 10:00:00', 'NF 4410 - escritório'),
(@p_estojo,   (SELECT id FROM fornecedores WHERE cnpj = '55.666.777/0001-25'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'),  'Entrada', 20, 15.00, '2026-09-05 10:00:00', 'NF 913 - pedagógico');

-- Saídas avulsas de higiene/pedagógico (o saldo cai; Sabonete e
-- Massinha ficam abaixo do mínimo e geram ALERTA na auditoria)
INSERT INTO movimentacoes_estoque (produto_id, usuario_id, tipo, quantidade, data_movimentacao, motivo) VALUES
(@p_fralda,   (SELECT id FROM usuarios WHERE email = 'usuario@cei.com'),       'Saída', 9,  '2026-09-15 08:00:00', 'Consumo quinzenal - Berçários'),
(@p_lenco,    (SELECT id FROM usuarios WHERE email = 'usuario@cei.com'),       'Saída', 12, '2026-09-15 08:00:00', 'Consumo quinzenal - Berçários'),
(@p_sabonete, (SELECT id FROM usuarios WHERE email = 'beatriz.nunes@cei.com'), 'Saída', 8,  '2026-09-18 08:00:00', 'Reposição dos banheiros'),
(@p_massinha, (SELECT id FROM usuarios WHERE email = 'carla.mendes@cei.com'),  'Saída', 6,  '2026-09-22 13:00:00', 'Projeto Cores - Maternal I');

-- ------------------------------------------------------------
-- CARDÁPIOS (12)
-- ------------------------------------------------------------
INSERT INTO cardapios (data_refeicao, tipo_refeicao, descricao, calorias) VALUES
('2026-09-28', 'Almoço',          'Arroz, feijão, frango desfiado e cenoura',   420),
('2026-09-28', 'Lanche da tarde', 'Leite com banana amassada e pão',            250),
('2026-09-29', 'Almoço',          'Arroz, feijão, frango assado e abobrinha',   430),
('2026-09-29', 'Lanche da tarde', 'Vitamina de banana e pão integral',          260),
('2026-09-30', 'Almoço',          'Risoto de frango com legumes',               410),
('2026-09-30', 'Lanche da tarde', 'Leite e pão com requeijão',                  240),
('2026-10-01', 'Almoço',          'Arroz, feijão, frango em cubos e chuchu',    425),
('2026-10-01', 'Lanche da tarde', 'Mingau de aveia com banana',                 230),
('2026-10-02', 'Almoço',          'Arroz, feijão, frango ao molho e beterraba', 430),
('2026-10-02', 'Lanche da tarde', 'Leite com achocolatado e pão',               255),
('2026-10-05', 'Almoço',          'Arroz, feijão, frango grelhado e brócolis',  420),
('2026-10-05', 'Lanche da tarde', 'Vitamina de banana e pão',                   260);

-- ------------------------------------------------------------
-- INSUMOS DO CARDÁPIO (36)  [INSERT+SUBSELECT] produto x tipo de refeição
-- ------------------------------------------------------------
INSERT INTO cardapio_insumos (cardapio_id, produto_id, quantidade_utilizada)
SELECT c.id, p.id, x.qtd
  FROM cardapios c
 INNER JOIN (
        SELECT 'Almoço' AS tipo, 'Arroz tipo 1 (kg)' AS produto, 3 AS qtd
        UNION ALL SELECT 'Almoço', 'Feijão carioca (kg)', 2
        UNION ALL SELECT 'Almoço', 'Peito de frango (kg)', 3
        UNION ALL SELECT 'Lanche da tarde', 'Leite integral (L)', 6
        UNION ALL SELECT 'Lanche da tarde', 'Banana prata (kg)', 2
        UNION ALL SELECT 'Lanche da tarde', 'Pão de forma (pct)', 2
       ) AS x ON x.tipo = c.tipo_refeicao
 INNER JOIN produtos p ON p.nome = x.produto
 WHERE c.data_refeicao BETWEEN '2026-09-28' AND '2026-10-05';

-- Baixa automática dos insumos das refeições já servidas (procedure P6)
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-09-28' AND tipo_refeicao = 'Almoço'),          (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-09-28' AND tipo_refeicao = 'Lanche da tarde'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-09-29' AND tipo_refeicao = 'Almoço'),          (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-09-29' AND tipo_refeicao = 'Lanche da tarde'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-09-30' AND tipo_refeicao = 'Almoço'),          (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-09-30' AND tipo_refeicao = 'Lanche da tarde'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-10-01' AND tipo_refeicao = 'Almoço'),          (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);
CALL sp_baixa_insumos_cardapio((SELECT id FROM cardapios WHERE data_refeicao = '2026-10-01' AND tipo_refeicao = 'Lanche da tarde'), (SELECT id FROM usuarios WHERE email = 'admin@cei.com'), @msg);

-- ------------------------------------------------------------
-- DISPENSAS DE MEDICAMENTOS (13)  [INSERT+SUBSELECT] criança e funcionário
-- (trg_medicamentos_bi_valida exige intervalo >= 4h entre doses)
-- ------------------------------------------------------------
INSERT INTO medicamentos_dispensas (crianca_id, medicamento, dosagem, data_hora, administrado_por, receita_medica, observacao)
SELECT c.id, x.medicamento, x.dosagem, x.data_hora, u.id, x.receita, x.obs
  FROM (
        SELECT '526.018.159-06' AS cpf, 'Paracetamol gotas 200mg/ml' AS medicamento, '8 gotas' AS dosagem, '2026-09-08 09:00:00' AS data_hora, 'beatriz.nunes@cei.com' AS email, 1 AS receita, 'Febre 38,2ºC' AS obs
        UNION ALL SELECT '526.018.159-06', 'Paracetamol gotas 200mg/ml', '8 gotas',  '2026-09-08 15:00:00', 'beatriz.nunes@cei.com', 1, 'Febre 37,9ºC'
        UNION ALL SELECT '993.518.190-19', 'Amoxicilina 250mg/5ml',      '5 ml',     '2026-09-14 08:00:00', 'beatriz.nunes@cei.com', 1, 'Tratamento de otite - 7 dias'
        UNION ALL SELECT '993.518.190-19', 'Amoxicilina 250mg/5ml',      '5 ml',     '2026-09-14 14:00:00', 'beatriz.nunes@cei.com', 1, NULL
        UNION ALL SELECT '993.518.190-19', 'Amoxicilina 250mg/5ml',      '5 ml',     '2026-09-15 08:00:00', 'beatriz.nunes@cei.com', 1, NULL
        UNION ALL SELECT '993.518.190-19', 'Amoxicilina 250mg/5ml',      '5 ml',     '2026-09-15 14:00:00', 'patricia.lima@cei.com', 1, 'Enfermeira em reunião'
        UNION ALL SELECT '252.760.189-87', 'Dipirona gotas 500mg/ml',    '10 gotas', '2026-09-10 10:30:00', 'beatriz.nunes@cei.com', 1, 'Dor de dente'
        UNION ALL SELECT '507.529.170-80', 'Loratadina xarope 1mg/ml',   '5 ml',     '2026-09-16 09:00:00', 'beatriz.nunes@cei.com', 1, 'Rinite alérgica'
        UNION ALL SELECT '507.529.170-80', 'Loratadina xarope 1mg/ml',   '5 ml',     '2026-09-17 09:00:00', 'beatriz.nunes@cei.com', 1, NULL
        UNION ALL SELECT '757.491.186-06', 'Soro fisiológico nasal',     '2 jatos',  '2026-09-21 08:30:00', 'carla.mendes@cei.com',  0, 'Higiene nasal'
        UNION ALL SELECT '757.491.186-06', 'Soro fisiológico nasal',     '2 jatos',  '2026-09-21 13:30:00', 'carla.mendes@cei.com',  0, NULL
        UNION ALL SELECT '563.212.233-60', 'Ibuprofeno gotas 50mg/ml',   '10 gotas', '2026-09-22 10:00:00', 'beatriz.nunes@cei.com', 1, 'Dor após queda no parquinho'
        UNION ALL SELECT '031.372.159-94', 'Paracetamol gotas 200mg/ml', '15 gotas', '2026-09-09 11:00:00', 'beatriz.nunes@cei.com', 1, 'Febre 38ºC'
       ) AS x
 INNER JOIN criancas c ON c.cpf = x.cpf
 INNER JOIN usuarios u ON u.email = x.email;
