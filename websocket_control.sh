#!/bin/bash

# WebSocket Monitoring Control Script

echo "🔌 WebSocket Monitoring Control"
echo "================================"

case "$1" in
    "status")
        echo "📊 Current WebSocket Status:"
        curl -s http://localhost:3002/websocket/stats | jq
        ;;
    "stop")
        echo "🛑 Stopping all WebSocket connections..."
        curl -X POST http://localhost:3002/websocket/stop_all
        echo ""
        ;;
    "stop-user")
        if [ -z "$2" ]; then
            echo "❌ Please provide user ID: ./websocket_control.sh stop-user 39"
            exit 1
        fi
        echo "🛑 Stopping connections for user $2..."
        curl -X POST http://localhost:3002/websocket/stop_user/$2
        echo ""
        ;;
    "monitor")
        echo "📈 Starting live monitoring (30-second intervals)..."
        echo "Press Ctrl+C to stop"
        watch -n 30 'curl -s http://localhost:3002/websocket/stats | jq'
        ;;
    "dashboard")
        echo "🌐 Opening monitoring dashboard..."
        echo "Dashboard URL: http://localhost:3002/websocket_dashboard.html"
        echo "Quiet Dashboard: http://localhost:3002/websocket_dashboard_quiet.html"
        echo "Note: Dashboard now polls every 5 minutes (much quieter!)"
        ;;
    "pause")
        echo "⏸️ Pausing WebSocket monitoring..."
        curl -X POST http://localhost:3002/websocket/pause | jq
        ;;
    "resume")
        echo "▶️ Resuming WebSocket monitoring..."
        curl -X POST http://localhost:3002/websocket/resume | jq
        ;;
    *)
        echo "Usage: $0 {status|stop|stop-user|monitor|dashboard|pause|resume}"
        echo ""
        echo "Commands:"
        echo "  status      - Show current WebSocket status"
        echo "  stop        - Stop all WebSocket connections"
        echo "  stop-user   - Stop connections for specific user"
        echo "  monitor     - Live monitoring with 30-second updates"
        echo "  dashboard   - Open web dashboard (5-minute polling)"
        echo "  pause       - Pause WebSocket monitoring"
        echo "  resume      - Resume WebSocket monitoring"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 stop"
        echo "  $0 stop-user 39"
        echo "  $0 monitor"
        ;;
esac
