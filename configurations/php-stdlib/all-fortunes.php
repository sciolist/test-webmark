<?php
$pdo = new PDO('pgsql:host=webmarkdb dbname=postgres', 'postgres', 'webmark', array(
    PDO::ATTR_PERSISTENT => true
));
$arr = $pdo->query('select id, message from fortunes')->fetchAll();
echo json_encode($arr);
$pdo = null;
