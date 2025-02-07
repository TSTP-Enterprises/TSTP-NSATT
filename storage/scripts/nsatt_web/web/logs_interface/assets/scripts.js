async function fetchLogs() {
    try {
        const response = await fetch('fetch_logs.php');
        const data = await response.json();
        if (data.error) {
            document.getElementById('logContainer').innerText = data.error;
        } else {
            document.getElementById('logContainer').innerText = data.logs.join('\n');
        }
    } catch (error) {
        document.getElementById('logContainer').innerText = 'Error fetching logs.';
    }
}

async function deleteAllLogs() {
    if (!confirm("Are you sure you want to delete all logs?")) return;
    try {
        const response = await fetch('delete_logs.php', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ action: 'delete_all' })
        });
        const data = await response.json();
        if (data.error) {
            alert("Error: " + data.error);
        } else {
            alert(data.status);
            fetchLogs();
        }
    } catch (error) {
        alert("Error deleting logs.");
    }
}

// Initial fetch
fetchLogs();

// Auto-refresh logs every 10 seconds without reloading the page
setInterval(fetchLogs, 10000);
