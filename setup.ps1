Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Ì∫Ä Setting up Deepfake Detection System" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Create virtual environment
Write-Host "Ì≥¶ Creating virtual environment..." -ForegroundColor Yellow
python -m venv venv

# Activate it
Write-Host "Ì¥å Activating virtual environment..." -ForegroundColor Yellow
.\venv\Scripts\Activate

# Install requirements
Write-Host "Ì≥• Installing packages from requirements.txt..." -ForegroundColor Yellow
Write-Host "‚è≥ This may take 2-3 minutes..." -ForegroundColor Yellow
pip install -r requirements.txt

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "‚úÖ Setup complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Activate environment: .\venv\Scripts\Activate" -ForegroundColor White
Write-Host "2. Start backend: python qdfx_back/main.py" -ForegroundColor White
Write-Host "3. Start Flutter: cd qdfx_front/qdfx_frontend; flutter run -d chrome" -ForegroundColor White
