# Roteiro para apresentar o banco de dados

Um caminho de uns 5 minutos pelos arquivos, na ordem em que o banco é montado.
Cada passo diz qual arquivo abrir e o que falar.

## 1. O modelo (abrir `DER_CEIControl.png`)

- O banco do CEIControl tem **17 tabelas**: as 6 originais do site (usuários, fornecedores,
  produtos, serviços, agenda e mensagens) e 11 novas para a rotina da creche.
- O centro do modelo é a **criança**: ela tem responsáveis, é matriculada numa turma,
  tem frequência diária e pode receber medicamentos.
- Duas relações muitos-para-muitos viram tabelas associativas:
  - `crianca_responsavel`: uma criança tem vários responsáveis, e um responsável pode ter vários filhos;
  - `cardapio_insumos`: uma refeição usa vários produtos do estoque.

## 2. A estrutura (abrir `01_estrutura_ddl.sql`)

- Cada tabela tem chave primária, chaves estrangeiras, `NOT NULL`, `UNIQUE` e `CHECK`.
- Exemplos para mostrar:
  - `UNIQUE (crianca_id, ano_letivo)` em `matriculas`: a criança só tem uma matrícula por ano;
  - `CHECK (capacidade BETWEEN 1 AND 40)` em `turmas`;
  - `ON DELETE RESTRICT` em `matriculas`: não dá para apagar uma turma que tem crianças.
- No fim do arquivo estão os **9 índices**, cada um com o comentário da consulta que ele acelera.

## 3. As regras de negócio (abrir `02_funcoes.sql`, `03_procedures.sql` e `04_triggers.sql`)

- **Funções** calculam e validam: CPF, idade em meses, vagas na turma, percentual de frequência.
- **Procedures** automatizam processos: matricular, transferir de turma, abrir a chamada do dia,
  dar baixa no estoque das refeições.
- **Triggers** garantem as regras sozinhos, mesmo que alguém grave direto no banco:
  - matrícula em turma lotada ou fora da faixa etária é recusada;
  - não se dá a mesma dose de remédio antes de 4 horas;
  - toda entrada ou saída de estoque atualiza o saldo, e o saldo nunca fica negativo;
  - toda matrícula criada ou alterada vai para a tabela `auditoria`.

## 4. Os dados e as consultas (abrir `05` a `08`)

- `05_carga_dados.sql`: pelo menos 10 registros em cada tabela, com CPFs válidos.
  Os blocos marcados `[INSERT+SUBSELECT]` buscam o ID em outra tabela
  (por exemplo, o educador da turma pelo e-mail).
- `06_atualizacoes_remocoes.sql`: os DELETEs seguem a ordem filho → pai para não quebrar
  a integridade (frequência → medicamentos → matrícula → criança).
- `07_consultas_join_subquery.sql`: consultas que cruzam as tabelas, como "quem pode buscar cada
  criança" ou "turmas com presença abaixo da média".
- `08_views.sql`: 8 views prontas para relatórios e consultas sobre elas com COUNT, SUM, AVG,
  MIN, MAX, IN e BETWEEN.

## 5. Transações (abrir `09_transacoes.sql`)

- Mostrar o **T2**: um reajuste de preço digitado errado é desfeito com `ROLLBACK`,
  e os preços voltam ao valor original.
- Mostrar o **T6**: a procedure tenta matricular numa turma lotada, o banco recusa,
  e nada fica gravado pela metade.

## 6. Backup (abrir `backup/backup_ceicontrol.sh` e `10_backup_logico.sql`)

- **Completo**: estrutura, dados, procedures e triggers num arquivo só.
- **Parcial**: só as tabelas com dados das crianças.
- **Diferencial**: só o que foi lançado desde o último backup completo.
- **Incremental**: cópia dos logs binários do MySQL.
- **Verificar**: restaura o último backup num banco de teste e compara as contagens.
- O `10_backup_logico.sql` faz uma cópia das tabelas pelo próprio SQL, útil no phpMyAdmin.

## Perguntas prováveis

- **Por que regra no banco e não só no PHP?** Porque vale para qualquer programa que acesse
  o banco: o site, o app em Kotlin ou alguém no phpMyAdmin.
- **Funciona no MySQL do Railway?** Sim, foi testado no MySQL 8 e no MariaDB.
- **Por que `Avó/Avô` é um valor só?** No MySQL 8, a comparação de texto ignora acentos,
  então "Avó" e "Avô" no mesmo ENUM seriam valores repetidos.
