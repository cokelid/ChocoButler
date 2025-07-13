using System;
using System.Windows.Forms;
#if DEBUG
using System.Runtime.InteropServices;
#endif

namespace ChocoButler
{
    static class Program
    {
#if DEBUG
        [DllImport("kernel32.dll")]
        private static extern bool AllocConsole();
#endif
        [STAThread]
        static void Main()
        {
#if DEBUG
            AllocConsole();
#endif
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new TrayAppContext());
        }
    }
} 