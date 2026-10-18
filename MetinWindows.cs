using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using System.IO;
using System.Media;

public static class MetinWindows {
    public sealed class Entry {
        public string handle;
        public int pid;
        public string started;
        public string title;
        public bool minimized;
    }
    private delegate bool EnumProc(IntPtr hwnd, IntPtr arg);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumProc callback, IntPtr arg);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int max);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr hwnd, int cmd);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll", SetLastError=true)] private static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [StructLayout(LayoutKind.Sequential)] private struct Rect { public int L,T,R,B; }
    private static int highlightVersion;

    public static Entry[] List() {
        var entries = new List<Entry>();
        EnumWindows(delegate(IntPtr hwnd, IntPtr arg) {
            if (!IsWindowVisible(hwnd)) return true;
            uint id; GetWindowThreadProcessId(hwnd, out id);
            try {
                using (var p = Process.GetProcessById((int)id)) {
                    if (!String.Equals(p.ProcessName, "metin2client", StringComparison.OrdinalIgnoreCase)) return true;
                    var title = new StringBuilder(2048);
                    GetWindowText(hwnd, title, title.Capacity);
                    entries.Add(new Entry { handle=hwnd.ToInt64().ToString(), pid=(int)id,
                        started=p.StartTime.ToUniversalTime().Ticks.ToString(),
                        title=title.Length == 0 ? "Metin2" : title.ToString(), minimized=IsIconic(hwnd) });
                }
            } catch (System.ComponentModel.Win32Exception) { }
              catch (InvalidOperationException) { }
              catch (ArgumentException) { }
            return true;
        }, IntPtr.Zero);
        entries.Sort((a,b) => { int c=a.pid.CompareTo(b.pid); return c!=0 ? c : String.CompareOrdinal(a.handle,b.handle); });
        return entries.ToArray();
    }
    private static IntPtr Resolve(string handle, int pid, string started) {
        foreach (var e in List())
            if (e.handle == handle && e.pid == pid && e.started == started) return new IntPtr(Int64.Parse(handle));
        throw new InvalidOperationException("Dieses Metin2-Fenster ist nicht mehr vorhanden oder kann nicht gelesen werden. Bitte aktualisieren und gegebenenfalls den Helper als Administrator starten.");
    }
    public static void Close(string handle, int pid, string started) {
        Resolve(handle,pid,started);
        try {
            using(var process=Process.GetProcessById(pid)) {
                // Retain the OS process handle before verifying identity; a recycled
                // PID must never redirect the termination to another process.
                if(process.Handle==IntPtr.Zero || process.HasExited ||
                    !String.Equals(process.ProcessName,"metin2client",StringComparison.OrdinalIgnoreCase) ||
                    process.StartTime.ToUniversalTime().Ticks.ToString()!=started)
                    throw new InvalidOperationException("Der ausgewaehlte Metin2-Prozess ist nicht mehr vorhanden. Bitte die Fensterliste aktualisieren.");
                process.Kill();
                if(!process.WaitForExit(3000))
                    throw new InvalidOperationException("Beenden wurde ausgeloest, aber der Prozess ist noch aktiv. Bitte aktualisieren und den Prozess im Task-Manager pruefen.");
            }
        } catch(System.ComponentModel.Win32Exception) {
            throw new InvalidOperationException("Metin2 konnte nicht beendet werden. Bitte den Helper mit Rechtsklick als Administrator starten, wenn Metin2 mit erhoehten Rechten laeuft.");
        } catch(ArgumentException) {
            throw new InvalidOperationException("Dieses Metin2-Fenster wurde bereits geschlossen. Bitte aktualisieren.");
        }
    }
    public static void Highlight(string handle, int pid, string started) {
        var hwnd=Resolve(handle,pid,started);
        if (IsIconic(hwnd)) ShowWindowAsync(hwnd,9);
        SetForegroundWindow(hwnd);
        int version=Interlocked.Increment(ref highlightVersion);
        var thread=new Thread(delegate() {
            using(var frame = new HighlightFrame())
            using(var timer = new System.Windows.Forms.Timer()) {
                var clock=Stopwatch.StartNew();
                timer.Interval=40;
                timer.Tick += delegate {
                    Rect r;
                    uint currentPid; GetWindowThreadProcessId(hwnd,out currentPid);
                    if (version!=highlightVersion || clock.ElapsedMilliseconds>1600 || currentPid!=(uint)pid || !IsWindowVisible(hwnd)) { frame.Close(); return; }
                    if (!GetWindowRect(hwnd,out r) || IsIconic(hwnd)) { frame.Hide(); return; }
                    frame.Bounds=new Rectangle(r.L,r.T,Math.Max(8,r.R-r.L),Math.Max(8,r.B-r.T));
                    var region=new Region(new Rectangle(0,0,frame.Width,frame.Height));
                    region.Exclude(new Rectangle(4,4,Math.Max(0,frame.Width-8),Math.Max(0,frame.Height-8)));
                    var old=frame.Region; frame.Region=region; if(old!=null)old.Dispose();
                    if(!frame.Visible)frame.Show();
                };
                timer.Start();
                Application.Run(frame);
            }
        });
        thread.IsBackground=true;
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
    }
    private sealed class HighlightFrame : Form {
        public HighlightFrame() { FormBorderStyle=FormBorderStyle.None; ShowInTaskbar=false; TopMost=true; BackColor=Color.FromArgb(174,118,255); StartPosition=FormStartPosition.Manual; Bounds=new Rectangle(-32000,-32000,8,8); }
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams { get { var p=base.CreateParams; p.ExStyle |= 0x08000000 | 0x20 | 0x80; return p; } }
    }
}

// Runs independently of the WebView, including while the app is minimized.
public static class HelperMonitor {
    private static readonly object gate=new object();
    private static System.Threading.Timer worker;
    private static Dictionary<string,MetinWindows.Entry> known=new Dictionary<string,MetinWindows.Entry>();
    private static Dictionary<string,int> missing=new Dictionary<string,int>();
    private static Dictionary<string,DateTime> intentional=new Dictionary<string,DateTime>();
    private static Dictionary<string,long> deadlines=new Dictionary<string,long>();
    private static HashSet<string> fired=new HashSet<string>();
    private static List<string> events=new List<string>();
    private static bool initialized, windowSound=true, timerSound=true;
    public static void Start(bool windows, bool timers) {
        lock(gate) { windowSound=windows;timerSound=timers; }
        worker=new System.Threading.Timer(Tick,null,0,1000);
    }
    public static void Settings(bool windows,bool timers) { lock(gate){windowSound=windows;timerSound=timers;} }
    public static void SetTimers(string[] ids,long[] times) {
        lock(gate) {
            var next=new Dictionary<string,long>();
            for(int i=0;i<ids.Length;i++) {
                next[ids[i]]=times[i];
                long old;
                if(!deadlines.TryGetValue(ids[i],out old)||old!=times[i]) {
                    fired.Remove(ids[i]);
                    // Timers already expired on app launch are displayed without a stale alarm.
                    if(times[i]<=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds())fired.Add(ids[i]);
                }
            }
            deadlines=next;
            fired.RemoveWhere(id=>!next.ContainsKey(id));
        }
    }
    public static void Close(string handle,int pid,string started) {
        lock(gate) {
            string key=handle+":"+pid+":"+started;
            intentional[key]=DateTime.UtcNow.AddSeconds(30);
            try { MetinWindows.Close(handle,pid,started); }
            catch { intentional.Remove(key);throw; }
        }
    }
    public static string[] Events() { lock(gate){return events.ToArray();} }
    private static void Record(string text) { events.Insert(0,DateTime.Now.ToString("HH:mm:ss")+" · "+text);if(events.Count>15)events.RemoveAt(events.Count-1); }
    private static void Tick(object state) {
        bool play=false;
        try {
            lock(gate) {
                var current=new Dictionary<string,MetinWindows.Entry>();
                foreach(var e in MetinWindows.List())current[e.handle+":"+e.pid+":"+e.started]=e;
                if(initialized) {
                    var keep=new Dictionary<string,MetinWindows.Entry>(current);
                    bool lost=false;
                    foreach(var pair in known) {
                        if(current.ContainsKey(pair.Key)){missing.Remove(pair.Key);continue;}
                        int count;missing.TryGetValue(pair.Key,out count);missing[pair.Key]=++count;
                        if(count<2){keep[pair.Key]=pair.Value;continue;}
                        DateTime until;
                        bool expected=intentional.TryGetValue(pair.Key,out until)&&until>DateTime.UtcNow;
                        if(!expected){Record(pair.Value.title+" (PID "+pair.Value.pid+") ist verschwunden.");lost=true;}
                        intentional.Remove(pair.Key);missing.Remove(pair.Key);
                    }
                    known=keep;
                    if(lost&&windowSound)play=true;
                }else{known=current;initialized=true;}
                var expired=new List<string>();
                foreach(var p in intentional)if(p.Value<DateTime.UtcNow)expired.Add(p.Key);
                foreach(var key in expired)intentional.Remove(key);
                long now=DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                foreach(var p in deadlines)if(p.Value<=now&&fired.Add(p.Key)) { Record("Ein Timer ist abgelaufen.");if(timerSound)play=true; }
            }
            if(play)PlayTone();
        } catch { /* Keep the last successful snapshot if enumeration fails. */ }
    }
    public static void TestTone() { System.Threading.ThreadPool.QueueUserWorkItem(delegate(object state){try{PlayTone();}catch{}}); }
    private static void PlayTone() {
        const int rate=22050,count=4851;
        using(var stream=new MemoryStream()) {
            using(var writer=new BinaryWriter(stream,Encoding.UTF8,true)) {
                writer.Write(Encoding.ASCII.GetBytes("RIFF"));writer.Write(36+count*2);writer.Write(Encoding.ASCII.GetBytes("WAVEfmt "));
                writer.Write(16);writer.Write((short)1);writer.Write((short)1);writer.Write(rate);writer.Write(rate*2);writer.Write((short)2);writer.Write((short)16);
                writer.Write(Encoding.ASCII.GetBytes("data"));writer.Write(count*2);
                for(int i=0;i<count;i++) {
                    double t=(double)i/rate,fade=Math.Sin(Math.PI*i/count);
                    double wave=(Math.Sin(2*Math.PI*660*t)+0.35*Math.Sin(2*Math.PI*880*t))*fade*fade;
                    writer.Write((short)(wave*2400));
                }
            }
            stream.Position=0;using(var player=new SoundPlayer(stream)){player.PlaySync();}
        }
    }
}

public static class TimerOverlay {
    private static readonly object gate=new object();
    private static string[] names=new string[0], states=new string[0];
    private static long[] ends=new long[0], remaining=new long[0];
    private static bool enabled=true,started;
    public static void Update(bool show,string[] labels,string[] modes,long[] deadlines,long[] rests,string positionFile) {
        lock(gate) {
            enabled=show;names=labels;states=modes;ends=deadlines;remaining=rests;
            if(started)return;started=true;
        }
        var thread=new Thread(delegate() {
            using(var form=new OverlayForm(positionFile))
            using(var timer=new System.Windows.Forms.Timer()) {
                timer.Interval=250;
                timer.Tick+=delegate {
                    var text=new StringBuilder();bool overlayVisible;
                    lock(gate) {
                        overlayVisible=enabled&&names.Length>0;
                        for(int i=0;i<names.Length;i++) {
                            long ms=states[i]=="running"?Math.Max(0,ends[i]-DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()):remaining[i];
                            var duration=TimeSpan.FromMilliseconds(ms);
                            long sec=(long)Math.Ceiling(duration.TotalSeconds);
                            text.Append(names[i]).Append("\n").Append((sec/3600).ToString("00")).Append(":").Append((sec/60%60).ToString("00")).Append(":").Append((sec%60).ToString("00"));
                            if(ms<=0)text.Append("  · Fertig");else if(states[i]=="paused")text.Append("  · Pause");
                            text.Append("\n\n");
                        }
                    }
                    form.SetText(text.ToString().TrimEnd());
                    if(overlayVisible&&!form.Visible)form.Show();else if(!overlayVisible&&form.Visible)form.Hide();
                };
                timer.Start();Application.Run();
            }
        });
        thread.IsBackground=true;thread.SetApartmentState(ApartmentState.STA);thread.Start();
    }
    private sealed class OverlayForm:Form {
        [DllImport("user32.dll")] private static extern bool ReleaseCapture();
        [DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr hwnd,int msg,IntPtr w,IntPtr l);
        private readonly string file;
        private string[] rows=new string[0];
        private int offset;
        private readonly Font titleFont=new Font("Segoe UI",9,FontStyle.Regular);
        private readonly Font clockFont=new Font("Consolas",19,FontStyle.Bold);
        public OverlayForm(string positionFile) {
            file=positionFile;FormBorderStyle=FormBorderStyle.None;TopMost=true;ShowInTaskbar=false;
            BackColor=Color.FromArgb(17,15,24);ForeColor=Color.FromArgb(232,222,250);
            DoubleBuffered=true;StartPosition=FormStartPosition.Manual;Width=236;Height=82;
            Location=new Point(Screen.PrimaryScreen.WorkingArea.Right-256,Screen.PrimaryScreen.WorkingArea.Top+40);
            try {var xy=File.ReadAllText(file).Split(',');var location=new Point(Int32.Parse(xy[0]),Int32.Parse(xy[1]));if(Array.Exists(Screen.AllScreens,screen=>screen.WorkingArea.IntersectsWith(new Rectangle(location,new Size(80,50)))))Location=location;}catch{}
            MouseDown+=Drag;
            MouseWheel+=delegate(object sender,MouseEventArgs e){offset=Math.Max(0,Math.Min(Math.Max(0,rows.Length-6),offset+(e.Delta<0?1:-1)));Invalidate();};
        }
        private static System.Drawing.Drawing2D.GraphicsPath Rounded(RectangleF r,float radius) {
            var path=new System.Drawing.Drawing2D.GraphicsPath();float d=radius*2;
            path.AddArc(r.X,r.Y,d,d,180,90);path.AddArc(r.Right-d,r.Y,d,d,270,90);
            path.AddArc(r.Right-d,r.Bottom-d,d,d,0,90);path.AddArc(r.X,r.Bottom-d,d,d,90,90);path.CloseFigure();return path;
        }
        private void Drag(object sender,MouseEventArgs e) {
            if(e.Button!=MouseButtons.Left)return;ReleaseCapture();SendMessage(Handle,0xA1,new IntPtr(2),IntPtr.Zero);
            try{File.WriteAllText(file,Left+","+Top);}catch{}
        }
        public void SetText(string value) {
            string[] next=value.Length==0?new string[0]:value.Split(new string[]{"\n\n"},StringSplitOptions.RemoveEmptyEntries);
            bool changed=String.Join("\n\n",rows)!=value;
            rows=next;offset=Math.Max(0,Math.Min(Math.Max(0,rows.Length-6),offset));
            int count=Math.Min(6,Math.Max(1,rows.Length));Height=20+count*62;
            if(changed)Invalidate();
        }
        protected override void OnSizeChanged(EventArgs e) {
            base.OnSizeChanged(e);if(Width<20||Height<20)return;
            using(var path=Rounded(new RectangleF(0,0,Width,Height),12)){var old=Region;Region=new Region(path);if(old!=null)old.Dispose();}
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            using(var border=new Pen(Color.FromArgb(91,66,126)))using(var outline=Rounded(new RectangleF(0.5f,0.5f,Width-1,Height-1),12))g.DrawPath(border,outline);
            using(var grip=new SolidBrush(Color.FromArgb(112,93,141)))for(int i=0;i<3;i++)g.FillEllipse(grip,Width/2-9+i*7,7,3,3);
            using(var sf=new StringFormat()){sf.Trimming=StringTrimming.EllipsisCharacter;sf.FormatFlags=StringFormatFlags.NoWrap;
                for(int index=offset;index<Math.Min(rows.Length,offset+6);index++) {
                    int y=18+(index-offset)*62;var lines=rows[index].Split('\n');string title=lines[0],clock=lines.Length>1?lines[1]:"";
                    bool done=clock.Contains("Fertig"),paused=clock.Contains("Pause");string digits=clock.Split(' ')[0];
                    using(var brush=new SolidBrush(Color.FromArgb(169,154,190)))g.DrawString(title,titleFont,brush,new RectangleF(15,y,Width-30,18),sf);
                    using(var brush=new SolidBrush(done?Color.FromArgb(115,220,172):Color.FromArgb(220,196,255)))g.DrawString(digits,clockFont,brush,new RectangleF(13,y+18,166,33),sf);
                    if(done||paused)using(var brush=new SolidBrush(done?Color.FromArgb(115,220,172):Color.FromArgb(182,161,211)))g.DrawString(done?"Fertig":"Pause",titleFont,brush,new PointF(178,y+29));
                    if(index<Math.Min(rows.Length,offset+6)-1)using(var pen=new Pen(Color.FromArgb(42,34,55)))g.DrawLine(pen,14,y+58,Width-14,y+58);
                }
            }
        }
        protected override void Dispose(bool disposing){if(disposing){titleFont.Dispose();clockFont.Dispose();}base.Dispose(disposing);}
        protected override bool ShowWithoutActivation {get{return true;}}
        protected override CreateParams CreateParams {get{var p=base.CreateParams;p.ExStyle|=0x08000000|0x80;return p;}}
    }
}
