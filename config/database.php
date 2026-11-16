<?php

$host = getenv('MYSQLHOST');
$user = getenv('MYSQLUSER');
$pass = getenv('MYSQLPASSWORD');
$db   = getenv('MYSQLDATABASE');
$port = (int) getenv('MYSQLPORT');

mysqli_report(MYSQLI_REPORT_OFF);
$conn = new mysqli($host, $user, $pass, $db, $port);

if ($conn->connect_error) {
    die("Falha na conexão com o banco do Railway: " . $conn->connect_error);
}

// O MySQL do Railway roda em UTC. Sem isto o chat mostrava as mensagens 3 horas
// adiantadas e CURDATE() virava o dia às 21h. Os TIMESTAMP continuam guardados em
// UTC; só a leitura e o NOW()/CURDATE() passam a usar o horário de Brasília
// (sem horário de verão desde 2019, por isso o deslocamento fixo).
$conn->query("SET time_zone = '-03:00'");

?>
