<?php
require_once __DIR__ . '/../../config/database.php';

class EventoModel {
    private $conn;

    public function __construct($conn) {
        $this->conn = $conn;
    }

    public function listarTodos() {
        return $this->conn->query("SELECT * FROM agenda ORDER BY data_evento ASC");
    }

    // Responsáveis (perfil cliente) não veem eventos internos dos funcionários
    public function listarPorPerfil($perfil) {
        if ($perfil === 'cliente') {
            return $this->conn->query("SELECT * FROM agenda WHERE publico_alvo IN ('Pais', 'Geral') ORDER BY data_evento ASC");
        }
        return $this->listarTodos();
    }

    public function buscarPorId($id) {
        $stmt = $this->conn->prepare("SELECT * FROM agenda WHERE id = ?");
        $stmt->bind_param("i", $id);
        $stmt->execute();
        return $stmt->get_result()->fetch_assoc();
    }

    public function criar($titulo, $descricao, $data_evento, $hora_evento, $local, $criado_por, $publico_alvo) {
        // Hora em branco vira NULL; '' era gravado como 00:00 e aparecia na agenda
        $hora_evento = ($hora_evento === '') ? null : $hora_evento;
        $stmt = $this->conn->prepare("INSERT INTO agenda (titulo, descricao, data_evento, hora_evento, local, criado_por, publico_alvo, data_cadastro) VALUES (?, ?, ?, ?, ?, ?, ?, CURDATE())");
        $stmt->bind_param("sssssss", $titulo, $descricao, $data_evento, $hora_evento, $local, $criado_por, $publico_alvo);
        return $stmt->execute();
    }

    public function atualizar($id, $titulo, $descricao, $data_evento, $hora_evento, $local, $publico_alvo) {
        $hora_evento = ($hora_evento === '') ? null : $hora_evento;
        $stmt = $this->conn->prepare("UPDATE agenda SET titulo=?, descricao=?, data_evento=?, hora_evento=?, local=?, publico_alvo=? WHERE id=?");
        $stmt->bind_param("ssssssi", $titulo, $descricao, $data_evento, $hora_evento, $local, $publico_alvo, $id);
        return $stmt->execute();
    }

    public function excluir($id) {
        $stmt = $this->conn->prepare("DELETE FROM agenda WHERE id = ?");
        $stmt->bind_param("i", $id);
        return $stmt->execute();
    }
}
?>