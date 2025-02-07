<?php
header('Content-Type: application/json');

// Path to the SQLite3 database
$db_file = '/home/nsatt-admin/nsatt/logs/networking/logs.db';

// Check if the database exists
if (!file_exists($db_file)) {
    echo json_encode(['error' => 'Log database does not exist.']);
    exit;
}

try {
    $db = new SQLite3($db_file);
    $results = $db->query("SELECT * FROM logs ORDER BY id DESC LIMIT 100");
    $logs = [];
    while ($row = $results->fetchArray(SQLITE3_ASSOC)) {
        $logs[] = "[{$row['timestamp']}] [{$row['log_level']}] {$row['message']}";
    }
    echo json_encode(['logs' => array_reverse($logs)]);
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>
