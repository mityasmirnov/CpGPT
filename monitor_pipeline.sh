#!/bin/bash
# Quick monitoring script for CpGPT AJHG Episignature Pipeline
# Usage: ./monitor_pipeline.sh [--watch]

echo "=========================================="
echo "CpGPT AJHG Pipeline Status Monitor"
echo "=========================================="
echo ""

# Check external drive connectivity
echo "📁 External Drive Status:"
if ls -ld /Volumes/Dima_work/cpgpt_data/results >/dev/null 2>&1; then
    echo "  ✅ Connected: /Volumes/Dima_work/cpgpt_data/"
    echo "  Results dir: $(ls -ld /Volumes/Dima_work/cpgpt_data/results | awk '{print $9, "(" $5, "bytes)"}')"
else
    echo "  ❌ NOT CONNECTED: /Volumes/Dima_work/cpgpt_data/"
    echo "  ⚠️  Processes will fail if drive is not mounted!"
fi
echo ""

# Check running processes
echo "🔄 Active Processes:"
PROCS=$(ps aux | grep -E "make.*ajhg|Rscript.*ajhg|python.*cpgpt|make.*cpgpt" | grep -v grep)
if [ -z "$PROCS" ]; then
    echo "  ⚠️  No active pipeline processes found"
else
    echo "$PROCS" | while read line; do
        PID=$(echo "$line" | awk '{print $2}')
        CMD=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
        STAT=$(echo "$line" | awk '{print $8}')
        CPU=$(echo "$line" | awk '{print $3"%"}')
        MEM=$(echo "$line" | awk '{print $4"%"}')
        echo "  PID: $PID | Status: $STAT | CPU: $CPU | Memory: $MEM"
        echo "    Command: $CMD"
    done
fi
echo ""

# Check log files
echo "📋 Log Files:"
for log in /tmp/ajhg_train.log /tmp/cpgpt_embeddings_only.log /tmp/cpgpt_infer.log /tmp/episignature_eval.log; do
    if [ -f "$log" ]; then
        SIZE=$(ls -lh "$log" | awk '{print $5}')
        LINES=$(wc -l < "$log" 2>/dev/null || echo "0")
        LAST_MOD=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$log" 2>/dev/null || echo "unknown")
        echo "  ✅ $(basename $log): $SIZE, $LINES lines, modified: $LAST_MOD"
        
        # Check for recent errors
        ERRORS=$(grep -i "error\|failed\|halted" "$log" 2>/dev/null | tail -1)
        if [ ! -z "$ERRORS" ]; then
            echo "    ⚠️  Last error: ${ERRORS:0:80}..."
        fi
    else
        echo "  ⏳ $(basename $log): Not created yet"
    fi
done
echo ""

# Check results directories
echo "📊 Results Directories:"
for dir in ajhg cpgpt episignature; do
    RESULT_DIR="/Volumes/Dima_work/cpgpt_data/results/$dir"
    if [ -d "$RESULT_DIR" ]; then
        FILE_COUNT=$(find "$RESULT_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$FILE_COUNT" -gt 0 ]; then
            echo "  ✅ $dir/: $FILE_COUNT files"
            ls -lh "$RESULT_DIR" | head -3 | tail -2 | awk '{print "    " $9, "(" $5 ")"}'
        else
            echo "  ⏳ $dir/: Directory exists but empty"
        fi
    else
        echo "  ⏳ $dir/: Not created yet"
    fi
done
echo ""

# Show recent log activity
if [ "$1" == "--watch" ]; then
    echo "📺 Watching logs in real-time (Ctrl+C to stop):"
    echo "=========================================="
    echo "Choose which log to watch:"
    echo "  1) AJHG log: tail -f /tmp/ajhg_train.log"
    echo "  2) CpGPT embeddings log: tail -f /tmp/cpgpt_embeddings_only.log"
    echo ""
    echo "Watching CpGPT embeddings log (most recent activity):"
    tail -f /tmp/cpgpt_embeddings_only.log 2>/dev/null || tail -f /tmp/ajhg_train.log 2>/dev/null || echo "No log files found"
elif [ "$1" == "--cpgpt" ]; then
    echo "📺 CpGPT Embeddings Status:"
    echo "=========================================="
    if [ -f "/tmp/cpgpt_embeddings_only.log" ]; then
        tail -20 /tmp/cpgpt_embeddings_only.log
    else
        echo "CpGPT embeddings log not found"
    fi
else
    echo "💡 Recent log activity:"
    echo "=========================================="
    if [ -f "/tmp/cpgpt_embeddings_only.log" ]; then
        echo "CpGPT embeddings (last 5 lines):"
        tail -5 /tmp/cpgpt_embeddings_only.log 2>/dev/null || echo "  (empty)"
    fi
    if [ -f "/tmp/ajhg_train.log" ]; then
        echo ""
        echo "AJHG replication (last 5 lines):"
        tail -5 /tmp/ajhg_train.log 2>/dev/null || echo "  (empty)"
    fi
    echo ""
    echo "💡 Tips:"
    echo "  - Use './monitor_pipeline.sh --watch' to watch logs in real-time"
    echo "  - Use './monitor_pipeline.sh --cpgpt' to see CpGPT embeddings status"
    echo "  - Use './monitor_cpgpt.sh' for detailed CpGPT embeddings monitoring"
fi
