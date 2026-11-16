<?php
// Logout seguro: apaga os dados da sessão, expira o cookie no navegador
// e destrói a sessão no servidor.
$_SESSION = [];

if (ini_get('session.use_cookies')) {
    $p = session_get_cookie_params();
    setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
}

session_destroy();
header("Cache-Control: no-store");
header("Location: " . BASE_URL . "login");
exit;
?>
