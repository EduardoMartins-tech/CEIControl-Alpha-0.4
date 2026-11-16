<?php
require_once __DIR__ . '/../../config/database.php';

class ServicoModel {
    private $conn;

    public function __construct($conn) {
        $this->conn = $conn;
    }

    public function listarTodos() {
        return $this->conn->query("SELECT * FROM servicos ORDER BY nome ASC");
    }

    public function buscarPorId($id) {
        $stmt = $this->conn->prepare("SELECT * FROM servicos WHERE id = ?");
        $stmt->bind_param("i", $id);
        $stmt->execute();
        return $stmt->get_result()->fetch_assoc();
    }

    public function criar($nome, $descricao, $preco) {
        $stmt = $this->conn->prepare("INSERT INTO servicos (nome, descricao, preco, data_cadastro) VALUES (?, ?, ?, CURDATE())");
        $stmt->bind_param("ssd", $nome, $descricao, $preco);
        return $stmt->execute();
    }

    public function atualizar($id, $nome, $descricao, $preco) {
        $stmt = $this->conn->prepare("UPDATE servicos SET nome=?, descricao=?, preco=? WHERE id=?");
        $stmt->bind_param("ssdi", $nome, $descricao, $preco, $id);
        return $stmt->execute();
    }

    public function excluir($id) {
        $stmt = $this->conn->prepare("DELETE FROM servicos WHERE id = ?");
        $stmt->bind_param("i", $id);
        return $stmt->execute();
    }
}
?>
