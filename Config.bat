:: Do we release as is or do we do a clean up files
set cleanNonModFiles=true
:: Do we release as is or do we do a clean up content of files
set cleanModFiles=true

:: Current folder and name of folder where to we save out release
set pathFrom=%cd%
set pathToFolderName=Releases

:: Folders to ignore for release all mods
set foldersToIgnore[0]=Debug200
set foldersToIgnore[1]=Testing

:: Get parent folder and set where to store release
FOR %%a IN ("%pathFrom:~0,-1%") DO set parent=%%~dpa
set pathTo=%parent%%pathToFolderName%