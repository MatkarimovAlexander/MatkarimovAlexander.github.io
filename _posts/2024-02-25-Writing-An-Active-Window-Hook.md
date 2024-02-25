---
layout: post
title: Пишем перехватчик активного окна в Windows
---
# Введение
Всем привет! В рамках разработки приложения на C# под Windows в узкоспециализированных задачах нам может потребоваться отслеживание активного окна и его process Id, так давайте напишем его!

# Ингредиенты
Начнем с того, что нам нужно написать нашу утилиту не через консольное приложение, а именно в том, где есть цикл сообщений, т.е WinForm

```
The client thread that calls **SetWinEventHook** must have a message loop in order to receive events.
```

Самой главной функцией будет [SetWinEventHook](https://learn.microsoft.com/ru-ru/windows/win32/api/winuser/nf-winuser-setwineventhook?redirectedfrom=MSDN).
Вкратце он устанавливает глобальный хук события, который позволяет приложению получать уведомления о различных событиях системы, таких как активация окон.

Вызовем ее с помощью технологии Platform Invocation Services [(P/Invoke)](https://learn.microsoft.com/ru-ru/dotnet/api/system.runtime.interopservices.dllimportattribute?view=net-8.0)

Поскольку нам нужно мониторить все окна, из всех потоков и процессов, то мы должны указать `idProcess` и `idThread` как 0.
```
Если параметр _idProcess_ не равен нулю, а _idThread_ равен нулю, функция перехватчика получает указанные события из всех потоков в этом процессе. Если параметр _idProcess_ равен нулю, а _idThread_ — ненулевому, функция перехватчика получает указанные события только из потока, заданного _idThread_. Если оба значения равны нулю, функция-перехватчик получает указанные события из всех потоков и процессов.
```
Рассмотрим внимательнее данный [раздел](https://learn.microsoft.com/en-us/windows/win32/winauto/event-constants), в котором описаны события, генерируемые операционной системой и серверными приложениями.
Из массы констант нам потребуется 0x0003(т.е 3) означающая EVENT_SYSTEM_FOREGROUND
```
Окно переднего плана изменилось. Система отправляет это событие, даже если окно переднего плана изменилось на другое окно в том же потоке. Серверные приложения никогда не отправляют данное событие.
```
Так же мы должны указать что наш перехватчик должен быть ВНЕ контекста, а не В,[подробнее](https://learn.microsoft.com/ru-ru/windows/win32/winauto/in-context-and-out-of-context-hook-functions)


Следовательно должны выбрать WINEVENT_OUTOFCONTEXT.

Значение константы в справочнике я не смог найти, однако наткнулся на нее в [интересном посте со схожей тематикой](https://www.manhunter.ru/assembler/1536_perehvat_i_obrabotka_izmeneniya_zagolovka_okna_drugogo_prilozheniya.html)

Благодарен вам.
Тык.
<a href="https://www.manhunter.ru" target="_blank"><img src="https://www.manhunter.ru/images/button.gif" alt="Личный блог ManHunter'а" title="Личный блог ManHunter'а" width="88" height="31" /></a>

Поскольку у нас WINEVENT_OUTOFCONTEXT, следовательно, hmodWinEventProc должен быть IntPtr.Zero

Последнее pfnWinEventProc является ссылкой на делегат
напишем его по [образу и подобию](https://learn.microsoft.com/ru-ru/windows/win32/api/winuser/nc-winuser-wineventproc)

```cs
public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);
```

Все что нам остается получить process id и имя процесса с помощью этой [функции](https://learn.microsoft.com/ru-ru/windows/win32/api/winuser/nf-winuser-getwindowthreadprocessid)

Теперь напишем логику обработки события когда окно поменялось

```cs
public void WinEventProc(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime)
    {
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);

        string processName = Process.GetProcessById((int)pid).ProcessName;

        OnActiveWindowChanged(hwnd, (int)pid, processName);
    }
    
protected virtual void OnActiveWindowChanged(IntPtr hwnd, int pid, string processName)
    {
        ActiveWindowChanged?.Invoke(this, new ActiveWindowChangedEventArgs { Hwnd = hwnd, ProcessId = pid, ProcessName = processName });
    }
    
```
сделаем публичное событие

```cs
public event EventHandler<ActiveWindowChangedEventArgs> ActiveWindowChanged;
```

Оформим в отдельный класс
```cs
public class ActiveWindowChangedEventArgs : EventArgs
{
    public IntPtr Hwnd { get; set; }
    public int ProcessId { get; set; }
    public string ProcessName { get; set; }
}

public class ActiveWindowTracker
{
    [DllImport("user32.dll")]
    public static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr hmodWinEventProc, WinEventDelegate lpfnWinEventProc, uint idProcess, uint idThread, uint dwFlags);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    private const uint WINEVENT_OUTOFCONTEXT = 0;
    private const uint EVENT_SYSTEM_FOREGROUND = 3;

    public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);

    public event EventHandler<ActiveWindowChangedEventArgs> ActiveWindowChanged;

    // Сохраняем ссылку на делегат, чтобы предотвратить его удаление сборщиком мусора
    private WinEventDelegate dele;
    private readonly Thread _threadSafe;

    public ActiveWindowTracker()
    {
        dele = new WinEventDelegate(WinEventProc);
        // Запускаем SetWinEventHook в отдельном потоке
        var newDele = new Thread(() =>
         {
             SetWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, IntPtr.Zero, dele, 0, 0, WINEVENT_OUTOFCONTEXT);
             
             // Запускаем цикл обработки сообщений, чтобы предотвратить завершение потока
             System.Windows.Forms.Application.Run();

         });
        newDele.Start();
        _threadSafe = newDele;
    }

    public void WinEventProc(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime)
    {
        uint pid;
        GetWindowThreadProcessId(hwnd, out pid);

        string processName = Process.GetProcessById((int)pid).ProcessName;

        OnActiveWindowChanged(hwnd, (int)pid, processName);
    }

    protected virtual void OnActiveWindowChanged(IntPtr hwnd, int pid, string processName)
    {
        ActiveWindowChanged?.Invoke(this, new ActiveWindowChangedEventArgs { Hwnd = hwnd, ProcessId = pid, ProcessName = processName });
    }
}
```

Последний штрих, вызовем наш класс, запустив задачу.
```cs
internal static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            Task.Run(() => {
                ActiveWindowTracker tracker = new ActiveWindowTracker();
                tracker.ActiveWindowChanged += (sender, e) => Console.WriteLine($"Thread: {System.Threading.Thread.CurrentThread}Window activated: {e.Hwnd}, PID: {e.ProcessId}, Process Name: {e.ProcessName}");
            });
            
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            //Application.Run(new Form1());
        }
    }
```

Давайте запустим и оценим наш результат.
![](assets/2024-02-26-02-08-03.gif)
Надеюсь, пост был полезен и познавательным для вас.
А на сегодня все, до новых встреч!

