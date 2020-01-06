<?php
$pdo = new PDO('pgsql:host=' . getenv('PGHOST') . ' dbname=' . getenv('PGDATABASE'), getenv('PGUSER'), getenv('PGPASSWORD'), array(
    PDO::ATTR_PERSISTENT => true
));
$arr = $pdo->query('select id, message from fortunes limit 10')->fetchAll();
echo json_encode($arr);
$pdo = null;
