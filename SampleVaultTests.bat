@echo off
:: Cambiamos la codificación de la terminal a UTF-8 para que entienda símbolos como °.
chcp 65001 > nul
title Lanzador SampleVaultests - ISFT 151
color 0A

echo Lanzando el frontend en el navegador...
start http://localhost:3000

:: Usamos %~dp0 que es una variable de sistema que apunta a la carpeta donde está el script.
echo Accediendo a la carpeta del backend...
cd /d "%~dp0backend"

:: Verificamos si server.js existe antes de intentar correrlo.
if exist server.js (
    echo Iniciando motor Node.js...
    echo.
    node server.js
) else (
    echo.
    echo [ERROR] No se encontró server.js en la carpeta backend.
    echo Ruta actual: %cd%
)

pause