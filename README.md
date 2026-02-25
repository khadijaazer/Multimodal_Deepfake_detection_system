# Deepfake Detection System

## Ì∫Ä Quick Start

### For Windows Users
```powershell
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/Deepfake_detection_system.git
cd Deepfake_detection_system

# 2. Run setup (creates environment and installs packages)
.\setup.ps1

# 3. Start the backend
cd qdfx_back
python main.py

# 4. In a new terminal, start Flutter
cd qdfx_front/qdfx_frontend
flutter run -d chrome
```

### For Mac/Linux Users
```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/Deepfake_detection_system.git
cd Deepfake_detection_system

# 2. Run setup
chmod +x setup.sh
./setup.sh

# 3. Start the backend
cd qdfx_back
python main.py

# 4. In a new terminal, start Flutter
cd qdfx_front/qdfx_frontend
flutter run -d chrome
```

## Ì≥¶ What's Included
- ‚úÖ **Backend**: FastAPI server with ML models
- ‚úÖ **Frontend**: Flutter web app

## Ì¥ß Requirements
- Python 3.11 or 3.12
- Flutter SDK
- Chrome browser

## Ì¥ù Contributing
1. Pull latest changes
2. Activate virtual environment: `source venv/bin/activate` (or `.\venv\Scripts\Activate` on Windows)
3. Install new packages: `pip install package-name`
4. Update requirements: `pip freeze > requirements.txt`
5. Commit and push

## Ì≥ù Notes
- Models are loaded from Hugging Face automatically
- First run may take 2-5 minutes to download models
- All model files are cached locally after first download
