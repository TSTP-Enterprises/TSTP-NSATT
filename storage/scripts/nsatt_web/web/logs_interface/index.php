<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Network Logs</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body>
    <div class="container">
        <h1>Network Logs</h1>
        <div class="controls">
            <button onclick="fetchLogs()">Refresh</button>
            <button onclick="deleteAllLogs()">Delete All Logs</button>
        </div>
        <div class="log-container" id="logContainer">
            Loading logs...
        </div>
    </div>

    <script src="assets/scripts.js"></script>
</body>
</html>
