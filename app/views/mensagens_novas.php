<?php
// Endpoint JSON do chat em tempo real: mensagens da conversa com id maior que "depois"
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

if (!isset($_SESSION['usuario_id'])) {
    http_response_code(401);
    echo '[]';
    exit;
}

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../app/models/MensagemModel.php';

$meu_id     = (int) $_SESSION['usuario_id'];
$id_contato = intval($_GET['id_contato'] ?? 0);
$depois     = intval($_GET['depois'] ?? 0);

$model = new MensagemModel($conn);
if (!$model->buscarContatoPermitido($meu_id, $_SESSION['perfil'], $id_contato)) {
    http_response_code(403);
    echo '[]';
    exit;
}

$saida = [];
foreach ($model->buscarNovas($meu_id, $id_contato, $depois) as $m) {
    $saida[] = [
        'id'       => (int) $m['id'],
        'mensagem' => $m['mensagem'],
        'hora'     => date('H:i', strtotime($m['data_envio'])),
        'enviada'  => ((int) $m['remetente_id'] === $meu_id),
    ];
}
echo json_encode($saida, JSON_UNESCAPED_UNICODE);
