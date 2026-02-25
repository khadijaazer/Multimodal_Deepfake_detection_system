#!/bin/bash
echo "======================================"
echo "Ì∫Ä Setting up Deepfake Detection System"
echo "======================================"
echo ""

# Create virtual environment
echo "Ì≥¶ Creating virtual environment..."
python3 -m venv venv

# Activate it
echo "Ì¥å Activating virtual environment..."
source venv/bin/activate

# Install requirements
echo "Ì≥• Installing packages from requirements.txt..."
echo "‚è≥ This may take 2-3 minutes..."
pip install -r requirements.txt

echo ""
echo "======================================"
echo "‚úÖ Setup complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Activate environment: source venv/bin/activate"
echo "2. Start backend: python qdfx_back/main.py"
echo "3. Start Flutter: cd qdfx_front/qdfx_frontend; flutter run -d chrome"
