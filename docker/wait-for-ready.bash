#!/usr/bin/env bash

if [[ -f run/ready ]]; then
	exit
fi

exec awk 'BEGIN {
	cmd = "tail -F run/ready 2>/dev/null"
	cmd = "echo $$ && exec "cmd
	cmd | getline pid
	if ((cmd | getline) <= 0) {
		close(cmd)
		exit(1)
	}
	system("kill -9 "pid)
	close(cmd)
}'
