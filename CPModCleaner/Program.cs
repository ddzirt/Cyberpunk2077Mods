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

        SWriter.WriteLine(string.Format("App configuration isDebug: {0}", ConfigManager.isDebug));

        var modTypes = ConfigManager.SupportedModOptions.Select(pair => pair.Value).ToList();
        var filterTypes = ConfigManager.FilterOptions.Select(pair => pair.Value).ToList();
        List<string> files = new List<string>();

        SWriter.WriteLine("App config parsed");

        foreach (string mod in modTypes)
        {
            var filesToCleanUp = Directory.GetFiles(Environment.CurrentDirectory, string.Format("*{0}", mod), SearchOption.AllDirectories).ToList();
            files.AddRange(filesToCleanUp);
        }

        List<string> filesAfterIgnoreModOptions = new List<string>();
        if (!ConfigManager.isDebug)
        {
            filesAfterIgnoreModOptions = files.Where(f => !ConfigManager.IgnoreModOptions.Any(fo => f.Contains(fo))).ToList();
        }
        else
        {
            ConfigManager.IgnoreModOptions = ConfigManager.IgnoreModOptions.Where(imo => imo != "bin").ToList();
            filesAfterIgnoreModOptions = files.Where(f => !ConfigManager.IgnoreModOptions.Any(fo => f.Contains(fo)) && !f.Contains("Test")).ToList();
        }

        SWriter.WriteLine("App files retrieved");

        // We can't have previous "Cleaned" copies in our logic
        var filesToDelete = files.Where(f => (f.Contains("Cleaned") || f.Contains("Test"))).ToList();
        if (filesToDelete.Count > 0)
        {
            foreach (var file in filesToDelete)
            {
                try
                {
                    SWriter.WriteLine(string.Format("App file to delete: {0}", file));
                    File.Delete(file);
                }
                catch (Exception e)
                {
                    SWriter.WriteLine("App deleting file crashed: {0}", e.Message);
                }
            }
        }

        SWriter.WriteLine("App files cleaned from previous iterations of app");

        foreach (var file in filesAfterIgnoreModOptions)
        {
            SWriter.WriteLine(string.Format("App file to clean up: {0}", file));

            string newFile;
            if (ConfigManager.isDebug)
            {
                newFile = file.Substring(0, file.IndexOf('.', file.IndexOf('.') + 1)) + "-Test.reds";
            }
            else
            {
                // "D:\\Work\\CPMods\\Projects\\CPModCleaner\\bin\\Debug\\net6.0\\UpgradeWeaponsUnlocked\\r6\\scripts\\UpgradeWeaponsUnlocked\\UpgradeWeaponsUnlocked.reds"
                var fileName = Path.GetFileName(file);
                var newFileName = file.Substring(0, file.IndexOf(fileName, file.IndexOf('.') - fileName.Length));
                newFile = newFileName + fileName.Substring(0, fileName.IndexOf('.')) + "Cleaned.reds";
            }

            using (var sr = new StreamReader(file))
            using (StreamWriter sw = new StreamWriter(newFile, true))
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

            SWriter.WriteLine(string.Format("App file after cleaning up: {0}", newFile));
        }

        SWriter.WriteLine("App files are all cleaned");
    }
    catch (Exception e)
    {
        SWriter.WriteLine(string.Format("App crashed with e: {0}", e.Message));
    }
}
