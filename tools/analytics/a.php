<?php
// Funnel beacon endpoint (plan.md M24). Appends one line per event to log/
// (denied to the web by log/.htaccess; fetched over FTPS by tools/funnel.py).
// Anonymous by design: no IP, no user agent, no cookies; only the sent line is kept.
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    http_response_code(405);
    exit;
}
$body = file_get_contents('php://input', false, null, 0, 200);
$re = '/^1 [0-9a-f]{8} [0-9A-Za-z.+-]{1,48} (cg|web) (mobile|desktop) \d{1,3} [a-z0-9_]{1,12} \d{1,6}\.\d$/';
if (!is_string($body) || !preg_match($re, $body)) {
    http_response_code(400);
    exit;
}
if (!is_dir(__DIR__ . '/log')) {
    @mkdir(__DIR__ . '/log');
}
$file = __DIR__ . '/log/events-' . gmdate('Y-m-d') . '.log';
if (!is_file($file) || filesize($file) < 5000000) {
    @file_put_contents($file, gmdate('Y-m-d\TH:i:s\Z') . ' ' . $body . "\n", FILE_APPEND | LOCK_EX);
}
http_response_code(204);
