/* ============================================================
   CEICONTROL - 10. BACKUP LÓGICO DENTRO DO SGBD (Requisito 16)
   Complementa database/backup/backup_ceicontrol.sh (mysqldump/binlog).
   Útil quando não há acesso ao terminal do servidor (ex.: phpMyAdmin).
   ============================================================ */

USE ceicontrol;

CREATE DATABASE IF NOT EXISTS ceicontrol_bkp CHARACTER SET utf8mb4;

DROP PROCEDURE IF EXISTS sp_backup_snapshot;

DELIMITER $$

-- B1. Snapshot completo: copia cada tabela para ceicontrol_bkp.<tabela>_AAAAMMDD
--     (estrutura com CREATE TABLE ... LIKE, dados com INSERT ... SELECT)
CREATE PROCEDURE sp_backup_snapshot()
MODIFIES SQL DATA
BEGIN
    DECLARE v_fim INT DEFAULT 0;
    DECLARE v_tabela VARCHAR(64);
    DECLARE v_sufixo CHAR(8) DEFAULT DATE_FORMAT(CURDATE(), '%Y%m%d');
    DECLARE cur CURSOR FOR
        SELECT table_name FROM information_schema.tables
         WHERE table_schema = 'ceicontrol' AND table_type = 'BASE TABLE';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;

    OPEN cur;
    copia: LOOP
        FETCH cur INTO v_tabela;
        IF v_fim = 1 THEN LEAVE copia; END IF;

        SET @sql = CONCAT('DROP TABLE IF EXISTS ceicontrol_bkp.`', v_tabela, '_', v_sufixo, '`');
        PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

        SET @sql = CONCAT('CREATE TABLE ceicontrol_bkp.`', v_tabela, '_', v_sufixo,
                          '` LIKE ceicontrol.`', v_tabela, '`');
        PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

        SET @sql = CONCAT('INSERT INTO ceicontrol_bkp.`', v_tabela, '_', v_sufixo,
                          '` SELECT * FROM ceicontrol.`', v_tabela, '`');
        PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;
    END LOOP;
    CLOSE cur;

    SELECT CONCAT('Snapshot ', v_sufixo, ' concluído em ceicontrol_bkp') AS resultado;
END$$

DELIMITER ;

-- Executa o snapshot completo
CALL sp_backup_snapshot();

-- B2. Backup diferencial lógico de uma tabela: só a frequência lançada
--     a partir de uma data (ex.: desde o último snapshot)
DROP TABLE IF EXISTS ceicontrol_bkp.frequencias_diferencial;
CREATE TABLE ceicontrol_bkp.frequencias_diferencial AS
SELECT * FROM ceicontrol.frequencias WHERE data_aula >= '2026-09-16';

-- B3. Exportação em CSV (requer privilégio FILE e o diretório de secure_file_priv;
--     no Railway não há acesso ao disco do servidor - use o script .sh)
-- SELECT * FROM ceicontrol.criancas
--   INTO OUTFILE '/var/lib/mysql-files/criancas.csv'
--   FIELDS TERMINATED BY ';' ENCLOSED BY '"' LINES TERMINATED BY '\n';

-- Conferência: quantidade de linhas na produção x backup diferencial
SELECT (SELECT COUNT(*) FROM ceicontrol.criancas)                     AS criancas_producao,
       (SELECT COUNT(*) FROM ceicontrol_bkp.frequencias_diferencial)  AS frequencias_no_diferencial;

/* Restauração de uma tabela a partir do snapshot (exemplo, não executar):
   START TRANSACTION;
   DELETE FROM ceicontrol.crianca_responsavel;
   INSERT INTO ceicontrol.crianca_responsavel SELECT * FROM ceicontrol_bkp.crianca_responsavel_AAAAMMDD;
   COMMIT;
*/
