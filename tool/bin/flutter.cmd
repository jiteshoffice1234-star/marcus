@echo off
rem Project-local Flutter wrapper: uses the workspace SDK and a local pub cache.
rem The SDK is a release zip and this machine has no git, so pin the engine version
rem (read from bin/internal/engine.version) to bypass git-based version detection.
set "PUB_CACHE=%~dp0..\..\.tooling\pub-cache"
set /p FLUTTER_PREBUILT_ENGINE_VERSION=<"%~dp0..\..\.tooling\flutter\bin\internal\engine.version"
call "%~dp0..\..\.tooling\flutter\bin\flutter.bat" %*
