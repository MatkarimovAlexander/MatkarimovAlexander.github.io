---
layout: post
title: Мониторим создание\закрытие процессов с помощью WMI\WQL
---
# Введение
В рамках безопасности нам может пригодится мониторинг определенных вещей, например реестр windows, чтобы пользователь не смог поменять наше приложение по умолчанию, запустить сторонние приложения во время выполнения нашего. Прописать эту логику можно благодаря WMI с помощью WQL.

# Что такое WMI?
WMI (Windows Management Instrumentation) это набор стандартов для управления устройствами и приложениями в операционных системах Windows. WMI позволяет администраторам управлять компонентами и службами Windows через стандартизированный интерфейс, а также собирать информацию о состоянии и параметрах системы. WMI предоставляет доступ к различным системным ресурсам, таким как процессы, службы, события, журналы и многое другое.

# Что такое WQL ?
WQL (Windows Management Instrumentation Query Language) - это язык запросов, используемый для выполнения запросов к информации и данным, хранящимся в Windows Management Instrumentation (WMI). WQL похож на стандартный язык SQL (Structured Query Language), но приспособлен для работы с объектами и данными, предоставляемыми WMI. С помощью WQL администраторы могут выполнять запросы на получение информации о конфигурации и статусе компьютеров, сетевых устройств, процессов и других системных ресурсов, которые поддерживаются WMI.\
# Мониторим Блокнот
Все что нам нужно это написать заранее запрос по WQL, далее создать экземпляр ManagementEventWatcher, закинув в параметр конструктора наш запрос.
После устанавливаем обработчик событий как только наш объект обработает событие.
Создадим задачу для мониторинга и можем запускать наше приложение.
```cs
static void Main(string[] args)
        {
            string procName = "notepad.exe";
            string query = $"SELECT * FROM __InstanceOperationEvent WITHIN 1 " +
                $"WHERE TargetInstance ISA 'Win32_Process' " +
                $"AND (TargetInstance.Name = '{procName}')";
            using (ManagementEventWatcher watcher = new ManagementEventWatcher(query))
            {
                watcher.EventArrived += (sender, e) =>
                {
                    string eventType = e.NewEvent.ClassPath.ClassName;
                    if(eventType.Equals("__InstanceDeletionEvent"))
                    {
                        Console.WriteLine($"Info：{0}", GetInfo(e.NewEvent));
                        ManagementBaseObject targetInstance = (ManagementBaseObject)e.NewEvent.Properties["TargetInstance"].Value;
                        string processName = targetInstance["Name"].ToString();
                        int PID = Convert.ToInt32(targetInstance["ProcessId"]);

                        Console.WriteLine($"{processName} is deleted, his pid is {PID}");
                    }
                    if (eventType.Equals("__InstanceModificationEvent"))
                    {
                        Console.WriteLine($"Info：{0}", GetInfo(e.NewEvent));
                        ManagementBaseObject targetInstance = (ManagementBaseObject)e.NewEvent.Properties["TargetInstance"].Value;
                        string processName = targetInstance["Name"].ToString();
                        int PID = Convert.ToInt32(targetInstance["ProcessId"]);

                        Console.WriteLine($"{processName} is __InstanceModificationEvent, his pid is {PID}");
                    }
                    if (eventType.Equals("__InstanceCreationEvent"))
                    {
                        ManagementBaseObject targetInstance = (ManagementBaseObject)e.NewEvent.Properties["TargetInstance"].Value;
                        string processName = targetInstance["Name"].ToString();
                        int PID = Convert.ToInt32(targetInstance["ProcessId"]);

                        // Получаем командную строку процесса
                        string commandLine = targetInstance["CommandLine"].ToString();

                        Console.WriteLine($"{processName} is __InstanceCreationEvent, his pid is {PID}");
                        Console.WriteLine($"Command Line: {commandLine}");
                    }

                };

                Task monitoringTask = Task.Run(() => watcher.Start());

                Console.WriteLine($"Start monitoring {procName}");

                Console.ReadLine();

                watcher.Stop();
                monitoringTask.Wait();
            }
        }
        static string GetInfo(ManagementBaseObject mobj)
        {
            var instance = (ManagementBaseObject)mobj["TargetInstance"];
            return string.Format("{0}", instance["Name"]);
        }
```

Интересно то что `__InstanceModificationEvent` триггерится даже тогда когда мы передвигаем окно или просто мотаем мышкой в области окна.

![](/assets/Pasted%20image%2020240212015347.png)

![](/assets/Pasted%20image%2020240212015419.png)
# Мониторим События файлов в указанном пути
Для начала ознакомимся с документацией и выполним шаблонный код.
https://learn.microsoft.com/ru-ru/dotnet/api/system.io.filesystemeventhandler?view=net-8.0
![](/assets/Pasted%20image%2020240212020959.png)
Он отрабатывает замечательно, однако вы должны помнить что у вас не получится качественно отлавливать ВСЕ события с файлами в корневой папке(имеется в виду что не только сам диск С но и во всех его подпапках)
Я пытался и по началу у меня шла волна всего и вся(у нас же не только обычные файлы есть, но и temp), но программа быстро прекращала дальнейший отлов как бы я не старался закидывать в очередь, или увеличить время для обработки всех сообщений. Однако в рамках 1 папки дело свое делает.


# Что почитать?
https://learn.microsoft.com/ru-ru/dotnet/api/system.management.managementeventwatcher?view=dotnet-plat-ext-8.0

https://learn.microsoft.com/ru-ru/windows/win32/wmisdk/querying-with-wql

https://learn.microsoft.com/ru-ru/previous-versions/windows/desktop/regprov/system-registry-provider

https://github.com/xme/powershell_scripts/blob/2a8e74927c432963d11dcae9908441943e52ea0c/registerusbevent.ps1

https://learn.microsoft.com/ru-ru/dotnet/api/system.management.wqleventquery?view=dotnet-plat-ext-7.0


https://learn.microsoft.com/en-us/windows/win32/wmisdk/--instanceoperationevent

# Итог
Аналогично можем обрабатывать оперативно изменения в реестре минуя Event Viewer, поскольку он любит зависать.
Сегодня мы поверхностно ознакомились с WMI и WQL, и потому если вы столкнетесь с проблемой мониторинга процессов или событий файлов/ключей реестра, вы сразу вспомните о них.
Надеюсь пост был полезен для вас!