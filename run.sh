#!/bin/bash

echo "🔄 GitSnap Flutter - Avvio applicazione"
echo "========================================"

# Verifica Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter non trovato!"
    echo "Installa Flutter da: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Installa dipendenze se necessario
if [ ! -d ".dart_tool" ]; then
    echo "📦 Installazione dipendenze..."
    flutter pub get
fi

# Rileva piattaforma
OS="$(uname -s)"
case "${OS}" in
    Linux*)     PLATFORM=linux;;
    Darwin*)    PLATFORM=macos;;
    MINGW*|MSYS*|CYGWIN*)    PLATFORM=windows;;
    *)          PLATFORM="UNKNOWN:${OS}"
esac

echo "🖥️  Piattaforma rilevata: $PLATFORM"
echo ""
echo "Avvio applicazione..."
flutter run -d $PLATFORM

