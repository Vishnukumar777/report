"""
Flask CI/CD Demo Application
A simple web application to demonstrate CI/CD pipeline with Docker and Kubernetes
"""

from flask import Flask, jsonify, render_template_string
import os
import socket
from datetime import datetime

app = Flask(__name__)

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CI/CD Demo App</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            width: 100%;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        .info-card {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 15px;
        }
        .info-card h3 {
            color: #764ba2;
            margin-bottom: 10px;
        }
        .info-card p {
            color: #555;
            font-family: monospace;
            font-size: 0.95em;
        }
        .status {
            display: inline-block;
            background: #28a745;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-top: 20px;
        }
        .endpoints {
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #eee;
        }
        .endpoints h3 {
            color: #333;
            margin-bottom: 15px;
        }
        .endpoint {
            background: #e9ecef;
            padding: 10px 15px;
            border-radius: 5px;
            margin-bottom: 10px;
            font-family: monospace;
        }
        .endpoint span {
            color: #667eea;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 CI/CD Demo App</h1>
        <p class="subtitle">Deployed via GitHub Actions & Docker</p>
        
        <div class="info-card">
            <h3>📦 Container Info</h3>
            <p><strong>Hostname:</strong> {{ hostname }}</p>
            <p><strong>Version:</strong> {{ version }}</p>
        </div>
        
        <div class="info-card">
            <h3>🕐 Runtime Info</h3>
            <p><strong>Current Time:</strong> {{ current_time }}</p>
            <p><strong>Environment:</strong> {{ environment }}</p>
        </div>
        
        <span class="status">✅ Running</span>
        
        <div class="endpoints">
            <h3>Available Endpoints</h3>
            <div class="endpoint"><span>GET</span> / - This page</div>
            <div class="endpoint"><span>GET</span> /health - Health check</div>
            <div class="endpoint"><span>GET</span> /api/info - JSON info</div>
        </div>
    </div>
</body>
</html>
"""


def get_app_info():
    """Get application runtime information"""
    return {
        "hostname": socket.gethostname(),
        "version": os.environ.get("APP_VERSION", "1.0.0"),
        "environment": os.environ.get("ENVIRONMENT", "development"),
        "current_time": datetime.utcnow().isoformat()
    }


@app.route("/")
def home():
    """Home page with application info"""
    info = get_app_info()
    return render_template_string(HTML_TEMPLATE, **info)


@app.route("/health")
def health():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat()
    }), 200


@app.route("/api/info")
def api_info():
    """API endpoint returning application info as JSON"""
    info = get_app_info()
    info["status"] = "running"
    return jsonify(info), 200


@app.route("/ready")
def ready():
    """Readiness probe endpoint"""
    return jsonify({"ready": True}), 200


def add(a: int, b: int) -> int:
    """Simple add function for testing"""
    return a + b


def multiply(a: int, b: int) -> int:
    """Simple multiply function for testing"""
    return a * b


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    debug = os.environ.get("FLASK_DEBUG", "false").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)
