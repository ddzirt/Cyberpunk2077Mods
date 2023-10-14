call Config.bat

@echo off

echo %1

if "%1" == "specific" (
  echo Release for: %2

  :: Delete old release zip
  IF EXIST %pathTo%\%2.zip (
    echo Delete previous zip
    del /q %pathTo%\%2.zip
  )
  :: Delete folder if it exists for some reason
  IF EXIST %pathTo%\%2 (
    echo Delete previous folder if exists
    rmdir /s /q %pathTo%\%2\
  )
  :: And now we recreate folder to do our logic
  IF NOT EXIST %pathTo% (
    echo Create new temp folder 
    mkdir %pathTo%
  )
  :: Add a copy of mod
  echo Copy mod
  Robocopy "%pathFrom%\%2" "%pathTo%\%2" /E > nul
  :: Clean it up
  if "%cleanNonModFiles%" == "true" (
    echo Clean it up if set in config
    del /s /q /f %pathTo%\*.md
    rmdir /s /q %pathTo%\%2\Media
  )
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


@REM pause

@REM IF %cleanNonModFiles% == true (
@REM     echo %cleanNonModFiles%
@REM )

@REM IF %cleanModFiles% == true (
@REM     echo %cleanModFiles%
@REM )

:: echo %pathFrom%
:: echo %pathTo%