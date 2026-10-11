@echo off
call C:\oss-cad-suite-windows-x64\oss-cad-suite\environment.bat
yosys synth_direct.ys > direct_report.txt
yosys synth_serial.ys > serial_report.txt
echo Done.