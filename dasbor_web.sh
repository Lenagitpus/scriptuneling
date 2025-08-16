#!/bin/bash
# Web Dashboard for VPS Manager
# Version: HAPPY NEW YEAR 2025

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
CONFIG_DIR="/etc/vps_manager"
DASHBOARD_DIR="$CONFIG_DIR/dashboard"
DASHBOARD_PORT=8888
DASHBOARD_USER="admin"
DASHBOARD_PASS=$(cat "$CONFIG_DIR/dashboard_pass" 2>/dev/null || echo "admin")
DASHBOARD_LOG="/var/log/vps_manager/dashboard.log"

# Ensure directories exist
mkdir -p $DASHBOARD_DIR
mkdir -p /var/log/vps_manager

# Function to log messages
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $DASHBOARD_LOG
    echo -e "$1"
}

# Function to install required packages
install_dashboard_deps() {
    log_message "${YELLOW}Installing dashboard dependencies...${NC}"
    
    # Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log_message "${YELLOW}Installing Node.js...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi
    
    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        log_message "${YELLOW}Installing npm...${NC}"
        apt-get install -y npm
    fi
    
    # Install required npm packages
    log_message "${YELLOW}Installing required npm packages...${NC}"
    npm install -g express express-session body-parser ejs socket.io axios chart.js
    
    log_message "${GREEN}Dashboard dependencies installed successfully.${NC}"
}

# Function to create dashboard files
create_dashboard_files() {
    log_message "${YELLOW}Creating dashboard files...${NC}"
    
    # Create main server file
    cat > "$DASHBOARD_DIR/server.js" << 'EOF'
const express = require('express');
const session = require('express-session');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const http = require('http');
const socketIo = require('socket.io');
const os = require('os');

const app = express();
const server = http.createServer(app);
const io = socketIo(server);

// Configuration
const PORT = process.env.PORT || 8888;
const CONFIG_DIR = '/etc/vps_manager';
const SESSION_SECRET = fs.existsSync(`${CONFIG_DIR}/session_secret`) 
    ? fs.readFileSync(`${CONFIG_DIR}/session_secret`, 'utf8').trim() 
    : 'vps_manager_secret_key';

// Middleware
app.use(session({
    secret: SESSION_SECRET,
    resave: false,
    saveUninitialized: true,
    cookie: { secure: false } // Set to true if using HTTPS
}));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Authentication middleware
const authenticate = (req, res, next) => {
    if (req.session.authenticated) {
        next();
    } else {
        res.redirect('/login');
    }
};

// Routes
app.get('/login', (req, res) => {
    res.render('login');
});

app.post('/login', (req, res) => {
    const { username, password } = req.body;
    
    // Read credentials from config
    let dashboardUser = 'admin';
    let dashboardPass = 'admin';
    
    try {
        if (fs.existsSync(`${CONFIG_DIR}/dashboard_user`)) {
            dashboardUser = fs.readFileSync(`${CONFIG_DIR}/dashboard_user`, 'utf8').trim();
        }
        if (fs.existsSync(`${CONFIG_DIR}/dashboard_pass`)) {
            dashboardPass = fs.readFileSync(`${CONFIG_DIR}/dashboard_pass`, 'utf8').trim();
        }
    } catch (err) {
        console.error('Error reading credentials:', err);
    }
    
    if (username === dashboardUser && password === dashboardPass) {
        req.session.authenticated = true;
        res.redirect('/');
    } else {
        res.render('login', { error: 'Invalid credentials' });
    }
});

app.get('/logout', (req, res) => {
    req.session.destroy();
    res.redirect('/login');
});

app.get('/', authenticate, (req, res) => {
    res.render('dashboard');
});

app.get('/accounts', authenticate, (req, res) => {
    res.render('accounts');
});

app.get('/bandwidth', authenticate, (req, res) => {
    res.render('bandwidth');
});

app.get('/settings', authenticate, (req, res) => {
    res.render('settings');
});

app.get('/logs', authenticate, (req, res) => {
    res.render('logs');
});

// API endpoints
app.get('/api/system-info', authenticate, (req, res) => {
    exec('bash -c "source /usr/local/bin/vps_manager && get_system_info"', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        try {
            const lines = stdout.trim().split('\n');
            const systemInfo = {};
            
            lines.forEach(line => {
                const [key, value] = line.split(':').map(item => item.trim());
                systemInfo[key] = value;
            });
            
            res.json(systemInfo);
        } catch (err) {
            res.status(500).json({ error: 'Failed to parse system info' });
        }
    });
});

app.get('/api/accounts/:type', authenticate, (req, res) => {
    const { type } = req.params;
    const validTypes = ['ssh', 'vmess', 'vless', 'trojan', 'noobzvpn', 'ss'];
    
    if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid account type' });
    }
    
    exec(`bash -c "source /usr/local/bin/vps_manager && list_${type}_members"`, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        try {
            const lines = stdout.trim().split('\n');
            const accounts = [];
            
            // Skip header lines
            for (let i = 2; i < lines.length; i++) {
                const fields = lines[i].split(/\s+/);
                if (fields.length >= 4) {
                    accounts.push({
                        username: fields[0],
                        password: fields[1],
                        created: fields[2],
                        expires: fields[3]
                    });
                }
            }
            
            res.json(accounts);
        } catch (err) {
            res.status(500).json({ error: 'Failed to parse account info' });
        }
    });
});

app.post('/api/accounts/:type', authenticate, (req, res) => {
    const { type } = req.params;
    const { username, password, days } = req.body;
    const validTypes = ['ssh', 'vmess', 'vless', 'trojan', 'noobzvpn', 'ss'];
    
    if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid account type' });
    }
    
    if (!username || !password || !days) {
        return res.status(400).json({ error: 'Missing required fields' });
    }
    
    exec(`bash -c "source /usr/local/bin/vps_manager && create_${type}_account ${username} ${password} ${days}"`, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        res.json({ success: true, message: `${type.toUpperCase()} account created successfully` });
    });
});

app.delete('/api/accounts/:type/:username', authenticate, (req, res) => {
    const { type, username } = req.params;
    const validTypes = ['ssh', 'vmess', 'vless', 'trojan', 'noobzvpn', 'ss'];
    
    if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid account type' });
    }
    
    exec(`bash -c "source /usr/local/bin/vps_manager && delete_${type}_account ${username}"`, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        res.json({ success: true, message: `${type.toUpperCase()} account deleted successfully` });
    });
});

app.get('/api/bandwidth', authenticate, (req, res) => {
    exec('bash -c "/usr/local/bin/bandwidth_monitor.sh usage"', (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        try {
            const lines = stdout.trim().split('\n');
            const bandwidth = [];
            
            // Skip header lines
            for (let i = 2; i < lines.length; i++) {
                const fields = lines[i].split(/\s+/);
                if (fields.length >= 4) {
                    bandwidth.push({
                        username: fields[0],
                        usage: fields[1],
                        limit: fields[2],
                        status: fields[3]
                    });
                }
            }
            
            res.json(bandwidth);
        } catch (err) {
            res.status(500).json({ error: 'Failed to parse bandwidth info' });
        }
    });
});

app.get('/api/logs/:type', authenticate, (req, res) => {
    const { type } = req.params;
    const validTypes = ['system', 'ssh', 'bandwidth', 'dashboard'];
    
    if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid log type' });
    }
    
    let logFile = '';
    
    switch (type) {
        case 'system':
            logFile = '/var/log/syslog';
            break;
        case 'ssh':
            logFile = '/var/log/auth.log';
            break;
        case 'bandwidth':
            logFile = '/var/log/vps_manager/bandwidth.log';
            break;
        case 'dashboard':
            logFile = '/var/log/vps_manager/dashboard.log';
            break;
    }
    
    exec(`tail -n 100 ${logFile}`, (error, stdout, stderr) => {
        if (error) {
            return res.status(500).json({ error: error.message });
        }
        
        res.json({ logs: stdout });
    });
});

// Real-time monitoring with Socket.IO
io.on('connection', (socket) => {
    console.log('Client connected');
    
    // Send system stats every 5 seconds
    const statsInterval = setInterval(() => {
        const cpuUsage = os.loadavg()[0];
        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const memUsage = ((totalMem - freeMem) / totalMem * 100).toFixed(2);
        
        socket.emit('system-stats', {
            cpu: cpuUsage.toFixed(2),
            memory: memUsage,
            uptime: os.uptime()
        });
    }, 5000);
    
    socket.on('disconnect', () => {
        clearInterval(statsInterval);
        console.log('Client disconnected');
    });
});

// Start server
server.listen(PORT, () => {
    console.log(`Dashboard server running on port ${PORT}`);
});
EOF
    
    # Create directory structure
    mkdir -p "$DASHBOARD_DIR/views"
    mkdir -p "$DASHBOARD_DIR/public/css"
    mkdir -p "$DASHBOARD_DIR/public/js"
    
    # Create login view
    cat > "$DASHBOARD_DIR/views/login.ejs" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Manager - Login</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body class="login-page">
    <div class="container">
        <div class="row justify-content-center">
            <div class="col-md-6 col-lg-4">
                <div class="login-card">
                    <div class="text-center mb-4">
                        <h2>VPS Manager</h2>
                        <p>Web Dashboard</p>
                    </div>
                    
                    <% if (typeof error !== 'undefined') { %>
                        <div class="alert alert-danger" role="alert">
                            <%= error %>
                        </div>
                    <% } %>
                    
                    <form action="/login" method="POST">
                        <div class="mb-3">
                            <label for="username" class="form-label">Username</label>
                            <input type="text" class="form-control" id="username" name="username" required>
                        </div>
                        <div class="mb-3">
                            <label for="password" class="form-label">Password</label>
                            <input type="password" class="form-control" id="password" name="password" required>
                        </div>
                        <div class="d-grid">
                            <button type="submit" class="btn btn-primary">Login</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
EOF
    
    # Create dashboard view
    cat > "$DASHBOARD_DIR/views/dashboard.ejs" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Manager - Dashboard</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <%- include('partials/navbar') %>
    
    <div class="container-fluid">
        <div class="row">
            <%- include('partials/sidebar') %>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Dashboard</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button type="button" class="btn btn-sm btn-outline-secondary" id="refreshBtn">
                            <i class="bi bi-arrow-clockwise"></i> Refresh
                        </button>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-md-4 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">CPU Usage</h5>
                                <div class="progress mb-2">
                                    <div id="cpuProgress" class="progress-bar" role="progressbar" style="width: 0%;" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">0%</div>
                                </div>
                                <p id="cpuInfo" class="card-text">Loading...</p>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-4 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Memory Usage</h5>
                                <div class="progress mb-2">
                                    <div id="memoryProgress" class="progress-bar" role="progressbar" style="width: 0%;" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100">0%</div>
                                </div>
                                <p id="memoryInfo" class="card-text">Loading...</p>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-4 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Uptime</h5>
                                <p id="uptimeInfo" class="card-text">Loading...</p>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">System Information</h5>
                                <table class="table">
                                    <tbody id="systemInfoTable">
                                        <tr><td>Loading...</td></tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Account Summary</h5>
                                <table class="table">
                                    <thead>
                                        <tr>
                                            <th>Account Type</th>
                                            <th>Total</th>
                                            <th>Active</th>
                                        </tr>
                                    </thead>
                                    <tbody id="accountSummaryTable">
                                        <tr><td colspan="3">Loading...</td></tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-12 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Resource Usage History</h5>
                                <canvas id="resourceChart"></canvas>
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="/socket.io/socket.io.js"></script>
    <script src="/js/dashboard.js"></script>
</body>
</html>
EOF
    
    # Create accounts view
    cat > "$DASHBOARD_DIR/views/accounts.ejs" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Manager - Accounts</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <%- include('partials/navbar') %>
    
    <div class="container-fluid">
        <div class="row">
            <%- include('partials/sidebar') %>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Account Management</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button type="button" class="btn btn-sm btn-primary" data-bs-toggle="modal" data-bs-target="#createAccountModal">
                            <i class="bi bi-plus-lg"></i> Create Account
                        </button>
                    </div>
                </div>
                
                <ul class="nav nav-tabs" id="accountTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="ssh-tab" data-bs-toggle="tab" data-bs-target="#ssh" type="button" role="tab" aria-controls="ssh" aria-selected="true">SSH</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="vmess-tab" data-bs-toggle="tab" data-bs-target="#vmess" type="button" role="tab" aria-controls="vmess" aria-selected="false">VMESS</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="vless-tab" data-bs-toggle="tab" data-bs-target="#vless" type="button" role="tab" aria-controls="vless" aria-selected="false">VLESS</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="trojan-tab" data-bs-toggle="tab" data-bs-target="#trojan" type="button" role="tab" aria-controls="trojan" aria-selected="false">TROJAN</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="noobzvpn-tab" data-bs-toggle="tab" data-bs-target="#noobzvpn" type="button" role="tab" aria-controls="noobzvpn" aria-selected="false">NOOBZVPN</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="ss-tab" data-bs-toggle="tab" data-bs-target="#ss" type="button" role="tab" aria-controls="ss" aria-selected="false">Shadowsocks</button>
                    </li>
                </ul>
                
                <div class="tab-content" id="accountTabsContent">
                    <div class="tab-pane fade show active" id="ssh" role="tabpanel" aria-labelledby="ssh-tab">
                        <div class="table-responsive mt-3">
                            <table class="table table-striped table-sm">
                                <thead>
                                    <tr>
                                        <th>Username</th>
                                        <th>Password</th>
                                        <th>Created</th>
                                        <th>Expires</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="sshAccountsTable">
                                    <tr><td colspan="5">Loading...</td></tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="vmess" role="tabpanel" aria-labelledby="vmess-tab">
                        <div class="table-responsive mt-3">
                            <table class="table table-striped table-sm">
                                <thead>
                                    <tr>
                                        <th>Username</th>
                                        <th>Password</th>
                                        <th>Created</th>
                                        <th>Expires</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="vmessAccountsTable">
                                    <tr><td colspan="5">Loading...</td></tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                    
                    <!-- Similar structure for other account types -->
                    <div class="tab-pane fade" id="vless" role="tabpanel" aria-labelledby="vless-tab">
                        <div class="table-responsive mt-3">
                            <table class="table table-striped table-sm">
                                <thead>
                                    <tr>
                                        <th>Username</th>
                                        <th>Password</th>
                                        <th>Created</th>
                                        <th>Expires</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="vlessAccountsTable">
                                    <tr><td colspan="5">Loading...</td></tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="trojan" role="tabpanel" aria-labelledby="trojan-tab">
                        <!-- Similar table structure -->
                    </div>
                    
                    <div class="tab-pane fade" id="noobzvpn" role="tabpanel" aria-labelledby="noobzvpn-tab">
                        <!-- Similar table structure -->
                    </div>
                    
                    <div class="tab-pane fade" id="ss" role="tabpanel" aria-labelledby="ss-tab">
                        <!-- Similar table structure -->
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <!-- Create Account Modal -->
    <div class="modal fade" id="createAccountModal" tabindex="-1" aria-labelledby="createAccountModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="createAccountModalLabel">Create New Account</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <form id="createAccountForm">
                        <div class="mb-3">
                            <label for="accountType" class="form-label">Account Type</label>
                            <select class="form-select" id="accountType" required>
                                <option value="ssh">SSH</option>
                                <option value="vmess">VMESS</option>
                                <option value="vless">VLESS</option>
                                <option value="trojan">TROJAN</option>
                                <option value="noobzvpn">NOOBZVPN</option>
                                <option value="ss">Shadowsocks</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label for="username" class="form-label">Username</label>
                            <input type="text" class="form-control" id="username" required>
                        </div>
                        <div class="mb-3">
                            <label for="password" class="form-label">Password</label>
                            <input type="text" class="form-control" id="password" required>
                        </div>
                        <div class="mb-3">
                            <label for="days" class="form-label">Duration (days)</label>
                            <input type="number" class="form-control" id="days" min="1" value="30" required>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" id="createAccountBtn">Create</button>
                </div>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/js/accounts.js"></script>
</body>
</html>
EOF
    
    # Create bandwidth view
    cat > "$DASHBOARD_DIR/views/bandwidth.ejs" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Manager - Bandwidth</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <%- include('partials/navbar') %>
    
    <div class="container-fluid">
        <div class="row">
            <%- include('partials/sidebar') %>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Bandwidth Management</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button type="button" class="btn btn-sm btn-outline-secondary me-2" id="refreshBandwidthBtn">
                            <i class="bi bi-arrow-clockwise"></i> Refresh
                        </button>
                        <button type="button" class="btn btn-sm btn-outline-primary" data-bs-toggle="modal" data-bs-target="#setBandwidthLimitModal">
                            <i class="bi bi-sliders"></i> Set Limit
                        </button>
                    </div>
                </div>
                
                <div class="row mb-4">
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Bandwidth Usage Overview</h5>
                                <canvas id="bandwidthChart"></canvas>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Top Users</h5>
                                <div class="table-responsive">
                                    <table class="table table-sm">
                                        <thead>
                                            <tr>
                                                <th>Username</th>
                                                <th>Usage (GB)</th>
                                                <th>% of Total</th>
                                            </tr>
                                        </thead>
                                        <tbody id="topUsersTable">
                                            <tr><td colspan="3">Loading...</td></tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="card mb-4">
                    <div class="card-body">
                        <h5 class="card-title">Bandwidth Usage Details</h5>
                        <div class="table-responsive">
                            <table class="table table-striped table-sm">
                                <thead>
                                    <tr>
                                        <th>Username</th>
                                        <th>Usage (GB)</th>
                                        <th>Limit (GB)</th>
                                        <th>Status</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody id="bandwidthTable">
                                    <tr><td colspan="5">Loading...</td></tr>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <!-- Set Bandwidth Limit Modal -->
    <div class="modal fade" id="setBandwidthLimitModal" tabindex="-1" aria-labelledby="setBandwidthLimitModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="setBandwidthLimitModalLabel">Set Bandwidth Limit</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body">
                    <form id="setBandwidthLimitForm">
                        <div class="mb-3">
                            <label for="limitUsername" class="form-label">Username</label>
                            <select class="form-select" id="limitUsername" required>
                                <option value="">Loading users...</option>
                            </select>
                        </div>
                        <div class="mb-3">
                            <label for="limitValue" class="form-label">Bandwidth Limit (GB)</label>
                            <input type="number" class="form-control" id="limitValue" min="0" step="0.1" required>
                            <div class="form-text">Enter 0 for unlimited bandwidth.</div>
                        </div>
                    </form>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="button" class="btn btn-primary" id="setBandwidthLimitBtn">Set Limit</button>
                </div>
            </div>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="/js/bandwidth.js"></script>
</body>
</html>
EOF
    
    # Create settings view
    cat > "$DASHBOARD_DIR/views/settings.ejs" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Manager - Settings</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <%- include('partials/navbar') %>
    
    <div class="container-fluid">
        <div class="row">
            <%- include('partials/sidebar') %>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Settings</h1>
                </div>
                
                <div class="row">
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Dashboard Settings</h5>
                                <form id="dashboardSettingsForm">
                                    <div class="mb-3">
                                        <label for="dashboardUsername" class="form-label">Dashboard Username</label>
                                        <input type="text" class="form-control" id="dashboardUsername" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="dashboardPassword" class="form-label">Dashboard Password</label>
                                        <input type="password" class="form-control" id="dashboardPassword" required>
                                    </div>
                                    <div class="mb-3">
                                        <label for="dashboardPort" class="form-label">Dashboard Port</label>
                                        <input type="number" class="form-control" id="dashboardPort" min="1024" max="65535" required>
                                    </div>
                                    <button type="submit" class="btn btn-primary">Save Dashboard Settings</button>
                                </form>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Domain Settings</h5>
                                <form id="domainSettingsForm">
                                    <div class="mb-3">
                                        <label for="domainName" class="form-label">Domain Name</label>
                                        <input type="text" class="form-control" id="domainName" required>
                                    </div>
                                    <button type="submit" class="btn btn-primary">Update Domain</button>
                                </form>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div class="row">
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">Backup Settings</h5>
                                <form id="backupSettingsForm">
                                    <div class="mb-3">
                                        <label for="backupSchedule" class="form-label">Backup Schedule</label>
                                        <select class="form-select" id="backupSchedule" required>
                                            <option value="daily">Daily</option>
                                            <option value="weekly">Weekly</option>
                                            <option value="monthly">Monthly</option>
                                            <option value="disabled">Disabled</option>
                                        </select>
                                    </div>
                                    <button type="submit" class="btn btn-primary">Save Backup Settings</button>
                                </form>
                                <hr>
                                <button id="backupNowBtn" class="btn btn-secondary">Backup Now</button>
                                <button id="restoreBackupBtn" class="btn btn-warning ms-2">Restore Backup</button>
                            </div>
                        </div>
                    </div>
                    
                    <div class="col-md-6 mb-4">
                        <div class="card">
                            <div class="card-body">
                                <h5 class="card-title">System Actions</h5>
                                <div class="d-grid gap-2">
                                    <button id="restartServicesBtn" class="btn btn-info">Restart All Services</button>
                                    <button id="updateSystemBtn" class="btn btn-success">Update System Packages</button>
                                    <button id="updateScriptBtn" class="btn btn-primary">Update VPS Manager Script</button>
                                    <button id="rebootSystemBtn" class="btn btn-danger">Reboot System</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/js/settings.js"></script>
</body>
</html>
EOF
    
    # Create logs view
    cat > "$DASHBOARD_DIR/views/logs.ejs" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Manager - Logs</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="/css/style.css">
</head>
<body>
    <%- include('partials/navbar') %>
    
    <div class="container-fluid">
        <div class="row">
            <%- include('partials/sidebar') %>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">System Logs</h1>
                    <div class="btn-toolbar mb-2 mb-md-0">
                        <button type="button" class="btn btn-sm btn-outline-secondary" id="refreshLogsBtn">
                            <i class="bi bi-arrow-clockwise"></i> Refresh
                        </button>
                    </div>
                </div>
                
                <ul class="nav nav-tabs" id="logTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="system-tab" data-bs-toggle="tab" data-bs-target="#system" type="button" role="tab" aria-controls="system" aria-selected="true">System</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="ssh-tab" data-bs-toggle="tab" data-bs-target="#ssh" type="button" role="tab" aria-controls="ssh" aria-selected="false">SSH</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="bandwidth-tab" data-bs-toggle="tab" data-bs-target="#bandwidth" type="button" role="tab" aria-controls="bandwidth" aria-selected="false">Bandwidth</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="dashboard-tab" data-bs-toggle="tab" data-bs-target="#dashboard" type="button" role="tab" aria-controls="dashboard" aria-selected="false">Dashboard</button>
                    </li>
                </ul>
                
                <div class="tab-content" id="logTabsContent">
                    <div class="tab-pane fade show active" id="system" role="tabpanel" aria-labelledby="system-tab">
                        <div class="card mt-3">
                            <div class="card-body">
                                <pre id="systemLogs" class="logs-container">Loading...</pre>
                            </div>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="ssh" role="tabpanel" aria-labelledby="ssh-tab">
                        <div class="card mt-3">
                            <div class="card-body">
                                <pre id="sshLogs" class="logs-container">Loading...</pre>
                            </div>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="bandwidth" role="tabpanel" aria-labelledby="bandwidth-tab">
                        <div class="card mt-3">
                            <div class="card-body">
                                <pre id="bandwidthLogs" class="logs-container">Loading...</pre>
                            </div>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="dashboard" role="tabpanel" aria-labelledby="dashboard-tab">
                        <div class="card mt-3">
                            <div class="card-body">
                                <pre id="dashboardLogs" class="logs-container">Loading...</pre>
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="/js/logs.js"></script>
</body>
</html>
EOF
    
    # Create navbar partial
    mkdir -p "$DASHBOARD_DIR/views/partials"
    cat > "$DASHBOARD_DIR/views/partials/navbar.ejs" << 'EOF'
<header class="navbar navbar-dark sticky-top bg-dark flex-md-nowrap p-0 shadow">
    <a class="navbar-brand col-md-3 col-lg-2 me-0 px-3" href="/">VPS Manager</a>
    <button class="navbar-toggler position-absolute d-md-none collapsed" type="button" data-bs-toggle="collapse" data-bs-target="#sidebarMenu" aria-controls="sidebarMenu" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
    </button>
    <div class="navbar-nav">
        <div class="nav-item text-nowrap">
            <a class="nav-link px-3" href="/logout">Sign out</a>
        </div>
    </div>
</header>
EOF
    
    # Create sidebar partial
    cat > "$DASHBOARD_DIR/views/partials/sidebar.ejs" << 'EOF'
<nav id="sidebarMenu" class="col-md-3 col-lg-2 d-md-block bg-light sidebar collapse">
    <div class="position-sticky pt-3">
        <ul class="nav flex-column">
            <li class="nav-item">
                <a class="nav-link <%= (typeof active !== 'undefined' && active === 'dashboard') ? 'active' : '' %>" href="/">
                    <i class="bi bi-speedometer2"></i> Dashboard
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link <%= (typeof active !== 'undefined' && active === 'accounts') ? 'active' : '' %>" href="/accounts">
                    <i class="bi bi-people"></i> Accounts
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link <%= (typeof active !== 'undefined' && active === 'bandwidth') ? 'active' : '' %>" href="/bandwidth">
                    <i class="bi bi-graph-up"></i> Bandwidth
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link <%= (typeof active !== 'undefined' && active === 'logs') ? 'active' : '' %>" href="/logs">
                    <i class="bi bi-journal-text"></i> Logs
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link <%= (typeof active !== 'undefined' && active === 'settings') ? 'active' : '' %>" href="/settings">
                    <i class="bi bi-gear"></i> Settings
                </a>
            </li>
        </ul>
        
        <h6 class="sidebar-heading d-flex justify-content-between align-items-center px-3 mt-4 mb-1 text-muted">
            <span>Quick Actions</span>
        </h6>
        <ul class="nav flex-column mb-2">
            <li class="nav-item">
                <a class="nav-link" href="#" id="quickCreateAccount">
                    <i class="bi bi-plus-circle"></i> Create Account
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#" id="quickRestartServices">
                    <i class="bi bi-arrow-repeat"></i> Restart Services
                </a>
            </li>
            <li class="nav-item">
                <a class="nav-link" href="#" id="quickBackup">
                    <i class="bi bi-cloud-arrow-up"></i> Backup Now
                </a>
            </li>
        </ul>
    </div>
</nav>
EOF
    
    # Create CSS file
    cat > "$DASHBOARD_DIR/public/css/style.css" << 'EOF'
/* Dashboard styles */
body {
    font-size: .875rem;
}

.feather {
    width: 16px;
    height: 16px;
    vertical-align: text-bottom;
}

/* Sidebar */
.sidebar {
    position: fixed;
    top: 0;
    bottom: 0;
    left: 0;
    z-index: 100; /* Behind the navbar */
    padding: 48px 0 0; /* Height of navbar */
    box-shadow: inset -1px 0 0 rgba(0, 0, 0, .1);
}

@media (max-width: 767.98px) {
    .sidebar {
        top: 5rem;
    }
}

.sidebar-sticky {
    position: relative;
    top: 0;
    height: calc(100vh - 48px);
    padding-top: .5rem;
    overflow-x: hidden;
    overflow-y: auto; /* Scrollable contents if viewport is shorter than content. */
}

.sidebar .nav-link {
    font-weight: 500;
    color: #333;
}

.sidebar .nav-link .feather {
    margin-right: 4px;
    color: #727272;
}

.sidebar .nav-link.active {
    color: #2470dc;
}

.sidebar .nav-link:hover .feather,
.sidebar .nav-link.active .feather {
    color: inherit;
}

.sidebar-heading {
    font-size: .75rem;
    text-transform: uppercase;
}

/* Navbar */
.navbar-brand {
    padding-top: .75rem;
    padding-bottom: .75rem;
    font-size: 1rem;
    background-color: rgba(0, 0, 0, .25);
    box-shadow: inset -1px 0 0 rgba(0, 0, 0, .25);
}

.navbar .navbar-toggler {
    top: .25rem;
    right: 1rem;
}

/* Content */
.navbar .form-control {
    padding: .75rem 1rem;
    border-width: 0;
    border-radius: 0;
}

.form-control-dark {
    color: #fff;
    background-color: rgba(255, 255, 255, .1);
    border-color: rgba(255, 255, 255, .1);
}

.form-control-dark:focus {
    border-color: transparent;
    box-shadow: 0 0 0 3px rgba(255, 255, 255, .25);
}

/* Login page */
.login-page {
    display: flex;
    align-items: center;
    padding-top: 40px;
    padding-bottom: 40px;
    background-color: #f5f5f5;
    height: 100vh;
}

.login-card {
    max-width: 330px;
    padding: 15px;
    margin: auto;
    background-color: white;
    border-radius: 5px;
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    padding: 2rem;
}

/* Logs container */
.logs-container {
    height: 500px;
    overflow-y: auto;
    background-color: #f8f9fa;
    padding: 10px;
    font-family: monospace;
    font-size: 0.85rem;
    white-space: pre-wrap;
}

/* Cards */
.card {
    margin-bottom: 1rem;
    box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
}

.card-title {
    margin-bottom: 1rem;
    font-weight: 500;
}
EOF
    
    # Create dashboard JavaScript file
    cat > "$DASHBOARD_DIR/public/js/dashboard.js" << 'EOF'
// Dashboard JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Connect to Socket.IO
    const socket = io();
    
    // Chart configuration
    const ctx = document.getElementById('resourceChart').getContext('2d');
    const resourceChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: [],
            datasets: [
                {
                    label: 'CPU Usage (%)',
                    data: [],
                    borderColor: 'rgba(255, 99, 132, 1)',
                    backgroundColor: 'rgba(255, 99, 132, 0.2)',
                    tension: 0.4
                },
                {
                    label: 'Memory Usage (%)',
                    data: [],
                    borderColor: 'rgba(54, 162, 235, 1)',
                    backgroundColor: 'rgba(54, 162, 235, 0.2)',
                    tension: 0.4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                y: {
                    beginAtZero: true,
                    max: 100
                }
            }
        }
    });
    
    // Function to update system info
    function updateSystemInfo() {
        fetch('/api/system-info')
            .then(response => response.json())
            .then(data => {
                let html = '';
                for (const [key, value] of Object.entries(data)) {
                    html += `<tr><td><strong>${key}</strong></td><td>${value}</td></tr>`;
                }
                document.getElementById('systemInfoTable').innerHTML = html;
            })
            .catch(error => console.error('Error fetching system info:', error));
    }
    
    // Function to format uptime
    function formatUptime(seconds) {
        const days = Math.floor(seconds / 86400);
        seconds %= 86400;
        const hours = Math.floor(seconds / 3600);
        seconds %= 3600;
        const minutes = Math.floor(seconds / 60);
        seconds = Math.floor(seconds % 60);
        
        return `${days} days, ${hours} hours, ${minutes} minutes, ${seconds} seconds`;
    }
    
    // Listen for system stats updates
    socket.on('system-stats', function(data) {
        // Update CPU progress bar
        const cpuProgress = document.getElementById('cpuProgress');
        cpuProgress.style.width = `${data.cpu}%`;
        cpuProgress.textContent = `${data.cpu}%`;
        cpuProgress.setAttribute('aria-valuenow', data.cpu);
        
        // Update CPU info
        document.getElementById('cpuInfo').textContent = `Load Average: ${data.cpu}%`;
        
        // Update Memory progress bar
        const memoryProgress = document.getElementById('memoryProgress');
        memoryProgress.style.width = `${data.memory}%`;
        memoryProgress.textContent = `${data.memory}%`;
        memoryProgress.setAttribute('aria-valuenow', data.memory);
        
        // Update Memory info
        document.getElementById('memoryInfo').textContent = `Used: ${data.memory}%`;
        
        // Update Uptime info
        document.getElementById('uptimeInfo').textContent = formatUptime(data.uptime);
        
        // Update chart
        const now = new Date();
        const timeString = now.toLocaleTimeString();
        
        // Add data to chart
        resourceChart.data.labels.push(timeString);
        resourceChart.data.datasets[0].data.push(data.cpu);
        resourceChart.data.datasets[1].data.push(data.memory);
        
        // Keep only the last 20 data points
        if (resourceChart.data.labels.length > 20) {
            resourceChart.data.labels.shift();
            resourceChart.data.datasets[0].data.shift();
            resourceChart.data.datasets[1].data.shift();
        }
        
        resourceChart.update();
    });
    
    // Initial load
    updateSystemInfo();
    
    // Refresh button
    document.getElementById('refreshBtn').addEventListener('click', updateSystemInfo);
    
    // Quick action buttons
    document.getElementById('quickCreateAccount').addEventListener('click', function(e) {
        e.preventDefault();
        window.location.href = '/accounts';
    });
    
    document.getElementById('quickRestartServices').addEventListener('click', function(e) {
        e.preventDefault();
        if (confirm('Are you sure you want to restart all services?')) {
            fetch('/api/restart-services', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('Services restarted successfully');
                    } else {
                        alert('Failed to restart services: ' + data.error);
                    }
                })
                .catch(error => console.error('Error restarting services:', error));
        }
    });
    
    document.getElementById('quickBackup').addEventListener('click', function(e) {
        e.preventDefault();
        if (confirm('Are you sure you want to create a backup now?')) {
            fetch('/api/backup-now', { method: 'POST' })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('Backup created successfully');
                    } else {
                        alert('Failed to create backup: ' + data.error);
                    }
                })
                .catch(error => console.error('Error creating backup:', error));
        }
    });
});
EOF
    
    # Create accounts JavaScript file
    cat > "$DASHBOARD_DIR/public/js/accounts.js" << 'EOF'
// Accounts JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Function to load accounts
    function loadAccounts(type) {
        fetch(`/api/accounts/${type}`)
            .then(response => response.json())
            .then(accounts => {
                const tableId = `${type}AccountsTable`;
                const table = document.getElementById(tableId);
                
                if (accounts.length === 0) {
                    table.innerHTML = `<tr><td colspan="5">No ${type.toUpperCase()} accounts found</td></tr>`;
                    return;
                }
                
                let html = '';
                accounts.forEach(account => {
                    html += `
                        <tr>
                            <td>${account.username}</td>
                            <td>${account.password}</td>
                            <td>${account.created}</td>
                            <td>${account.expires}</td>
                            <td>
                                <button class="btn btn-sm btn-danger delete-account" data-type="${type}" data-username="${account.username}">Delete</button>
                            </td>
                        </tr>
                    `;
                });
                
                table.innerHTML = html;
                
                // Add event listeners to delete buttons
                document.querySelectorAll('.delete-account').forEach(button => {
                    button.addEventListener('click', function() {
                        const type = this.getAttribute('data-type');
                        const username = this.getAttribute('data-username');
                        
                        if (confirm(`Are you sure you want to delete ${username}?`)) {
                            deleteAccount(type, username);
                        }
                    });
                });
            })
            .catch(error => console.error(`Error loading ${type} accounts:`, error));
    }
    
    // Function to delete account
    function deleteAccount(type, username) {
        fetch(`/api/accounts/${type}/${username}`, {
            method: 'DELETE'
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert(`${type.toUpperCase()} account deleted successfully`);
                    loadAccounts(type);
                } else {
                    alert(`Failed to delete account: ${data.error}`);
                }
            })
            .catch(error => console.error('Error deleting account:', error));
    }
    
    // Load accounts for each tab
    loadAccounts('ssh');
    
    // Tab change event
    document.querySelectorAll('button[data-bs-toggle="tab"]').forEach(tab => {
        tab.addEventListener('shown.bs.tab', function(event) {
            const type = event.target.id.split('-')[0];
            loadAccounts(type);
        });
    });
    
    // Create account form submission
    document.getElementById('createAccountBtn').addEventListener('click', function() {
        const type = document.getElementById('accountType').value;
        const username = document.getElementById('username').value;
        const password = document.getElementById('password').value;
        const days = document.getElementById('days').value;
        
        if (!username || !password || !days) {
            alert('Please fill in all fields');
            return;
        }
        
        fetch(`/api/accounts/${type}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username,
                password,
                days
            })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert(`${type.toUpperCase()} account created successfully`);
                    
                    // Close modal
                    const modal = bootstrap.Modal.getInstance(document.getElementById('createAccountModal'));
                    modal.hide();
                    
                    // Reset form
                    document.getElementById('username').value = '';
                    document.getElementById('password').value = '';
                    document.getElementById('days').value = '30';
                    
                    // Reload accounts
                    loadAccounts(type);
                    
                    // Switch to the appropriate tab
                    const tabElement = document.querySelector(`#${type}-tab`);
                    const tab = new bootstrap.Tab(tabElement);
                    tab.show();
                } else {
                    alert(`Failed to create account: ${data.error}`);
                }
            })
            .catch(error => console.error('Error creating account:', error));
    });
});
EOF
    
    # Create bandwidth JavaScript file
    cat > "$DASHBOARD_DIR/public/js/bandwidth.js" << 'EOF'
// Bandwidth JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Chart configuration
    const ctx = document.getElementById('bandwidthChart').getContext('2d');
    let bandwidthChart;
    
    // Function to load bandwidth data
    function loadBandwidthData() {
        fetch('/api/bandwidth')
            .then(response => response.json())
            .then(data => {
                updateBandwidthTable(data);
                updateBandwidthChart(data);
                updateTopUsersTable(data);
                updateUserDropdown(data);
            })
            .catch(error => console.error('Error loading bandwidth data:', error));
    }
    
    // Function to update bandwidth table
    function updateBandwidthTable(data) {
        const table = document.getElementById('bandwidthTable');
        
        if (data.length === 0) {
            table.innerHTML = '<tr><td colspan="5">No bandwidth data available</td></tr>';
            return;
        }
        
        let html = '';
        data.forEach(item => {
            // Determine status class
            let statusClass = '';
            if (item.status.includes('EXCEEDED')) {
                statusClass = 'text-danger';
            } else if (item.status.includes('WARNING')) {
                statusClass = 'text-warning';
            } else {
                statusClass = 'text-success';
            }
            
            html += `
                <tr>
                    <td>${item.username}</td>
                    <td>${item.usage}</td>
                    <td>${item.limit}</td>
                    <td class="${statusClass}">${item.status}</td>
                    <td>
                        <button class="btn btn-sm btn-warning reset-bandwidth" data-username="${item.username}">Reset</button>
                        <button class="btn btn-sm btn-primary set-limit" data-username="${item.username}">Set Limit</button>
                    </td>
                </tr>
            `;
        });
        
        table.innerHTML = html;
        
        // Add event listeners to buttons
        document.querySelectorAll('.reset-bandwidth').forEach(button => {
            button.addEventListener('click', function() {
                const username = this.getAttribute('data-username');
                
                if (confirm(`Are you sure you want to reset bandwidth usage for ${username}?`)) {
                    resetBandwidth(username);
                }
            });
        });
        
        document.querySelectorAll('.set-limit').forEach(button => {
            button.addEventListener('click', function() {
                const username = this.getAttribute('data-username');
                document.getElementById('limitUsername').value = username;
                
                // Find current limit
                const userBandwidth = data.find(item => item.username === username);
                if (userBandwidth) {
                    const limit = userBandwidth.limit === 'Unlimited' ? 0 : parseFloat(userBandwidth.limit);
                    document.getElementById('limitValue').value = limit;
                }
                
                // Show modal
                const modal = new bootstrap.Modal(document.getElementById('setBandwidthLimitModal'));
                modal.show();
            });
        });
    }
    
    // Function to update bandwidth chart
    function updateBandwidthChart(data) {
        // Prepare data for chart
        const labels = data.map(item => item.username);
        const usageData = data.map(item => parseFloat(item.usage));
        
        // Create or update chart
        if (bandwidthChart) {
            bandwidthChart.data.labels = labels;
            bandwidthChart.data.datasets[0].data = usageData;
            bandwidthChart.update();
        } else {
            bandwidthChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: labels,
                    datasets: [{
                        label: 'Bandwidth Usage (GB)',
                        data: usageData,
                        backgroundColor: 'rgba(54, 162, 235, 0.5)',
                        borderColor: 'rgba(54, 162, 235, 1)',
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    scales: {
                        y: {
                            beginAtZero: true,
                            title: {
                                display: true,
                                text: 'GB'
                            }
                        }
                    }
                }
            });
        }
    }
    
    // Function to update top users table
    function updateTopUsersTable(data) {
        const table = document.getElementById('topUsersTable');
        
        if (data.length === 0) {
            table.innerHTML = '<tr><td colspan="3">No bandwidth data available</td></tr>';
            return;
        }
        
        // Sort by usage (descending)
        const sortedData = [...data].sort((a, b) => {
            return parseFloat(b.usage) - parseFloat(a.usage);
        });
        
        // Take top 5
        const topUsers = sortedData.slice(0, 5);
        
        // Calculate total usage
        const totalUsage = data.reduce((sum, item) => sum + parseFloat(item.usage), 0);
        
        let html = '';
        topUsers.forEach(item => {
            const usage = parseFloat(item.usage);
            const percentage = totalUsage > 0 ? ((usage / totalUsage) * 100).toFixed(2) : 0;
            
            html += `
                <tr>
                    <td>${item.username}</td>
                    <td>${item.usage}</td>
                    <td>${percentage}%</td>
                </tr>
            `;
        });
        
        table.innerHTML = html;
    }
    
    // Function to update user dropdown
    function updateUserDropdown(data) {
        const dropdown = document.getElementById('limitUsername');
        
        let html = '';
        data.forEach(item => {
            html += `<option value="${item.username}">${item.username}</option>`;
        });
        
        dropdown.innerHTML = html;
    }
    
    // Function to reset bandwidth
    function resetBandwidth(username) {
        fetch(`/api/bandwidth/reset/${username}`, {
            method: 'POST'
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert(`Bandwidth usage for ${username} reset successfully`);
                    loadBandwidthData();
                } else {
                    alert(`Failed to reset bandwidth: ${data.error}`);
                }
            })
            .catch(error => console.error('Error resetting bandwidth:', error));
    }
    
    // Set bandwidth limit form submission
    document.getElementById('setBandwidthLimitBtn').addEventListener('click', function() {
        const username = document.getElementById('limitUsername').value;
        const limit = document.getElementById('limitValue').value;
        
        if (!username || limit === '') {
            alert('Please fill in all fields');
            return;
        }
        
        fetch(`/api/bandwidth/limit/${username}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                limit
            })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert(`Bandwidth limit for ${username} set successfully`);
                    
                    // Close modal
                    const modal = bootstrap.Modal.getInstance(document.getElementById('setBandwidthLimitModal'));
                    modal.hide();
                    
                    // Reload bandwidth data
                    loadBandwidthData();
                } else {
                    alert(`Failed to set bandwidth limit: ${data.error}`);
                }
            })
            .catch(error => console.error('Error setting bandwidth limit:', error));
    });
    
    // Refresh button
    document.getElementById('refreshBandwidthBtn').addEventListener('click', loadBandwidthData);
    
    // Initial load
    loadBandwidthData();
});
EOF
    
    # Create settings JavaScript file
    cat > "$DASHBOARD_DIR/public/js/settings.js" << 'EOF'
// Settings JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Load dashboard settings
    fetch('/api/settings/dashboard')
        .then(response => response.json())
        .then(data => {
            document.getElementById('dashboardUsername').value = data.username;
            document.getElementById('dashboardPort').value = data.port;
        })
        .catch(error => console.error('Error loading dashboard settings:', error));
    
    // Load domain settings
    fetch('/api/settings/domain')
        .then(response => response.json())
        .then(data => {
            document.getElementById('domainName').value = data.domain;
        })
        .catch(error => console.error('Error loading domain settings:', error));
    
    // Load backup settings
    fetch('/api/settings/backup')
        .then(response => response.json())
        .then(data => {
            document.getElementById('backupSchedule').value = data.schedule;
        })
        .catch(error => console.error('Error loading backup settings:', error));
    
    // Dashboard settings form submission
    document.getElementById('dashboardSettingsForm').addEventListener('submit', function(e) {
        e.preventDefault();
        
        const username = document.getElementById('dashboardUsername').value;
        const password = document.getElementById('dashboardPassword').value;
        const port = document.getElementById('dashboardPort').value;
        
        if (!username || !password || !port) {
            alert('Please fill in all fields');
            return;
        }
        
        fetch('/api/settings/dashboard', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                username,
                password,
                port
            })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('Dashboard settings updated successfully. Please restart the dashboard for changes to take effect.');
                } else {
                    alert(`Failed to update dashboard settings: ${data.error}`);
                }
            })
            .catch(error => console.error('Error updating dashboard settings:', error));
    });
    
    // Domain settings form submission
    document.getElementById('domainSettingsForm').addEventListener('submit', function(e) {
        e.preventDefault();
        
        const domain = document.getElementById('domainName').value;
        
        if (!domain) {
            alert('Please enter a domain name');
            return;
        }
        
        fetch('/api/settings/domain', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                domain
            })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('Domain settings updated successfully');
                } else {
                    alert(`Failed to update domain settings: ${data.error}`);
                }
            })
            .catch(error => console.error('Error updating domain settings:', error));
    });
    
    // Backup settings form submission
    document.getElementById('backupSettingsForm').addEventListener('submit', function(e) {
        e.preventDefault();
        
        const schedule = document.getElementById('backupSchedule').value;
        
        fetch('/api/settings/backup', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                schedule
            })
        })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    alert('Backup settings updated successfully');
                } else {
                    alert(`Failed to update backup settings: ${data.error}`);
                }
            })
            .catch(error => console.error('Error updating backup settings:', error));
    });
    
    // Backup now button
    document.getElementById('backupNowBtn').addEventListener('click', function() {
        if (confirm('Are you sure you want to create a backup now?')) {
            fetch('/api/backup-now', {
                method: 'POST'
            })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('Backup created successfully');
                    } else {
                        alert(`Failed to create backup: ${data.error}`);
                    }
                })
                .catch(error => console.error('Error creating backup:', error));
        }
    });
    
    // Restore backup button
    document.getElementById('restoreBackupBtn').addEventListener('click', function() {
        if (confirm('WARNING: Restoring a backup will overwrite current data. Are you sure you want to proceed?')) {
            fetch('/api/restore-backup', {
                method: 'POST'
            })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('Backup restored successfully');
                    } else {
                        alert(`Failed to restore backup: ${data.error}`);
                    }
                })
                .catch(error => console.error('Error restoring backup:', error));
        }
    });
    
    // Restart services button
    document.getElementById('restartServicesBtn').addEventListener('click', function() {
        if (confirm('Are you sure you want to restart all services?')) {
            fetch('/api/restart-services', {
                method: 'POST'
            })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('Services restarted successfully');
                    } else {
                        alert(`Failed to restart services: ${data.error}`);
                    }
                })
                .catch(error => console.error('Error restarting services:', error));
        }
    });
    
    // Update system button
    document.getElementById('updateSystemBtn').addEventListener('click', function() {
        if (confirm('Are you sure you want to update system packages? This may take a while.')) {
            fetch('/api/update-system', {
                method: 'POST'
            })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('System packages updated successfully');
                    } else {
                        alert(`Failed to update system packages: ${data.error}`);
                    }
                })
                .catch(error => console.error('Error updating system packages:', error));
        }
    });
    
    // Update script button
    document.getElementById('updateScriptBtn').addEventListener('click', function() {
        if (confirm('Are you sure you want to update the VPS Manager script?')) {
            fetch('/api/update-script', {
                method: 'POST'
            })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('VPS Manager script updated successfully');
                    } else {
                        alert(`Failed to update VPS Manager script: ${data.error}`);
                    }
                })
                .catch(error => console.error('Error updating VPS Manager script:', error));
        }
    });
    
    // Reboot system button
    document.getElementById('rebootSystemBtn').addEventListener('click', function() {
        if (confirm('WARNING: This will reboot the server. Are you sure you want to proceed?')) {
            fetch('/api/reboot-system', {
                method: 'POST'
            })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        alert('System reboot initiated. The server will be unavailable for a few minutes.');
                    } else {
                        alert(`Failed to reboot system: ${data.error}`);
                    }
                })
                .catch(error => console.error('Error rebooting system:', error));
        }
    });
});
EOF
    
    # Create logs JavaScript file
    cat > "$DASHBOARD_DIR/public/js/logs.js" << 'EOF'
// Logs JavaScript
document.addEventListener('DOMContentLoaded', function() {
    // Function to load logs
    function loadLogs(type) {
        fetch(`/api/logs/${type}`)
            .then(response => response.json())
            .then(data => {
                document.getElementById(`${type}Logs`).textContent = data.logs;
            })
            .catch(error => console.error(`Error loading ${type} logs:`, error));
    }
    
    // Load logs for each tab
    loadLogs('system');
    
    // Tab change event
    document.querySelectorAll('button[data-bs-toggle="tab"]').forEach(tab => {
        tab.addEventListener('shown.bs.tab', function(event) {
            const type = event.target.id.split('-')[0];
            loadLogs(type);
        });
    });
    
    // Refresh button
    document.getElementById('refreshLogsBtn').addEventListener('click', function() {
        const activeTab = document.querySelector('.tab-pane.active');
        const type = activeTab.id;
        loadLogs(type);
    });
});
EOF
    
    log_message "${GREEN}Dashboard files created successfully.${NC}"
}

# Function to create systemd service for dashboard
create_dashboard_service() {
    log_message "${YELLOW}Creating dashboard systemd service...${NC}"
    
    cat > /etc/systemd/system/vps_dashboard.service << EOF
[Unit]
Description=VPS Manager Web Dashboard
After=network.target

[Service]
ExecStart=/usr/bin/node $DASHBOARD_DIR/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=vps-dashboard
Environment=NODE_ENV=production
Environment=PORT=$DASHBOARD_PORT

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable vps_dashboard.service
    
    log_message "${GREEN}Dashboard service created and enabled.${NC}"
}

# Function to start dashboard
start_dashboard() {
    log_message "${YELLOW}Starting dashboard service...${NC}"
    
    systemctl start vps_dashboard.service
    
    # Check if service started successfully
    if systemctl is-active --quiet vps_dashboard.service; then
        log_message "${GREEN}Dashboard service started successfully.${NC}"
        log_message "${GREEN}Dashboard is accessible at: http://$(hostname -I | awk '{print $1}'):$DASHBOARD_PORT${NC}"
    else
        log_message "${RED}Failed to start dashboard service.${NC}"
        log_message "${YELLOW}Check logs with: journalctl -u vps_dashboard.service${NC}"
    fi
}

# Function to stop dashboard
stop_dashboard() {
    log_message "${YELLOW}Stopping dashboard service...${NC}"
    
    systemctl stop vps_dashboard.service
    
    log_message "${GREEN}Dashboard service stopped.${NC}"
}

# Function to restart dashboard
restart_dashboard() {
    log_message "${YELLOW}Restarting dashboard service...${NC}"
    
    systemctl restart vps_dashboard.service
    
    # Check if service restarted successfully
    if systemctl is-active --quiet vps_dashboard.service; then
        log_message "${GREEN}Dashboard service restarted successfully.${NC}"
    else
        log_message "${RED}Failed to restart dashboard service.${NC}"
        log_message "${YELLOW}Check logs with: journalctl -u vps_dashboard.service${NC}"
    fi
}

# Function to check dashboard status
check_dashboard_status() {
    log_message "${YELLOW}Checking dashboard status...${NC}"
    
    systemctl status vps_dashboard.service
}

# Function to change dashboard credentials
change_dashboard_credentials() {
    log_message "${YELLOW}Changing dashboard credentials...${NC}"
    
    read -p "Enter new username: " new_user
    read -s -p "Enter new password: " new_pass
    echo ""
    
    echo "$new_user" > "$CONFIG_DIR/dashboard_user"
    echo "$new_pass" > "$CONFIG_DIR/dashboard_pass"
    
    log_message "${GREEN}Dashboard credentials updated.${NC}"
    log_message "${YELLOW}Please restart the dashboard for changes to take effect.${NC}"
}

# Function to change dashboard port
change_dashboard_port() {
    log_message "${YELLOW}Changing dashboard port...${NC}"
    
    read -p "Enter new port (1024-65535): " new_port
    
    # Validate port
    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
        log_message "${RED}Invalid port number. Please enter a number between 1024 and 65535.${NC}"
        return 1
    fi
    
    # Update port in config
    DASHBOARD_PORT=$new_port
    echo "DASHBOARD_PORT=$new_port" > "$CONFIG_DIR/dashboard_port"
    
    # Update service file
    sed -i "s/Environment=PORT=.*/Environment=PORT=$new_port/" /etc/systemd/system/vps_dashboard.service
    
    systemctl daemon-reload
    
    log_message "${GREEN}Dashboard port updated to $new_port.${NC}"
    log_message "${YELLOW}Please restart the dashboard for changes to take effect.${NC}"
}

# Function to display dashboard menu
dashboard_menu() {
    clear
    echo -e "${BLUE}${BOLD}=== WEB DASHBOARD MANAGEMENT ===${NC}"
    echo -e "${CYAN}1.${NC} Install Dashboard"
    echo -e "${CYAN}2.${NC} Start Dashboard"
    echo -e "${CYAN}3.${NC} Stop Dashboard"
    echo -e "${CYAN}4.${NC} Restart Dashboard"
    echo -e "${CYAN}5.${NC} Check Dashboard Status"
    echo -e "${CYAN}6.${NC} Change Dashboard Credentials"
    echo -e "${CYAN}7.${NC} Change Dashboard Port"
    echo -e "${CYAN}8.${NC} Back to Main Menu"
    echo -e "${CYAN}0.${NC} Exit"
    echo ""
    read -p "Select an option: " option
    
    case $option in
        1)
            install_dashboard_deps
            create_dashboard_files
            create_dashboard_service
            start_dashboard
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        2)
            start_dashboard
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        3)
            stop_dashboard
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        4)
            restart_dashboard
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        5)
            check_dashboard_status
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        6)
            change_dashboard_credentials
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        7)
            change_dashboard_port
            echo ""
            read -p "Press Enter to continue..."
            dashboard_menu
            ;;
        8)
            # Return to main menu (handled by calling script)
            return
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            dashboard_menu
            ;;
    esac
}

# Function to install the dashboard
install_dashboard() {
    install_dashboard_deps
    create_dashboard_files
    create_dashboard_service
    start_dashboard
}

# Main execution
case "$1" in
    install)
        install_dashboard
        ;;
    start)
        start_dashboard
        ;;
    stop)
        stop_dashboard
        ;;
    restart)
        restart_dashboard
        ;;
    status)
        check_dashboard_status
        ;;
    credentials)
        change_dashboard_credentials
        ;;
    port)
        change_dashboard_port
        ;;
    menu)
        dashboard_menu
        ;;
    *)
        echo -e "${BLUE}${BOLD}Web Dashboard for VPS Manager${NC}"
        echo -e "${CYAN}Usage:${NC}"
        echo -e "  $0 install              - Install web dashboard"
        echo -e "  $0 start                - Start dashboard service"
        echo -e "  $0 stop                 - Stop dashboard service"
        echo -e "  $0 restart              - Restart dashboard service"
        echo -e "  $0 status               - Check dashboard status"
        echo -e "  $0 credentials          - Change dashboard credentials"
        echo -e "  $0 port                 - Change dashboard port"
        echo -e "  $0 menu                 - Show dashboard menu"
        ;;
esac

exit 0
