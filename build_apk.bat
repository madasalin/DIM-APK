@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

echo ============================================================
echo    DIM Android - push to GitHub to auto-build APK
echo    (GitHub Actions builds app-release.apk for you)
echo ============================================================
echo.

REM --- check git ---
where git >nul 2>nul
if errorlevel 1 (
  echo [ERROR] git is not installed. Install from https://git-scm.com then retry.
  pause & exit /b 1
)

REM --- 1) restore dot-prefix: github -> .github, gitignore -> .gitignore ---
if exist "github" (
  if not exist ".github" (
    echo [1/6] restoring github  -^> .github
    ren "github" ".github"
  )
) else (
  echo [1/6] .github OK
)
if exist "gitignore" (
  if not exist ".gitignore" (
    echo       restoring gitignore -^> .gitignore
    ren "gitignore" ".gitignore"
  )
)
echo.

REM --- 2) init git repo if needed ---
if not exist ".git" (
  echo [2/6] git init
  git init >nul
) else (
  echo [2/6] git repo OK
)
echo.

REM --- 3) check origin remote / ask URL only once ---
git remote get-url origin >nul 2>nul
if errorlevel 1 (
  echo [3/6] No GitHub remote set.
  echo       example: https://github.com/USERNAME/REPO.git
  set /p REPO_URL="      Enter repository URL: "
  if "!REPO_URL!"=="" (
    echo [ERROR] empty URL. abort.
    pause & exit /b 1
  )
  git remote add origin "!REPO_URL!"
  echo       origin set: !REPO_URL!
) else (
  for /f "delims=" %%u in ('git remote get-url origin') do set REPO_URL=%%u
  echo [3/6] origin OK: !REPO_URL!
)
echo.

REM --- 4) use main branch ---
echo [4/6] set branch main
git branch -M main
echo.

REM --- 5) ensure git identity (commit needs a name/email) ---
git config user.email >nul 2>nul
if errorlevel 1 (
  echo [5/6] git identity not set - configuring for this repo
  git config user.email "dongtan9dong@gmail.com"
  git config user.name "madasalin"
) else (
  echo [5/6] git identity OK
)

REM --- commit everything ---
echo       commit changes
git add -A
git commit -m "DIM mobile - apply latest DMD.py algorithm (%date% %time%)"
if errorlevel 1 (
  echo       (no new changes to commit - continue)
)
echo.

REM --- 6) push -> triggers GitHub Actions build ---
echo [6/6] push to GitHub (Actions will build the APK)
git push -u origin main
if errorlevel 1 (
  echo.
  echo [WARN] push failed. check:
  echo   - repo URL correct / you are logged in with access
  echo   - if remote already has commits:
  echo       git pull origin main --allow-unrelated-histories
  pause & exit /b 1
)

echo.
echo ============================================================
echo   DONE! Get the APK from your GitHub repo:
echo   - Actions tab - latest run - Artifacts (dim-mobile-apk), or
echo   - Releases tab - app-release.apk
echo ============================================================
echo.
pause
