<?php
if (!isset($_SESSION['perfil']) || $_SESSION['perfil'] !== 'admin') {
    header("Location: " . BASE_URL . "login");
    exit;
}

require_once __DIR__ . '/../../../config/database.php';
require_once __DIR__ . '/../../../app/controllers/ServicoController.php';

// A mesma tela atende cadastro (servicos/cadastro) e edição (servicos/editar?id=N)
$servico = null;
if (isset($_GET['id'])) {
    $controller = new ServicoController($conn);
    $servico = $controller->buscar((int) $_GET['id']);
    if (!$servico) {
        header("Location: " . BASE_URL . "produtos?erro=nao_encontrado");
        exit;
    }
}
$editando = $servico !== null;

$pagina_atual = 'estoque';
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= $editando ? 'Editar Serviço' : 'Novo Serviço' ?> - CEIControl</title>
    <link rel="stylesheet" href="<?= BASE_URL ?>public/style.css">
    <link rel="stylesheet" href="<?= BASE_URL ?>public/mobile.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css">
    <link rel="icon" type="image/png" href="<?= BASE_URL ?>public/assets/ceicontrol.png">
</head>
<body class="dashboard-body">
<div class="dashboard-container">
    <?php include __DIR__ . '/../../../sidebar.php'; ?>

    <main class="main-content">
        <header class="dash-header">
            <div class="header-welcome">
                <h1><?= $editando ? 'Editar Serviço' : 'Novo Serviço' ?></h1>
                <p>Manutenções e serviços contratados pela unidade.</p>
            </div>
            <a href="<?= BASE_URL ?>produtos" class="btn-sm secondary" style="text-decoration:none;">
                <i class="fa-solid fa-arrow-left"></i> Voltar
            </a>
        </header>

        <section class="content-wrapper-centered">
            <div class="form-card-centered">
                <form action="<?= BASE_URL ?><?= $editando ? 'servicos/atualizar' : 'servicos/processa' ?>" method="POST" class="custom-form">
                    <?php if ($editando): ?>
                    <input type="hidden" name="id" value="<?= (int) $servico['id'] ?>">
                    <?php endif; ?>

                    <div class="form-group">
                        <label><i class="fa-solid fa-wrench"></i> Nome do Serviço</label>
                        <input type="text" name="nome" placeholder="Ex: Manutenção do parquinho" required
                               value="<?= htmlspecialchars($servico['nome'] ?? '') ?>">
                    </div>

                    <div class="form-group">
                        <label><i class="fa-solid fa-align-left"></i> Descrição</label>
                        <textarea name="descricao" rows="2" placeholder="O que será feito..."><?= htmlspecialchars($servico['descricao'] ?? '') ?></textarea>
                    </div>

                    <div class="form-group">
                        <label><i class="fa-solid fa-dollar-sign"></i> Preço Estimado</label>
                        <input type="number" step="0.01" min="0" name="preco" placeholder="0.00" required
                               value="<?= htmlspecialchars($servico['preco'] ?? '') ?>">
                    </div>

                    <button type="submit" class="btn-finalizar">
                        <i class="fa-solid fa-check"></i> <?= $editando ? 'Salvar Alterações' : 'Cadastrar Serviço' ?>
                    </button>
                </form>
            </div>
        </section>
    </main>
</div>
</body>
</html>
