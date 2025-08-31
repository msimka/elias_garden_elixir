#!/bin/bash

# Griffith Connection Test and Debug Script

echo "🔍 Testing Griffith Connection..."
echo "=================================="

# Test network connectivity
echo "1. Testing network connectivity to Griffith..."
if ping -c 3 -W 3000 172.20.35.144 > /dev/null 2>&1; then
    echo "✅ Network: Griffith is reachable"
else
    echo "❌ Network: Cannot reach Griffith (172.20.35.144)"
    echo "   Likely cause: Not on office network or VPN"
fi

echo ""

# Test SSH connection
echo "2. Testing SSH connection..."
if timeout 10 ssh -q -o ConnectTimeout=5 griffith "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✅ SSH: Connection successful"
else
    echo "❌ SSH: Connection failed"
    echo "   Checking SSH configuration..."
fi

echo ""

# Check SSH config
echo "3. Checking SSH configuration..."
if grep -q "griffith" ~/.ssh/config 2>/dev/null; then
    echo "✅ SSH Config: Griffith entry found"
    echo "   Configuration:"
    grep -A 5 "^Host griffith" ~/.ssh/config | head -6
else
    echo "❌ SSH Config: No Griffith configuration found"
fi

echo ""

# Check VPN status
echo "4. Checking VPN status..."
vpn_processes=$(ps aux | grep -i vpn | grep -v grep | wc -l)
if [ $vpn_processes -gt 0 ]; then
    echo "✅ VPN: VPN process detected"
    ps aux | grep -i vpn | grep -v grep
else
    echo "❌ VPN: No VPN processes running"
fi

echo ""

# Network diagnostics
echo "5. Network diagnostics..."
echo "Current network interface:"
ifconfig | grep -A 1 "en0\|en1" | grep "inet " | head -1

echo "Current public IP:"
curl -s --max-time 5 ifconfig.me || echo "Could not determine public IP"

echo ""

# Recommendations
echo "🛠️  RECOMMENDATIONS"
echo "=================="
echo "If connection failed:"
echo "1. Connect to office VPN"
echo "2. Use office WiFi network" 
echo "3. Check if Griffith has external access configured"
echo "4. Consider SSH port forwarding through jump host"

echo ""
echo "✅ Ready to deploy UDM when connection is available"
echo "   Run: ./deploy_udm_griffith.sh"