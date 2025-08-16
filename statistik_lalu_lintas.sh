#!/bin/bash
# Traffic Statistics and Graphs for VPS Manager
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
LOG_DIR="/var/log/vps_manager"
STATS_DIR="$CONFIG_DIR/traffic_stats"
GRAPHS_DIR="$CONFIG_DIR/traffic_graphs"
HTML_DIR="/var/www/html/stats"
STATS_LOG="$LOG_DIR/traffic_stats.log"
COLLECTION_INTERVAL=300 # 5 minutes in seconds

# Ensure directories exist
mkdir -p $CONFIG_DIR
mkdir -p $LOG_DIR
mkdir -p $STATS_DIR
mkdir -p $GRAPHS_DIR
mkdir -p $HTML_DIR

# Function to log messages
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $STATS_LOG
    echo -e "$1"
}

# Function to check if a package is installed
is_installed() {
    if dpkg -s "$1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to install required packages
install_dependencies() {
    log_message "${YELLOW}Installing dependencies...${NC}"
    
    # Update package lists
    apt-get update
    
    # Install required packages
    apt-get install -y vnstat iftop iptraf-ng nload nethogs bmon tcpdump gnuplot apache2 php libapache2-mod-php php-json
    
    # Install vnStat PHP frontend
    if [ ! -d "/var/www/html/vnstat" ]; then
        cd /tmp
        wget -q https://github.com/alexandermarston/vnstat-dashboard/archive/master.zip
        unzip -q master.zip
        mkdir -p /var/www/html/vnstat
        cp -r vnstat-dashboard-master/* /var/www/html/vnstat/
        rm -rf vnstat-dashboard-master master.zip
        
        # Configure vnStat PHP frontend
        sed -i "s/\$iface_list = array('eth0', 'wlan0');/\$iface_list = array('$(ip route | grep default | awk '{print $5}')');/" /var/www/html/vnstat/config.php
        sed -i "s/\$vnstat_bin = 'vnstat';/\$vnstat_bin = '\/usr\/bin\/vnstat';/" /var/www/html/vnstat/config.php
        
        # Set permissions
        chown -R www-data:www-data /var/www/html/vnstat
    fi
    
    # Enable and start vnStat service
    systemctl enable vnstat
    systemctl restart vnstat
    
    log_message "${GREEN}Dependencies installed successfully.${NC}"
}

# Function to setup traffic monitoring
setup_traffic_monitoring() {
    log_message "${YELLOW}Setting up traffic monitoring...${NC}"
    
    # Get main interface
    MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}')
    
    # Configure vnStat for the main interface
    vnstat -u -i $MAIN_INTERFACE
    
    # Create iptables rules for per-user traffic monitoring if they don't exist
    if ! iptables -L TRAFFIC_IN &>/dev/null; then
        iptables -N TRAFFIC_IN
        iptables -A INPUT -j TRAFFIC_IN
    fi
    
    if ! iptables -L TRAFFIC_OUT &>/dev/null; then
        iptables -N TRAFFIC_OUT
        iptables -A OUTPUT -j TRAFFIC_OUT
    fi
    
    # Save iptables rules
    if is_installed "iptables-persistent"; then
        netfilter-persistent save
    else
        iptables-save > /etc/iptables/rules.v4
    fi
    
    log_message "${GREEN}Traffic monitoring setup successfully.${NC}"
}

# Function to collect traffic data
collect_traffic_data() {
    log_message "${YELLOW}Collecting traffic data...${NC}"
    
    # Get current timestamp
    TIMESTAMP=$(date +%s)
    DATE_FORMAT=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Get main interface
    MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}')
    
    # Get overall traffic stats
    OVERALL_STATS=$(vnstat -i $MAIN_INTERFACE --json)
    echo "$OVERALL_STATS" > "$STATS_DIR/overall_stats_$TIMESTAMP.json"
    
    # Get hourly traffic stats
    HOURLY_STATS=$(vnstat -i $MAIN_INTERFACE -h --json)
    echo "$HOURLY_STATS" > "$STATS_DIR/hourly_stats_$TIMESTAMP.json"
    
    # Get daily traffic stats
    DAILY_STATS=$(vnstat -i $MAIN_INTERFACE -d --json)
    echo "$DAILY_STATS" > "$STATS_DIR/daily_stats_$TIMESTAMP.json"
    
    # Get monthly traffic stats
    MONTHLY_STATS=$(vnstat -i $MAIN_INTERFACE -m --json)
    echo "$MONTHLY_STATS" > "$STATS_DIR/monthly_stats_$TIMESTAMP.json"
    
    # Get current traffic rate
    CURRENT_RATE=$(vnstat -i $MAIN_INTERFACE -tr 2 --json)
    echo "$CURRENT_RATE" > "$STATS_DIR/current_rate_$TIMESTAMP.json"
    
    # Get per-user traffic stats
    # Get all SSH users
    USERS=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd)
    
    # Create a JSON array for user stats
    echo "{&quot;timestamp&quot;:&quot;$DATE_FORMAT&quot;,&quot;users&quot;:[" > "$STATS_DIR/user_stats_$TIMESTAMP.json"
    
    FIRST_USER=true
    for USER in $USERS; do
        # Skip system users
        if [[ "$USER" == "nobody" || "$USER" == "systemd-"* ]]; then
            continue
        fi
        
        # Check if user has iptables rules
        if ! iptables -L TRAFFIC_IN | grep -q "$USER"; then
            iptables -A TRAFFIC_IN -m owner --uid-owner "$USER" -j RETURN
        fi
        
        if ! iptables -L TRAFFIC_OUT | grep -q "$USER"; then
            iptables -A TRAFFIC_OUT -m owner --uid-owner "$USER" -j RETURN
        fi
        
        # Get traffic stats for the user
        IN_BYTES=$(iptables -L TRAFFIC_IN -v -n -x | grep "$USER" | awk '{print $2}')
        OUT_BYTES=$(iptables -L TRAFFIC_OUT -v -n -x | grep "$USER" | awk '{print $2}')
        
        # If no data found, set to 0
        IN_BYTES=${IN_BYTES:-0}
        OUT_BYTES=${OUT_BYTES:-0}
        
        # Calculate total bytes
        TOTAL_BYTES=$((IN_BYTES + OUT_BYTES))
        
        # Convert to human-readable format
        IN_HUMAN=$(numfmt --to=iec --suffix=B $IN_BYTES)
        OUT_HUMAN=$(numfmt --to=iec --suffix=B $OUT_BYTES)
        TOTAL_HUMAN=$(numfmt --to=iec --suffix=B $TOTAL_BYTES)
        
        # Add comma if not the first user
        if [ "$FIRST_USER" = true ]; then
            FIRST_USER=false
        else
            echo "," >> "$STATS_DIR/user_stats_$TIMESTAMP.json"
        fi
        
        # Add user stats to JSON
        cat >> "$STATS_DIR/user_stats_$TIMESTAMP.json" << EOF
{
    "username": "$USER",
    "in_bytes": $IN_BYTES,
    "out_bytes": $OUT_BYTES,
    "total_bytes": $TOTAL_BYTES,
    "in_human": "$IN_HUMAN",
    "out_human": "$OUT_HUMAN",
    "total_human": "$TOTAL_HUMAN"
}
EOF
    done
    
    # Close JSON array
    echo "]}" >> "$STATS_DIR/user_stats_$TIMESTAMP.json"
    
    # Reset iptables counters
    iptables -Z TRAFFIC_IN
    iptables -Z TRAFFIC_OUT
    
    # Create symlinks to latest stats
    ln -sf "$STATS_DIR/overall_stats_$TIMESTAMP.json" "$STATS_DIR/overall_stats_latest.json"
    ln -sf "$STATS_DIR/hourly_stats_$TIMESTAMP.json" "$STATS_DIR/hourly_stats_latest.json"
    ln -sf "$STATS_DIR/daily_stats_$TIMESTAMP.json" "$STATS_DIR/daily_stats_latest.json"
    ln -sf "$STATS_DIR/monthly_stats_$TIMESTAMP.json" "$STATS_DIR/monthly_stats_latest.json"
    ln -sf "$STATS_DIR/current_rate_$TIMESTAMP.json" "$STATS_DIR/current_rate_latest.json"
    ln -sf "$STATS_DIR/user_stats_$TIMESTAMP.json" "$STATS_DIR/user_stats_latest.json"
    
    log_message "${GREEN}Traffic data collected successfully.${NC}"
    
    # Clean up old stats files (keep only the last 24 hours)
    find "$STATS_DIR" -name "overall_stats_*.json" -mtime +1 -delete
    find "$STATS_DIR" -name "hourly_stats_*.json" -mtime +1 -delete
    find "$STATS_DIR" -name "daily_stats_*.json" -mtime +1 -delete
    find "$STATS_DIR" -name "monthly_stats_*.json" -mtime +1 -delete
    find "$STATS_DIR" -name "current_rate_*.json" -mtime +1 -delete
    find "$STATS_DIR" -name "user_stats_*.json" -mtime +1 -delete
}

# Function to generate traffic graphs
generate_traffic_graphs() {
    log_message "${YELLOW}Generating traffic graphs...${NC}"
    
    # Get current timestamp
    TIMESTAMP=$(date +%s)
    
    # Get main interface
    MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}')
    
    # Generate hourly traffic graph
    gnuplot << EOF
set terminal pngcairo enhanced font "arial,10" size 800,400
set output "$GRAPHS_DIR/hourly_traffic_$TIMESTAMP.png"
set title "Hourly Network Traffic"
set xlabel "Hour"
set ylabel "Traffic (MB)"
set grid
set style data histograms
set style fill solid 0.5
set boxwidth 0.8
set xtics rotate by -45
set datafile separator ","
set key outside
set auto x

# Create temporary data file
system "vnstat -i $MAIN_INTERFACE -h | grep -v 'hour' | grep -v '\\-\\-' | awk '{print \$1, \$2, \$3, \$6, \$7}' | tail -n 24 > /tmp/hourly_traffic.dat"

plot "/tmp/hourly_traffic.dat" using 4 title "Download (MB)" with boxes lc rgb "#00FF00", \
     "/tmp/hourly_traffic.dat" using 5 title "Upload (MB)" with boxes lc rgb "#FF0000"
EOF
    
    # Generate daily traffic graph
    gnuplot << EOF
set terminal pngcairo enhanced font "arial,10" size 800,400
set output "$GRAPHS_DIR/daily_traffic_$TIMESTAMP.png"
set title "Daily Network Traffic"
set xlabel "Day"
set ylabel "Traffic (MB)"
set grid
set style data histograms
set style fill solid 0.5
set boxwidth 0.8
set xtics rotate by -45
set datafile separator ","
set key outside
set auto x

# Create temporary data file
system "vnstat -i $MAIN_INTERFACE -d | grep -v 'day' | grep -v '\\-\\-' | awk '{print \$1, \$2, \$3, \$6, \$7}' | tail -n 30 > /tmp/daily_traffic.dat"

plot "/tmp/daily_traffic.dat" using 4 title "Download (MB)" with boxes lc rgb "#00FF00", \
     "/tmp/daily_traffic.dat" using 5 title "Upload (MB)" with boxes lc rgb "#FF0000"
EOF
    
    # Generate monthly traffic graph
    gnuplot << EOF
set terminal pngcairo enhanced font "arial,10" size 800,400
set output "$GRAPHS_DIR/monthly_traffic_$TIMESTAMP.png"
set title "Monthly Network Traffic"
set xlabel "Month"
set ylabel "Traffic (GB)"
set grid
set style data histograms
set style fill solid 0.5
set boxwidth 0.8
set xtics rotate by -45
set datafile separator ","
set key outside
set auto x

# Create temporary data file
system "vnstat -i $MAIN_INTERFACE -m | grep -v 'month' | grep -v '\\-\\-' | awk '{print \$1, \$2, \$3, \$6, \$7}' | tail -n 12 > /tmp/monthly_traffic.dat"

plot "/tmp/monthly_traffic.dat" using 4 title "Download (GB)" with boxes lc rgb "#00FF00", \
     "/tmp/monthly_traffic.dat" using 5 title "Upload (GB)" with boxes lc rgb "#FF0000"
EOF
    
    # Create symlinks to latest graphs
    ln -sf "$GRAPHS_DIR/hourly_traffic_$TIMESTAMP.png" "$GRAPHS_DIR/hourly_traffic_latest.png"
    ln -sf "$GRAPHS_DIR/daily_traffic_$TIMESTAMP.png" "$GRAPHS_DIR/daily_traffic_latest.png"
    ln -sf "$GRAPHS_DIR/monthly_traffic_$TIMESTAMP.png" "$GRAPHS_DIR/monthly_traffic_latest.png"
    
    # Copy to HTML directory
    cp "$GRAPHS_DIR/hourly_traffic_latest.png" "$HTML_DIR/hourly_traffic.png"
    cp "$GRAPHS_DIR/daily_traffic_latest.png" "$HTML_DIR/daily_traffic.png"
    cp "$GRAPHS_DIR/monthly_traffic_latest.png" "$HTML_DIR/monthly_traffic.png"
    
    log_message "${GREEN}Traffic graphs generated successfully.${NC}"
    
    # Clean up old graph files (keep only the last 24 hours)
    find "$GRAPHS_DIR" -name "hourly_traffic_*.png" -mtime +1 -delete
    find "$GRAPHS_DIR" -name "daily_traffic_*.png" -mtime +1 -delete
    find "$GRAPHS_DIR" -name "monthly_traffic_*.png" -mtime +1 -delete
}

# Function to generate HTML traffic dashboard
generate_html_dashboard() {
    log_message "${YELLOW}Generating HTML traffic dashboard...${NC}"
    
    # Create HTML index file
    cat > "$HTML_DIR/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VPS Traffic Statistics</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {
            padding-top: 20px;
            padding-bottom: 20px;
        }
        .header {
            padding-bottom: 20px;
            border-bottom: 1px solid #e5e5e5;
            margin-bottom: 30px;
        }
        .graph-container {
            margin-bottom: 30px;
        }
        .stats-card {
            margin-bottom: 20px;
        }
        .refresh-btn {
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>VPS Traffic Statistics</h1>
            <p class="lead">Real-time network traffic monitoring and statistics</p>
        </div>
        
        <div class="row">
            <div class="col-md-12">
                <button id="refreshBtn" class="btn btn-primary refresh-btn">
                    <i class="bi bi-arrow-clockwise"></i> Refresh Data
                </button>
            </div>
        </div>
        
        <div class="row">
            <div class="col-md-6">
                <div class="card stats-card">
                    <div class="card-header">
                        <h5>Current Traffic Rate</h5>
                    </div>
                    <div class="card-body">
                        <canvas id="currentRateChart"></canvas>
                    </div>
                </div>
            </div>
            
            <div class="col-md-6">
                <div class="card stats-card">
                    <div class="card-header">
                        <h5>Overall Statistics</h5>
                    </div>
                    <div class="card-body">
                        <table class="table table-striped">
                            <tbody id="overallStatsTable">
                                <tr><td>Loading...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="row">
            <div class="col-md-12">
                <div class="card stats-card">
                    <div class="card-header">
                        <h5>User Traffic Statistics</h5>
                    </div>
                    <div class="card-body">
                        <table class="table table-striped">
                            <thead>
                                <tr>
                                    <th>Username</th>
                                    <th>Download</th>
                                    <th>Upload</th>
                                    <th>Total</th>
                                </tr>
                            </thead>
                            <tbody id="userStatsTable">
                                <tr><td colspan="4">Loading...</td></tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="row">
            <div class="col-md-12">
                <ul class="nav nav-tabs" id="trafficTabs" role="tablist">
                    <li class="nav-item" role="presentation">
                        <button class="nav-link active" id="hourly-tab" data-bs-toggle="tab" data-bs-target="#hourly" type="button" role="tab" aria-controls="hourly" aria-selected="true">Hourly</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="daily-tab" data-bs-toggle="tab" data-bs-target="#daily" type="button" role="tab" aria-controls="daily" aria-selected="false">Daily</button>
                    </li>
                    <li class="nav-item" role="presentation">
                        <button class="nav-link" id="monthly-tab" data-bs-toggle="tab" data-bs-target="#monthly" type="button" role="tab" aria-controls="monthly" aria-selected="false">Monthly</button>
                    </li>
                </ul>
                
                <div class="tab-content" id="trafficTabsContent">
                    <div class="tab-pane fade show active" id="hourly" role="tabpanel" aria-labelledby="hourly-tab">
                        <div class="graph-container">
                            <img src="hourly_traffic.png" alt="Hourly Traffic" class="img-fluid" id="hourlyGraph">
                        </div>
                        <div class="card">
                            <div class="card-header">
                                <h5>Hourly Traffic Data</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="hourlyChart"></canvas>
                            </div>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="daily" role="tabpanel" aria-labelledby="daily-tab">
                        <div class="graph-container">
                            <img src="daily_traffic.png" alt="Daily Traffic" class="img-fluid" id="dailyGraph">
                        </div>
                        <div class="card">
                            <div class="card-header">
                                <h5>Daily Traffic Data</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="dailyChart"></canvas>
                            </div>
                        </div>
                    </div>
                    
                    <div class="tab-pane fade" id="monthly" role="tabpanel" aria-labelledby="monthly-tab">
                        <div class="graph-container">
                            <img src="monthly_traffic.png" alt="Monthly Traffic" class="img-fluid" id="monthlyGraph">
                        </div>
                        <div class="card">
                            <div class="card-header">
                                <h5>Monthly Traffic Data</h5>
                            </div>
                            <div class="card-body">
                                <canvas id="monthlyChart"></canvas>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <footer class="pt-4 my-md-5 pt-md-5 border-top">
            <div class="row">
                <div class="col-12 col-md">
                    <small class="d-block mb-3 text-muted">&copy; VPS Manager 2025</small>
                </div>
            </div>
        </footer>
    </div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Function to format bytes to human-readable format
        function formatBytes(bytes, decimals = 2) {
            if (bytes === 0) return '0 Bytes';
            
            const k = 1024;
            const dm = decimals < 0 ? 0 : decimals;
            const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
            
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            
            return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
        }
        
        // Function to load overall stats
        function loadOverallStats() {
            fetch('overall_stats_latest.json')
                .then(response => response.json())
                .then(data => {
                    const interface = data.interfaces[0];
                    const total = interface.traffic.total;
                    
                    let html = '';
                    html += '<tr><td>Interface</td><td>' + interface.name + '</td></tr>';
                    html += '<tr><td>Total Download</td><td>' + formatBytes(total.rx) + '</td></tr>';
                    html += '<tr><td>Total Upload</td><td>' + formatBytes(total.tx) + '</td></tr>';
                    html += '<tr><td>Total Traffic</td><td>' + formatBytes(total.rx + total.tx) + '</td></tr>';
                    html += '<tr><td>Created</td><td>' + new Date(interface.created.timestamp * 1000).toLocaleString() + '</td></tr>';
                    html += '<tr><td>Updated</td><td>' + new Date(interface.updated.timestamp * 1000).toLocaleString() + '</td></tr>';
                    
                    document.getElementById('overallStatsTable').innerHTML = html;
                })
                .catch(error => console.error('Error loading overall stats:', error));
        }
        
        // Function to load user stats
        function loadUserStats() {
            fetch('user_stats_latest.json')
                .then(response => response.json())
                .then(data => {
                    const users = data.users;
                    
                    if (users.length === 0) {
                        document.getElementById('userStatsTable').innerHTML = '<tr><td colspan="4">No user data available</td></tr>';
                        return;
                    }
                    
                    let html = '';
                    users.forEach(user => {
                        html += '<tr>';
                        html += '<td>' + user.username + '</td>';
                        html += '<td>' + user.in_human + '</td>';
                        html += '<td>' + user.out_human + '</td>';
                        html += '<td>' + user.total_human + '</td>';
                        html += '</tr>';
                    });
                    
                    document.getElementById('userStatsTable').innerHTML = html;
                })
                .catch(error => console.error('Error loading user stats:', error));
        }
        
        // Function to load current rate
        function loadCurrentRate() {
            fetch('current_rate_latest.json')
                .then(response => response.json())
                .then(data => {
                    const traffic = data.interfaces[0].traffic;
                    
                    // Update current rate chart
                    if (window.currentRateChart) {
                        window.currentRateChart.data.datasets[0].data = [traffic.rx, traffic.tx];
                        window.currentRateChart.update();
                    } else {
                        const ctx = document.getElementById('currentRateChart').getContext('2d');
                        window.currentRateChart = new Chart(ctx, {
                            type: 'bar',
                            data: {
                                labels: ['Download', 'Upload'],
                                datasets: [{
                                    label: 'Current Rate (KB/s)',
                                    data: [traffic.rx, traffic.tx],
                                    backgroundColor: [
                                        'rgba(75, 192, 192, 0.2)',
                                        'rgba(255, 99, 132, 0.2)'
                                    ],
                                    borderColor: [
                                        'rgba(75, 192, 192, 1)',
                                        'rgba(255, 99, 132, 1)'
                                    ],
                                    borderWidth: 1
                                }]
                            },
                            options: {
                                scales: {
                                    y: {
                                        beginAtZero: true,
                                        title: {
                                            display: true,
                                            text: 'KB/s'
                                        }
                                    }
                                }
                            }
                        });
                    }
                })
                .catch(error => console.error('Error loading current rate:', error));
        }
        
        // Function to load hourly stats
        function loadHourlyStats() {
            fetch('hourly_stats_latest.json')
                .then(response => response.json())
                .then(data => {
                    const hours = data.interfaces[0].traffic.hours;
                    
                    // Prepare data for chart
                    const labels = hours.map(hour => hour.id);
                    const rxData = hours.map(hour => hour.rx / 1024 / 1024); // Convert to MB
                    const txData = hours.map(hour => hour.tx / 1024 / 1024); // Convert to MB
                    
                    // Update hourly chart
                    if (window.hourlyChart) {
                        window.hourlyChart.data.labels = labels;
                        window.hourlyChart.data.datasets[0].data = rxData;
                        window.hourlyChart.data.datasets[1].data = txData;
                        window.hourlyChart.update();
                    } else {
                        const ctx = document.getElementById('hourlyChart').getContext('2d');
                        window.hourlyChart = new Chart(ctx, {
                            type: 'line',
                            data: {
                                labels: labels,
                                datasets: [
                                    {
                                        label: 'Download (MB)',
                                        data: rxData,
                                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                                        borderColor: 'rgba(75, 192, 192, 1)',
                                        borderWidth: 1,
                                        tension: 0.4
                                    },
                                    {
                                        label: 'Upload (MB)',
                                        data: txData,
                                        backgroundColor: 'rgba(255, 99, 132, 0.2)',
                                        borderColor: 'rgba(255, 99, 132, 1)',
                                        borderWidth: 1,
                                        tension: 0.4
                                    }
                                ]
                            },
                            options: {
                                scales: {
                                    y: {
                                        beginAtZero: true,
                                        title: {
                                            display: true,
                                            text: 'MB'
                                        }
                                    }
                                }
                            }
                        });
                    }
                    
                    // Refresh the graph image
                    document.getElementById('hourlyGraph').src = 'hourly_traffic.png?' + new Date().getTime();
                })
                .catch(error => console.error('Error loading hourly stats:', error));
        }
        
        // Function to load daily stats
        function loadDailyStats() {
            fetch('daily_stats_latest.json')
                .then(response => response.json())
                .then(data => {
                    const days = data.interfaces[0].traffic.days;
                    
                    // Prepare data for chart
                    const labels = days.map(day => day.date);
                    const rxData = days.map(day => day.rx / 1024 / 1024); // Convert to MB
                    const txData = days.map(day => day.tx / 1024 / 1024); // Convert to MB
                    
                    // Update daily chart
                    if (window.dailyChart) {
                        window.dailyChart.data.labels = labels;
                        window.dailyChart.data.datasets[0].data = rxData;
                        window.dailyChart.data.datasets[1].data = txData;
                        window.dailyChart.update();
                    } else {
                        const ctx = document.getElementById('dailyChart').getContext('2d');
                        window.dailyChart = new Chart(ctx, {
                            type: 'bar',
                            data: {
                                labels: labels,
                                datasets: [
                                    {
                                        label: 'Download (MB)',
                                        data: rxData,
                                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                                        borderColor: 'rgba(75, 192, 192, 1)',
                                        borderWidth: 1
                                    },
                                    {
                                        label: 'Upload (MB)',
                                        data: txData,
                                        backgroundColor: 'rgba(255, 99, 132, 0.2)',
                                        borderColor: 'rgba(255, 99, 132, 1)',
                                        borderWidth: 1
                                    }
                                ]
                            },
                            options: {
                                scales: {
                                    y: {
                                        beginAtZero: true,
                                        title: {
                                            display: true,
                                            text: 'MB'
                                        }
                                    }
                                }
                            }
                        });
                    }
                    
                    // Refresh the graph image
                    document.getElementById('dailyGraph').src = 'daily_traffic.png?' + new Date().getTime();
                })
                .catch(error => console.error('Error loading daily stats:', error));
        }
        
        // Function to load monthly stats
        function loadMonthlyStats() {
            fetch('monthly_stats_latest.json')
                .then(response => response.json())
                .then(data => {
                    const months = data.interfaces[0].traffic.months;
                    
                    // Prepare data for chart
                    const labels = months.map(month => month.date);
                    const rxData = months.map(month => month.rx / 1024 / 1024 / 1024); // Convert to GB
                    const txData = months.map(month => month.tx / 1024 / 1024 / 1024); // Convert to GB
                    
                    // Update monthly chart
                    if (window.monthlyChart) {
                        window.monthlyChart.data.labels = labels;
                        window.monthlyChart.data.datasets[0].data = rxData;
                        window.monthlyChart.data.datasets[1].data = txData;
                        window.monthlyChart.update();
                    } else {
                        const ctx = document.getElementById('monthlyChart').getContext('2d');
                        window.monthlyChart = new Chart(ctx, {
                            type: 'bar',
                            data: {
                                labels: labels,
                                datasets: [
                                    {
                                        label: 'Download (GB)',
                                        data: rxData,
                                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                                        borderColor: 'rgba(75, 192, 192, 1)',
                                        borderWidth: 1
                                    },
                                    {
                                        label: 'Upload (GB)',
                                        data: txData,
                                        backgroundColor: 'rgba(255, 99, 132, 0.2)',
                                        borderColor: 'rgba(255, 99, 132, 1)',
                                        borderWidth: 1
                                    }
                                ]
                            },
                            options: {
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
                    
                    // Refresh the graph image
                    document.getElementById('monthlyGraph').src = 'monthly_traffic.png?' + new Date().getTime();
                })
                .catch(error => console.error('Error loading monthly stats:', error));
        }
        
        // Function to load all stats
        function loadAllStats() {
            loadOverallStats();
            loadUserStats();
            loadCurrentRate();
            loadHourlyStats();
            loadDailyStats();
            loadMonthlyStats();
        }
        
        // Load stats on page load
        document.addEventListener('DOMContentLoaded', function() {
            loadAllStats();
            
            // Set up refresh button
            document.getElementById('refreshBtn').addEventListener('click', loadAllStats);
            
            // Set up tab change event
            document.querySelectorAll('button[data-bs-toggle="tab"]').forEach(tab => {
                tab.addEventListener('shown.bs.tab', function(event) {
                    const target = event.target.getAttribute('data-bs-target').substring(1);
                    if (target === 'hourly') {
                        loadHourlyStats();
                    } else if (target === 'daily') {
                        loadDailyStats();
                    } else if (target === 'monthly') {
                        loadMonthlyStats();
                    }
                });
            });
            
            // Auto-refresh every 5 minutes
            setInterval(loadAllStats, 300000);
        });
    </script>
</body>
</html>
EOF
    
    # Create JSON symlinks in HTML directory
    ln -sf "$STATS_DIR/overall_stats_latest.json" "$HTML_DIR/overall_stats_latest.json"
    ln -sf "$STATS_DIR/hourly_stats_latest.json" "$HTML_DIR/hourly_stats_latest.json"
    ln -sf "$STATS_DIR/daily_stats_latest.json" "$HTML_DIR/daily_stats_latest.json"
    ln -sf "$STATS_DIR/monthly_stats_latest.json" "$HTML_DIR/monthly_stats_latest.json"
    ln -sf "$STATS_DIR/current_rate_latest.json" "$HTML_DIR/current_rate_latest.json"
    ln -sf "$STATS_DIR/user_stats_latest.json" "$HTML_DIR/user_stats_latest.json"
    
    # Set permissions
    chown -R www-data:www-data $HTML_DIR
    
    log_message "${GREEN}HTML traffic dashboard generated successfully.${NC}"
}

# Function to setup Apache virtual host
setup_apache_vhost() {
    log_message "${YELLOW}Setting up Apache virtual host...${NC}"
    
    # Create virtual host configuration
    cat > /etc/apache2/sites-available/traffic-stats.conf << EOF
<VirtualHost *:80>
    ServerName stats.$(hostname -f)
    ServerAlias stats
    DocumentRoot $HTML_DIR
    
    <Directory $HTML_DIR>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/traffic-stats-error.log
    CustomLog \${APACHE_LOG_DIR}/traffic-stats-access.log combined
</VirtualHost>
EOF
    
    # Enable virtual host
    a2ensite traffic-stats.conf
    
    # Restart Apache
    systemctl restart apache2
    
    log_message "${GREEN}Apache virtual host setup successfully.${NC}"
    log_message "${GREEN}Traffic statistics dashboard is accessible at: http://stats.$(hostname -f) or http://$(hostname -I | awk '{print $1}')/stats${NC}"
}

# Function to setup cron job for data collection
setup_cron_job() {
    log_message "${YELLOW}Setting up cron job for data collection...${NC}"
    
    # Create cron job for data collection
    cat > /etc/cron.d/traffic-stats << EOF
# Collect traffic data every 5 minutes
*/5 * * * * root /usr/local/bin/traffic_stats.sh collect > /dev/null 2>&1

# Generate traffic graphs every hour
0 * * * * root /usr/local/bin/traffic_stats.sh graphs > /dev/null 2>&1

# Generate HTML dashboard every hour
5 * * * * root /usr/local/bin/traffic_stats.sh html > /dev/null 2>&1
EOF
    
    log_message "${GREEN}Cron job setup successfully.${NC}"
}

# Function to install traffic statistics
install_traffic_stats() {
    log_message "${YELLOW}Installing traffic statistics...${NC}"
    
    # Install dependencies
    install_dependencies
    
    # Setup traffic monitoring
    setup_traffic_monitoring
    
    # Copy this script to /usr/local/bin
    cp "$0" /usr/local/bin/traffic_stats.sh
    chmod +x /usr/local/bin/traffic_stats.sh
    
    # Create symlink to HTML directory
    ln -sf $HTML_DIR /var/www/html/stats
    
    # Setup Apache virtual host
    setup_apache_vhost
    
    # Setup cron job
    setup_cron_job
    
    # Collect initial data
    collect_traffic_data
    
    # Generate initial graphs
    generate_traffic_graphs
    
    # Generate initial HTML dashboard
    generate_html_dashboard
    
    log_message "${GREEN}Traffic statistics installed successfully.${NC}"
    log_message "${GREEN}Traffic statistics dashboard is accessible at: http://stats.$(hostname -f) or http://$(hostname -I | awk '{print $1}')/stats${NC}"
}

# Function to display traffic statistics menu
traffic_stats_menu() {
    clear
    echo -e "${BLUE}${BOLD}=== TRAFFIC STATISTICS MENU ===${NC}"
    echo -e "${CYAN}1.${NC} Install Traffic Statistics"
    echo -e "${CYAN}2.${NC} Collect Traffic Data"
    echo -e "${CYAN}3.${NC} Generate Traffic Graphs"
    echo -e "${CYAN}4.${NC} Generate HTML Dashboard"
    echo -e "${CYAN}5.${NC} View Traffic Statistics"
    echo -e "${CYAN}6.${NC} Back to Main Menu"
    echo -e "${CYAN}0.${NC} Exit"
    echo ""
    read -p "Select an option: " option
    
    case $option in
        1)
            install_traffic_stats
            echo ""
            read -p "Press Enter to continue..."
            traffic_stats_menu
            ;;
        2)
            collect_traffic_data
            echo ""
            read -p "Press Enter to continue..."
            traffic_stats_menu
            ;;
        3)
            generate_traffic_graphs
            echo ""
            read -p "Press Enter to continue..."
            traffic_stats_menu
            ;;
        4)
            generate_html_dashboard
            echo ""
            read -p "Press Enter to continue..."
            traffic_stats_menu
            ;;
        5)
            echo -e "${GREEN}Traffic statistics dashboard is accessible at: http://stats.$(hostname -f) or http://$(hostname -I | awk '{print $1}')/stats${NC}"
            echo -e "${YELLOW}VnStat dashboard is accessible at: http://$(hostname -f)/vnstat or http://$(hostname -I | awk '{print $1}')/vnstat${NC}"
            echo ""
            read -p "Press Enter to continue..."
            traffic_stats_menu
            ;;
        6)
            # Return to main menu (handled by calling script)
            return
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option!${NC}"
            sleep 2
            traffic_stats_menu
            ;;
    esac
}

# Main execution
case "$1" in
    install)
        install_traffic_stats
        ;;
    collect)
        collect_traffic_data
        ;;
    graphs)
        generate_traffic_graphs
        ;;
    html)
        generate_html_dashboard
        ;;
    menu)
        traffic_stats_menu
        ;;
    *)
        echo -e "${BLUE}${BOLD}Traffic Statistics and Graphs for VPS Manager${NC}"
        echo -e "${CYAN}Usage:${NC}"
        echo -e "  $0 install              - Install traffic statistics"
        echo -e "  $0 collect              - Collect traffic data"
        echo -e "  $0 graphs               - Generate traffic graphs"
        echo -e "  $0 html                 - Generate HTML dashboard"
        echo -e "  $0 menu                 - Show traffic statistics menu"
        ;;
esac

exit 0
