<?php
$pdo = new PDO('pgsql:host=webmarkdb dbname=postgres', 'postgres', 'webmark', array(
    PDO::ATTR_PERSISTENT => true
));
$arr = $pdo->query('select id, message from fortunes limit 10')->fetchAll();
echo json_encode($arr);
$pdo = null;
