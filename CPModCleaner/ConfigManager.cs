using System.Xml.Linq;
public class ConfigManager
{
    public ConfigManager()
    {
        if (Config == null)
        {
            string fileName = "Config.xml";
            string path = Path.Combine(Environment.CurrentDirectory, fileName);

            try
            {
                XDocument doc = XDocument.Load(path);
                Config = doc;

                InitiateConfigValues(doc);
            }
            catch (Exception e)
            {
                Console.WriteLine($"Processing failed: {e.Message}");
            }
        }
    }
    public ConfigManager(XDocument config)
    {
        Config ??= config;
    }

    public bool isDebug
    {
        get { return _isDebug; }
        set { _isDebug = value; }
    }
    private bool _isDebug = true;

    public XDocument? Config { get; set; }

    public Dictionary<string, string>? FilterOptions { get; set; }
    public Dictionary<string, string>? SupportedModOptions { get; set; }

    private void InitiateConfigValues(XDocument doc)
    {
        ReadConfigs(doc);
    }

    public void ReadConfigs(XDocument? doc)
    {
        if (Config != null || doc != null)
        {
            var rootDebug = Config.Root.Attribute("isDebug");
            _isDebug = rootDebug == null ? true : Convert.ToBoolean(rootDebug.Value);

            var settings = Config.Descendants("removeSettings").Descendants().Select(i => new KeyValuePair<string, string>(i.Attribute("name").Value.ToString(),
                i.Attribute("value").Value.ToString())).ToList();

            FilterOptions = settings.ToDictionary(pair => pair.Key, pair => pair.Value);

            var mods = Config.Descendants("supportedModTypes").Descendants().Select(i => new KeyValuePair<string, string>(i.Attribute("name").Value.ToString(),
                i.Attribute("fileType").Value.ToString())).ToList();

            SupportedModOptions = mods.ToDictionary(pair => pair.Key, pair => pair.Value);
        }
    }
}