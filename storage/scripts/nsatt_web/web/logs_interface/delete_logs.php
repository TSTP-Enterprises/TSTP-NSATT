<?php
header('Content-Type: application/json');

// Path to the SQLite3 database
$db_file = '/home/nsatt-admin/nsatt/logs/networking/logs.db';

// Check if the database exists
if (!file_exists($db_file)) {
    echo json_encode(['error' => 'Log database does not exist.']);
    exit;
}

// Get the action from POST data
$data = json_decode(file_get_contents('php://input'), true);
$action = isset($data['action']) ? $data['action'] : '';

try {
    $db = new SQLite3($db_file);

    if ($action === 'delete_all') {
        $db->exec("DELETE FROM logs");
        echo json_encode(['status' => 'All logs deleted successfully.']);
    } elseif ($action === 'delete_specific') {
        $lines = isset($data['lines']) ? $data['lines'] : [];
        if (!is_array($lines)) {
            echo json_encode(['error' => 'Invalid lines format.']);
            exit;
        }
        foreach ($lines as $line_id) {
            $stmt = $db->prepare("DELETE FROM logs WHERE id = :id");
            $stmt->bindValue(':id', $line_id, SQLITE3_INTEGER);
            $stmt->execute();
        }
        echo json_encode(['status' => 'Specified logs deleted successfully.']);
    } else {
        echo json_encode(['error' => 'Invalid action.']);
    }
} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>
