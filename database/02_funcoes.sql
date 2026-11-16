/* ============================================================
   CEICONTROL - 02. FUNÇÕES (Requisito 12)
   Funções de cálculo e de validação de regras de negócio.
   Várias delas são chamadas pelos triggers (Requisito 14).
   ============================================================ */

USE ceicontrol;

DROP FUNCTION IF EXISTS fn_idade_meses;
DROP FUNCTION IF EXISTS fn_valida_cpf;
DROP FUNCTION IF EXISTS fn_idade_compativel;
DROP FUNCTION IF EXISTS fn_vagas_disponiveis;
DROP FUNCTION IF EXISTS fn_percentual_frequencia;
DROP FUNCTION IF EXISTS fn_situacao_estoque;
DROP FUNCTION IF EXISTS fn_intervalo_dose_minutos;
DROP FUNCTION IF EXISTS fn_custo_cardapio;

DELIMITER $$

-- F1. Idade (em meses completos) de uma criança numa data de referência
CREATE FUNCTION fn_idade_meses(p_data_nascimento DATE, p_data_referencia DATE)
RETURNS INT
DETERMINISTIC NO SQL
BEGIN
    RETURN TIMESTAMPDIFF(MONTH, p_data_nascimento, p_data_referencia);
END$$

-- F2. Validação de CPF (dígitos verificadores). Aceita com ou sem máscara.
CREATE FUNCTION fn_valida_cpf(p_cpf VARCHAR(14))
RETURNS TINYINT
DETERMINISTIC NO SQL
BEGIN
    DECLARE v_cpf  VARCHAR(14);
    DECLARE v_soma INT;
    DECLARE v_dv   INT;
    DECLARE i      INT;

    IF p_cpf IS NULL THEN
        RETURN 0;
    END IF;

    SET v_cpf = REPLACE(REPLACE(REPLACE(TRIM(p_cpf), '.', ''), '-', ''), ' ', '');

    -- 11 dígitos e não pode ser sequência repetida (000.000.000-00, 111..., etc.).
    -- Lista explícita: no MySQL 8, "v = REPEAT(SUBSTRING(v,1,1),11)" dentro de
    -- rotina armazenada retorna verdadeiro indevidamente (reuso de buffer).
    IF v_cpf NOT REGEXP '^[0-9]{11}$'
       OR v_cpf IN ('00000000000','11111111111','22222222222','33333333333','44444444444',
                    '55555555555','66666666666','77777777777','88888888888','99999999999') THEN
        RETURN 0;
    END IF;

    -- 1º dígito verificador
    SET v_soma = 0, i = 1;
    WHILE i <= 9 DO
        SET v_soma = v_soma + CAST(SUBSTRING(v_cpf, i, 1) AS UNSIGNED) * (11 - i);
        SET i = i + 1;
    END WHILE;
    SET v_dv = (v_soma * 10) MOD 11;
    IF v_dv = 10 THEN SET v_dv = 0; END IF;
    IF v_dv <> CAST(SUBSTRING(v_cpf, 10, 1) AS UNSIGNED) THEN
        RETURN 0;
    END IF;

    -- 2º dígito verificador
    SET v_soma = 0, i = 1;
    WHILE i <= 10 DO
        SET v_soma = v_soma + CAST(SUBSTRING(v_cpf, i, 1) AS UNSIGNED) * (12 - i);
        SET i = i + 1;
    END WHILE;
    SET v_dv = (v_soma * 10) MOD 11;
    IF v_dv = 10 THEN SET v_dv = 0; END IF;

    RETURN IF(v_dv = CAST(SUBSTRING(v_cpf, 11, 1) AS UNSIGNED), 1, 0);
END$$

-- F3. A criança está na faixa etária da turma?
--     Regra: idade calculada na data de corte 31/03 do ano letivo da turma.
CREATE FUNCTION fn_idade_compativel(p_crianca_id INT, p_turma_id INT)
RETURNS TINYINT
READS SQL DATA
BEGIN
    DECLARE v_nascimento DATE;
    DECLARE v_min INT;
    DECLARE v_max INT;
    DECLARE v_corte DATE;
    DECLARE v_idade INT;

    SELECT data_nascimento INTO v_nascimento FROM criancas WHERE id = p_crianca_id;
    SELECT idade_min_meses, idade_max_meses, CAST(CONCAT(ano_letivo, '-03-31') AS DATE)
      INTO v_min, v_max, v_corte
      FROM turmas WHERE id = p_turma_id;

    IF v_nascimento IS NULL OR v_min IS NULL THEN
        RETURN 0;
    END IF;

    SET v_idade = fn_idade_meses(v_nascimento, v_corte);
    RETURN IF(v_idade BETWEEN v_min AND v_max, 1, 0);
END$$

-- F4. Vagas disponíveis numa turma (capacidade - matrículas ativas)
CREATE FUNCTION fn_vagas_disponiveis(p_turma_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_capacidade INT DEFAULT 0;
    DECLARE v_ocupadas INT DEFAULT 0;

    SELECT capacidade INTO v_capacidade FROM turmas WHERE id = p_turma_id;
    SELECT COUNT(*) INTO v_ocupadas
      FROM matriculas
     WHERE turma_id = p_turma_id AND status = 'Ativa';

    RETURN v_capacidade - v_ocupadas;
END$$

-- F5. Percentual de presença de uma matrícula num período (NULL se não houve aula)
CREATE FUNCTION fn_percentual_frequencia(p_matricula_id INT, p_inicio DATE, p_fim DATE)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE v_total INT;
    DECLARE v_presencas INT;

    SELECT COUNT(*), COALESCE(SUM(presente), 0)
      INTO v_total, v_presencas
      FROM frequencias
     WHERE matricula_id = p_matricula_id
       AND data_aula BETWEEN p_inicio AND p_fim;

    IF v_total = 0 THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(v_presencas * 100 / v_total, 2);
END$$

-- F6. Classificação do nível de estoque de um insumo
CREATE FUNCTION fn_situacao_estoque(p_quantidade INT, p_estoque_minimo INT)
RETURNS VARCHAR(10)
DETERMINISTIC NO SQL
BEGIN
    RETURN CASE
        WHEN p_quantidade <= 0                    THEN 'Esgotado'
        WHEN p_quantidade <  p_estoque_minimo     THEN 'Crítico'
        WHEN p_quantidade <  p_estoque_minimo * 2 THEN 'Baixo'
        ELSE 'Normal'
    END;
END$$

-- F7. Intervalo (minutos) entre um horário e a dose mais próxima do mesmo
--     medicamento já registrada para a criança (NULL se não houver dose).
CREATE FUNCTION fn_intervalo_dose_minutos(p_crianca_id INT, p_medicamento VARCHAR(100), p_data_hora DATETIME)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_minutos INT;

    SELECT MIN(ABS(TIMESTAMPDIFF(MINUTE, data_hora, p_data_hora)))
      INTO v_minutos
      FROM medicamentos_dispensas
     WHERE crianca_id = p_crianca_id
       AND medicamento = p_medicamento;

    RETURN v_minutos;
END$$

-- F8. Custo estimado de uma refeição do cardápio (insumos x preço unitário)
CREATE FUNCTION fn_custo_cardapio(p_cardapio_id INT)
RETURNS DECIMAL(10,2)
READS SQL DATA
BEGIN
    DECLARE v_custo DECIMAL(10,2);

    SELECT COALESCE(SUM(ci.quantidade_utilizada * p.preco), 0)
      INTO v_custo
      FROM cardapio_insumos ci
     INNER JOIN produtos p ON p.id = ci.produto_id
     WHERE ci.cardapio_id = p_cardapio_id;

    RETURN v_custo;
END$$

DELIMITER ;
