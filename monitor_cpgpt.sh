#!/bin/bash
# Monitor CpGPT embeddings job progress in real-time
# Usage: ./monitor_cpgpt.sh [--watch]

LOG_FILE="/tmp/cpgpt_embeddings_only.log"
RESULTS_DIR="/Volumes/Dima_work/cpgpt_data/results/cpgpt"

echo "=========================================="
echo "CpGPT Embeddings Job Monitor"
echo "=========================================="
echo ""

# Check if process is running
echo "🔄 Process Status:"
PROCS=$(ps aux | grep -E "python.*cpgpt_embeddings_only|poetry.*cpgpt_embeddings" | grep -v grep)
if [ -z "$PROCS" ]; then
    echo "  ⚠️  No CpGPT embeddings process found"
else
    echo "$PROCS" | while read line; do
        PID=$(echo "$line" | awk '{print $2}')
        CMD=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
        STAT=$(echo "$line" | awk '{print $8}')
        CPU=$(echo "$line" | awk '{print $3"%"}')
        MEM=$(echo "$line" | awk '{print $4"%"}')
        ETIME=$(ps -p $PID -o etime= 2>/dev/null | tr -d ' ' || echo "unknown")
        echo "  PID: $PID | Status: $STAT | CPU: $CPU | Memory: $MEM | Runtime: $ETIME"
        echo "    Command: ${CMD:0:100}..."
    done
fi
echo ""

# Check log file
echo "📋 Log File Status:"
if [ -f "$LOG_FILE" ]; then
    SIZE=$(ls -lh "$LOG_FILE" | awk '{print $5}')
    LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
    LAST_MOD=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$LOG_FILE" 2>/dev/null || echo "unknown")
    echo "  ✅ Log file exists: $SIZE, $LINES lines, modified: $LAST_MOD"
    
    # Check for recent activity (last 30 seconds)
    if [ "$(uname)" == "Darwin" ]; then
        MOD_TIME=$(stat -f "%m" "$LOG_FILE" 2>/dev/null)
        NOW=$(date +%s)
        AGE=$((NOW - MOD_TIME))
        if [ $AGE -lt 30 ]; then
            echo "  🔄 ACTIVE: Log updated $AGE seconds ago"
        else
            echo "  ⏸️  STALLED: Log not updated for $AGE seconds"
        fi
    fi
    
    # Show recent progress indicators
    echo ""
    echo "📊 Recent Progress:"
    if grep -q "Extracting sample embeddings" "$LOG_FILE"; then
        echo "  ✅ Embeddings extraction started"
        # Try to find progress indicators
        PROGRESS=$(grep -E "Processing|batch|sample|Embedding shape" "$LOG_FILE" | tail -3)
        if [ ! -z "$PROGRESS" ]; then
            echo "$PROGRESS" | while read line; do
                echo "    $line"
            done
        fi
    elif grep -q "Creating data module" "$LOG_FILE"; then
        echo "  🔄 Creating data module..."
    elif grep -q "Loading checkpoint" "$LOG_FILE"; then
        echo "  🔄 Loading model..."
    elif grep -q "Initializing CpGPTInferencer" "$LOG_FILE"; then
        echo "  🔄 Initializing inferencer..."
    else
        echo "  ⏳ Starting up..."
    fi
    
    # Check for errors
    echo ""
    echo "⚠️  Recent Errors/Warnings:"
    ERRORS=$(grep -i "error\|failed\|exception\|traceback" "$LOG_FILE" | tail -3)
    if [ ! -z "$ERRORS" ]; then
        echo "$ERRORS" | while read line; do
            echo "    ${line:0:120}..."
        done
    else
        echo "  ✅ No errors found"
    fi
else
    echo "  ⏳ Log file not created yet"
fi
echo ""

# Check results
echo "📊 Results Directory:"
if [ -d "$RESULTS_DIR" ]; then
    FILE_COUNT=$(find "$RESULTS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo "  ✅ $FILE_COUNT files found:"
        ls -lh "$RESULTS_DIR" | grep -v "^total" | head -5 | awk '{print "    " $9, "(" $5 ")"}'
        
        # Check for embeddings file specifically
        if [ -f "$RESULTS_DIR/sample_embeddings.pt" ]; then
            EMBED_SIZE=$(ls -lh "$RESULTS_DIR/sample_embeddings.pt" | awk '{print $5}')
            echo "  ✅ sample_embeddings.pt exists: $EMBED_SIZE"
        fi
    else
        echo "  ⏳ Directory exists but empty"
    fi
else
    echo "  ⏳ Results directory not created yet"
fi
echo ""

# Show recent log activity
if [ "$1" == "--watch" ]; then
    echo "📺 Watching log in real-time (Ctrl+C to stop):"
    echo "=========================================="
    tail -f "$LOG_FILE" 2>/dev/null || echo "Log file not found"
else
    echo "💡 Recent log activity (last 10 lines):"
    echo "=========================================="
    tail -10 "$LOG_FILE" 2>/dev/null || echo "Log file not found"
    echo ""
    echo "💡 Tip: Use './monitor_cpgpt.sh --watch' to watch log in real-time"
fi
