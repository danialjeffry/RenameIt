@echo off
echo ===================================
echo  RenameIt - Building .exe
echo ===================================
echo.

echo [1/4] Creating virtual environment...
python -m venv venv
call venv\Scripts\activate.bat

echo [2/4] Installing dependencies...
pip install customtkinter pyinstaller --quiet

REM tkinterdnd2 is optional — app works without it (Browse button only)
pip install tkinterdnd2 --quiet 2>nul
if errorlevel 1 (
    echo NOTE: tkinterdnd2 not available. Drag-and-drop will be disabled.
    echo       The app will still work with the Browse button.
    echo.
)

echo [3/4] Building .exe...

REM Check if tkinterdnd2 installed successfully
python -c "import tkinterdnd2" 2>nul
if errorlevel 1 (
    echo Building WITHOUT drag-and-drop support...
    pyinstaller --noconfirm --onefile --windowed ^
        --name "RenameIt" ^
        RenameIt.py
) else (
    echo Building WITH drag-and-drop support...
    pyinstaller --noconfirm --onefile --windowed ^
        --name "RenameIt" ^
        --collect-data tkinterdnd2 ^
        --hidden-import tkinterdnd2 ^
        RenameIt.py
)

if errorlevel 1 (
    echo ERROR: Build failed
    pause
    exit /b 1
)

echo [4/4] Done!
echo.
echo ===================================
echo  .exe created at: dist\RenameIt.exe
echo  You can distribute this single file.
echo ===================================
echo.

REM Clean up
deactivate
rmdir /s /q venv 2>nul

pause
