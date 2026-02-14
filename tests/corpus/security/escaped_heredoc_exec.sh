cat <<'EOF' >/tmp/run.sh
echo hi
EOF
bash /tmp/run.sh
source /tmp/run.sh
