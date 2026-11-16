<?php
// Recebe o POST de servicos/processa (novo) e servicos/atualizar (edição)
if (!isset($_SESSION['perfil']) || $_SESSION['perfil'] !== 'admin') {
    header("Location: " . BASE_URL . "login");
    exit;
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../app/controllers/ServicoController.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header("Location: " . BASE_URL . "produtos");
    exit;
}

$id        = intval($_POST['id'] ?? 0);
$nome      = trim($_POST['nome'] ?? '');
$descricao = trim($_POST['descricao'] ?? '');
$preco     = floatval($_POST['preco'] ?? 0);

if (!$nome || $preco < 0) {
    $volta = $id > 0 ? "servicos/editar?id=$id&erro=dados_invalidos" : "servicos/cadastro?erro=campos_vazios";
    header("Location: " . BASE_URL . $volta);
    exit;
}

$controller = new ServicoController($conn);
if ($id > 0) {
    $controller->atualizar($id, $nome, $descricao, $preco);
} else {
    $controller->cadastrar($nome, $descricao, $preco);
}
?>
