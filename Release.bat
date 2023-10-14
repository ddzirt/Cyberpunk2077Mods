call Config.bat

timeout /t 2 /nobreak

@echo off
if "%1" == "specific" (
  echo Release for: %2
  :: Delete old release zip
  IF EXIST %pathTo%\%2.zip (
    echo Delete previous zip
    del /q %pathTo%\%2.zip
  )
  :: Delete folder if it exists
  IF EXIST %pathTo%\%2 (
    echo Delete previous folder if exists
    rmdir /s /q %pathTo%\%2\
  )
  :: And now we recreate folder to do our logic
  IF NOT EXIST %pathTo% (
    echo Create new temp folder 
    mkdir %pathTo%
  )
  :: Now call .exe to clean up actual mod files(currently only redscript)
  if "%cleanModFiles%" == "true" (
    IF EXIST %pathFrom%\CPModCleaner.exe (
      echo Do mod cleaning
      :: Debug only
      IF "%isDebug%" == "true" (
        IF EXIST %pathFrom%\CPModCleaner\Config.xml (
          echo Update config from cleaner proj
          IF EXIST %pathFrom%\Config.xml (
            echo Delete previous config
            del /q /f %pathFrom%\Config.xml
          )
          echo Add new config
          copy "%pathFrom%\CPModCleaner\Config.xml" "%pathFrom%"
          echo.
        )
        IF EXIST %pathFrom%\CPModCleaner\bin\Release\net6.0\CPModCleaner.exe (
          echo Update exe process:
          IF EXIST %pathFrom%\CPModCleaner.exe (
            echo Delete previous exe
            del /q /f %pathFrom%\CPModCleaner.exe
          )
          IF EXIST %pathFrom%\CPModCleaner.dll (
            echo Delete previous dll
            del /q /f %pathFrom%\CPModCleaner.dll
          )
          IF EXIST %pathFrom%\CPModCleaner.runtimeconfig.json (
            echo Delete previous runtimeconfig
            del /q /f %pathFrom%\CPModCleaner.runtimeconfig.json
          )
          echo Add new exe
          copy "%pathFrom%\CPModCleaner\bin\Release\net6.0\CPModCleaner.exe" "%pathFrom%"
          echo Add new dll
          copy "%pathFrom%\CPModCleaner\bin\Release\net6.0\CPModCleaner.dll" "%pathFrom%"
          echo Add new runtimeconfig
          copy "%pathFrom%\CPModCleaner\bin\Release\net6.0\CPModCleaner.runtimeconfig.json" "%pathFrom%"
        )
      )
    )
    :: Run actual exe
    @REM IF EXIST %pathFrom%\CPModCleaner.exe (
    @REM   echo Clean up actual mod files
    @REM   start /B /wait "CPModCleaner" %pathFrom%\CPModCleaner.exe
    @REM )
  )
  :: Add a copy of mod
  echo Copy mod:
  Robocopy "%pathFrom%\%2" "%pathTo%\%2" /E > nul
  echo Mod copied!
  :: Clean it up
  if "%cleanNonModFiles%" == "true" (
      echo Clean it up if set in config
      del /s /q /f %pathTo%\*.md
      rmdir /s /q %pathTo%\%2\Media
  )
  @REM del 
  :: TODO: Add more custom/better clean up logic for this
  :: Zip for release
  echo Run zip: 
  powershell.exe Compress-Archive -Path "%pathTo%\%2\*" %pathTo%\%2.zip
  echo Done, now clean temp folder
  rmdir /s /q %pathTo%\%2\
)

if "%2" == "all" (
  echo Logic is not done ATM
)

pause