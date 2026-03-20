#!/bin/bash

echo ">>> Starting Oracle Listener..."
su - oracle -c "lsnrctl start"

echo ">>> Starting Oracle Database (SID=orcl)..."
su - oracle -c "sqlplus / as sysdba << 'EOF'
startup
EXIT;
EOF"

echo ">>> Oracle 19c Ready. (SID=orcl, PORT=1521)"

# 컨테이너 유지
exec tail -f /dev/null
