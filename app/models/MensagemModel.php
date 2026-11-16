<?php
require_once __DIR__ . '/../../config/database.php';

class MensagemModel {
    private $conn;

    public function __construct($conn) {
        $this->conn = $conn;
    }

    public function buscarConversa($meu_id, $contato_id) {
        $stmt = $this->conn->prepare("SELECT * FROM mensagens WHERE (remetente_id = ? AND destinatario_id = ?) OR (remetente_id = ? AND destinatario_id = ?) ORDER BY data_envio ASC, id ASC");
        $stmt->bind_param("iiii", $meu_id, $contato_id, $contato_id, $meu_id);
        $stmt->execute();
        return $stmt->get_result();
    }

    // Mensagens da conversa posteriores à última já exibida (atualização em tempo real)
    public function buscarNovas($meu_id, $contato_id, $depois_de_id) {
        $stmt = $this->conn->prepare("SELECT id, remetente_id, mensagem, data_envio FROM mensagens WHERE id > ? AND ((remetente_id = ? AND destinatario_id = ?) OR (remetente_id = ? AND destinatario_id = ?)) ORDER BY id ASC");
        $stmt->bind_param("iiiii", $depois_de_id, $meu_id, $contato_id, $contato_id, $meu_id);
        $stmt->execute();
        return $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    }

    public function enviar($remetente_id, $destinatario_id, $mensagem) {
        $stmt = $this->conn->prepare("INSERT INTO mensagens (remetente_id, destinatario_id, mensagem) VALUES (?, ?, ?)");
        $stmt->bind_param("iis", $remetente_id, $destinatario_id, $mensagem);
        return $stmt->execute();
    }

    // Responsáveis (cliente) conversam só com professores e a direção;
    // professores e direção conversam com todos.
    public function listarContatos($meu_id, $meu_perfil) {
        if ($meu_perfil === 'cliente') {
            $stmt = $this->conn->prepare("SELECT id, nome, perfil FROM usuarios WHERE id != ? AND perfil IN ('admin', 'usuario') ORDER BY nome");
        } else {
            $stmt = $this->conn->prepare("SELECT id, nome, perfil FROM usuarios WHERE id != ? ORDER BY nome");
        }
        $stmt->bind_param("i", $meu_id);
        $stmt->execute();
        return $stmt->get_result();
    }

    // Dados do contato, ou null se o usuário logado não pode conversar com ele
    public function buscarContatoPermitido($meu_id, $meu_perfil, $contato_id) {
        if ($contato_id == $meu_id) {
            return null;
        }
        $stmt = $this->conn->prepare("SELECT id, nome, perfil FROM usuarios WHERE id = ?");
        $stmt->bind_param("i", $contato_id);
        $stmt->execute();
        $contato = $stmt->get_result()->fetch_assoc();
        if (!$contato || ($meu_perfil === 'cliente' && $contato['perfil'] === 'cliente')) {
            return null;
        }
        return $contato;
    }
}
?>
