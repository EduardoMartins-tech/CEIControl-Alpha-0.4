<?php
// Envio feito pelo chat em tempo real (fetch): responde só com o código HTTP,
// sem redirecionar, para o JavaScript saber se a mensagem foi gravada.
$via_fetch = ($_SERVER['HTTP_X_REQUESTED_WITH'] ?? '') === 'fetch';

if (!isset($_SESSION['usuario_id'])) {
    // Sem isso, o fetch seguiria o redirecionamento para o login e
    // receberia 200, como se a mensagem tivesse sido enviada.
    if ($via_fetch) {
        http_response_code(401);
        exit;
    }
    header("Location: " . BASE_URL . "login");
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../app/models/MensagemModel.php';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $destinatario_id = intval($_POST['destinatario_id'] ?? 0);
    $mensagem        = trim($_POST['mensagem'] ?? '');
    $remetente_id    = $_SESSION['usuario_id'];

    $model   = new MensagemModel($conn);
    $contato = $model->buscarContatoPermitido($remetente_id, $_SESSION['perfil'], $destinatario_id);

    if (!$contato) {
        http_response_code(403);
        if ($via_fetch) exit;
        header("Location: " . BASE_URL . "comunicacao");
        exit;
    }

    if ($mensagem !== '' && !$model->enviar($remetente_id, $destinatario_id, $mensagem)) {
        // Falha ao gravar no banco: o chat mantém o texto no campo e avisa o usuário
        http_response_code(500);
        if ($via_fetch) exit;
        header("Location: " . BASE_URL . "comunicacao?id_contato=$destinatario_id&erro=envio");
        exit;
    }

    if ($via_fetch) {
        http_response_code(204);
        exit;
    }
    header("Location: " . BASE_URL . "comunicacao?id_contato=$destinatario_id");
    exit;
}

header("Location: " . BASE_URL . "comunicacao");
exit;
?>
