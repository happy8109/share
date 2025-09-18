@echo off
title Miner Start

:loop
minerd.exe -a sha256d -D -o stratum+tcp://public-pool.io:21496 -u 1J1PhNiw2fSWKoPYm1eh24x3xmqXSCvZ79.office -p x -t 1
echo Miner exited. Waiting 10 seconds before restarting...
timeout /t 10 /nobreak > NUL
goto loop
