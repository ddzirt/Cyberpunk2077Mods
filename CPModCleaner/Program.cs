var debugFile = Path.Combine(Environment.CurrentDirectory, "Output.txt");
using (StreamWriter SWriter = new StreamWriter(debugFile))
{
    SWriter.WriteLine("App initiated");
    try
    {
        var ConfigManager = new ConfigManager();
        if (ConfigManager.isDebug)
        {
            var configFileName = "Config.xml";
            var filePath = Environment.CurrentDirectory.Substring(0, Environment.CurrentDirectory.IndexOf("CPModCleaner") + "CPModCleaner".Length);
            var configFile = Directory.GetFiles(filePath, configFileName, SearchOption.TopDirectoryOnly)[0];
            File.Copy(configFile, Path.Combine(Environment.CurrentDirectory, configFileName), true);
        }

        SWriter.WriteLine(string.Format("App configuration: {0}", ConfigManager.isDebug));

        var modTypes = ConfigManager.SupportedModOptions.Select(pair => pair.Value).ToList();
        var filterTypes = ConfigManager.FilterOptions.Select(pair => pair.Value).ToList();
        List<string> files = new List<string>();

        SWriter.WriteLine("App config parsed");

        foreach (string mod in modTypes)
        {
            var filesToCleanUp = Directory.GetFiles(Environment.CurrentDirectory, string.Format("*{0}", mod), SearchOption.AllDirectories).ToList();
            files.AddRange(filesToCleanUp);
        }

        SWriter.WriteLine("App files retrieved");

        foreach (var file in files)
        {
            string tempFile;
            if (ConfigManager.isDebug)
            {
                tempFile = file.Substring(0, file.IndexOf(".")) + "-Test.reds";
            }
            else
            {
                // "D:\\Work\\CPMods\\Projects\\CPModCleaner\\bin\\Debug\\net6.0\\UpgradeWeaponsUnlocked\\r6\\scripts\\UpgradeWeaponsUnlocked\\UpgradeWeaponsUnlocked.reds"
                var fileName = Path.GetFileName(file);
                var newFile = file.Substring(0, file.IndexOf(fileName, file.IndexOf('.') - fileName.Length));
                tempFile = newFile + fileName.Substring(0, fileName.IndexOf('.')) + "Cleaned.reds";
            }

            SWriter.WriteLine(string.Format("App file to clean up: {0}", tempFile));

            using (var sr = new StreamReader(file))
            using (StreamWriter sw = new StreamWriter(tempFile))
            {
                {
                    string line;
                    int checker;
                    while ((line = sr.ReadLine()) != null)
                    {
                        line = line.Trim();
                        if (!string.IsNullOrEmpty(line) && !string.IsNullOrWhiteSpace(line))
                        {
                            checker = 0;
                            foreach (var typeToRemove in filterTypes)
                            {
                                if (!line.StartsWith(typeToRemove))
                                {
                                    checker++;
                                }
                            }

                            if (checker == filterTypes.Count)
                            {
                                sw.WriteLine(line.Trim());
                            }
                        }
                    }
                }
            }

            SWriter.WriteLine(string.Format("App file to cleaned: {0}", tempFile));
        }

        SWriter.WriteLine("App files cleaned");
    }
    catch (Exception e)
    {
        SWriter.WriteLine(string.Format("App crashed with e: {0}", e.Message));
    }
}
