#!/bin/bash
# Monitor CpGPT embeddings process and catch errors

LOG_FILE="/tmp/cpgpt_embeddings.log"
MAX_WAIT=3600  # 1 hour max wait
CHECK_INTERVAL=30  # Check every 30 seconds
START_TIME=$(date +%s)

echo "=========================================="
echo "CpGPT Embeddings Monitor"
echo "=========================================="
echo "Log file: $LOG_FILE"
echo "Check interval: ${CHECK_INTERVAL}s"
echo "Max wait: ${MAX_WAIT}s"
echo ""

# Check if process is running
check_process() {
    ps aux | grep -E "python.*cpgpt_embeddings_only|python.*convert_cpgcorpus|python.*cpgpt_prepare" | grep -v grep | head -1
}

# Check for errors in log
check_errors() {
    if [ -f "$LOG_FILE" ]; then
        grep -i "error\|failed\|exception\|traceback\|fatal" "$LOG_FILE" | tail -5
    fi
}

# Check for completion
check_completion() {
    if [ -f "$LOG_FILE" ]; then
        grep -i "✓.*complete\|embeddings.*complete\|saved.*embeddings" "$LOG_FILE" | tail -1
    fi
}

# Main monitoring loop
ITERATION=0
while true; do
    ITERATION=$((ITERATION + 1))
    ELAPSED=$(($(date +%s) - START_TIME))
    
    echo "[$(date +%H:%M:%S)] Check #$ITERATION (elapsed: ${ELAPSED}s)"
    
    # Check if process is still running
    PROCESS=$(check_process)
    if [ -z "$PROCESS" ]; then
        echo "  ⚠️  No active process found"
        # Check if it completed successfully
        COMPLETION=$(check_completion)
        if [ ! -z "$COMPLETION" ]; then
            echo "  ✅ Process completed successfully!"
            echo "  Last completion message: $COMPLETION"
            exit 0
        else
            echo "  ❌ Process stopped without completion"
            echo "  Last log entries:"
            tail -10 "$LOG_FILE" 2>/dev/null || echo "  (log file not found)"
            exit 1
        fi
    else
        PID=$(echo "$PROCESS" | awk '{print $2}')
        CPU=$(echo "$PROCESS" | awk '{print $3"%"}')
        MEM=$(echo "$PROCESS" | awk '{print $4"%"}')
        echo "  🔄 Process running (PID: $PID, CPU: $CPU, MEM: $MEM)"
    fi
    
    # Check for errors
    ERRORS=$(check_errors)
    if [ ! -z "$ERRORS" ]; then
        echo "  ❌ ERRORS DETECTED:"
        echo "$ERRORS" | sed 's/^/    /'
        echo ""
        echo "  Full error context:"
        tail -50 "$LOG_FILE" | grep -A 10 -B 10 -i "error\|failed\|exception" | head -30 | sed 's/^/    /'
        exit 1
    fi
    
    # Check for completion
    COMPLETION=$(check_completion)
    if [ ! -z "$COMPLETION" ]; then
        echo "  ✅ Completion detected!"
        echo "  Message: $COMPLETION"
        # Wait a bit to ensure process finishes
        sleep 5
        PROCESS=$(check_process)
        if [ -z "$PROCESS" ]; then
            echo "  ✅ Process finished successfully"
            exit 0
        fi
    fi
    
    # Check max wait time
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "  ⏰ Max wait time reached (${MAX_WAIT}s)"
        echo "  Process is still running. Check manually."
        exit 2
    fi
    
    # Show recent log activity
    if [ -f "$LOG_FILE" ]; then
        RECENT=$(tail -3 "$LOG_FILE" | grep -v "^$" | tail -1)
        if [ ! -z "$RECENT" ]; then
            echo "  📋 Recent: ${RECENT:0:80}..."
        fi
    fi
    
    echo ""
    sleep $CHECK_INTERVAL
done
