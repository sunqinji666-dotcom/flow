using System.Windows;

namespace Flow;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        XrayCoreManager.Stop();
        base.OnExit(e);
    }
}
