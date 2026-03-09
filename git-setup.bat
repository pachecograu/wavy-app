@echo off
echo Configurando repositorio Git para WAVY App...

git init
git add .
git commit -m "Initial commit: WAVY Flutter App"
git branch -M main
git remote add origin https://github.com/pachecograu/wavy-app.git
git push -u origin main

echo.
echo Repositorio configurado y archivos subidos exitosamente!
pause
