---
layout: post
title: Знакомимся с вариантами межпроцессных взаимодействий
---
# Что такое межпроцессное взаимодействие(ipc)?
IPC (Inter-Process Communication, межпроцессное взаимодействие) — это набор механизмов и протоколов, которые позволяют различным процессам (запущенным программам или потокам выполнения в рамках операционной системы) обмениваться данными и сигналами.

Существует множество различных методов и технологий IPC, каждый из которых имеет свои особенности, преимущества и области применения
https://learn.microsoft.com/ru-ru/windows/win32/ipc/interprocess-communications

Давайте разберем несколько вариантов.
# Вариант 1: Использование буфера обмена для ipc

Название говорит само за себя, представим, что у нас два приложения на Forms(как раз в Windows.Forms есть доступ к буферу обмена(есть и [альтернативный вариант](https://stackoverflow.com/questions/44205260/net-core-copy-to-clipboard), но не будем погружаться в детали .NET)), первое отправляет сообщение, второе - принимает.

```cs
using System.Windows.Forms;

public class ClipboardSender
{
    public static void SendToClipboard(string text)
    {
        Clipboard.SetText(text);
    }
}
```

```cs
using System.Windows.Forms;

public class ClipboardReceiver
{
    public static string ReceiveFromClipboard()
    {
        string text = Clipboard.GetText();
        return text;
    }
}
```
Казалось бы, задача решена, но какой ценой?
1. Буфер обмена общедоступен для всех приложений на пользовательской машине, что может представлять угрозу безопасности.
2. Буфер обмена не является надежным каналом IPC, поскольку данные в нем могут быть перезаписаны другими приложениями.
3. Буфер обмена лучше всего подходит для передачи небольших объемов данных, таких как текст или изображения.
Конечно нам такое не подходит.
# Вариант 2: Socket
Создадим сокет, используя AddressFamily.InterNetwork, SocketType.Stream для ориентированного на соединение потока данных и ProtocolType.Tcp для использования протокола TCP.
Далее привяжем сокет к локальному адресу и порту: Используя IPEndPoint, сокет привязывается к локальному IP-адресу (127.0.0.1) и порту (11000).
Далее будем ждать подключения. После установления соединения сервер читает входящие данные в цикле до тех пор, пока не обнаружит специальную последовательность символов `<EOF>`

## Код проекта, принимающего сообщения


```cs

using System;
using System.Net;
using System.Net.Sockets;
using System.Text;

class Receiver
{
    static void Main(string[] args)
    {
        var listener = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
        var localEndPoint = new IPEndPoint(IPAddress.Loopback, 11000);
        listener.Bind(localEndPoint);
        listener.Listen(10);

        Console.WriteLine("Waiting for a connection...");
        var handler = listener.Accept();

        string data = null;
        byte[] bytes = null;

        while (true)
        {
            bytes = new byte[1024];
            int bytesRec = handler.Receive(bytes);
            data += Encoding.ASCII.GetString(bytes, 0, bytesRec);
            if (data.IndexOf("<EOF>") > -1)
            {
                break;
            }
        }

        Console.WriteLine("Text received : {0}", data);
        handler.Shutdown(SocketShutdown.Both);
        handler.Close();

        Console.WriteLine("\nPress ENTER to continue...");
        Console.ReadLine();
    }
}
```

Аналогично серверу, клиент создает сокет для TCP-соединения.
Подключается к серверу и отправим сообщение.
## Код проекта, отправляющего сообщения
```cs
using System;
using System.Net;
using System.Net.Sockets;
using System.Text;

namespace Sender
{
    class Program
    {
        static void Main(string[] args)
        {
            byte[] bytes = new byte[1024];

            try
            {
                var sender = new Socket(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);
                var remoteEndPoint = new IPEndPoint(IPAddress.Loopback, 11000);

                sender.Connect(remoteEndPoint);
                Console.WriteLine("Socket connected to {0}", sender.RemoteEndPoint.ToString());

                string message = "This is a test message from the sender.<EOF>";
                byte[] msg = Encoding.ASCII.GetBytes(message);

                int bytesSent = sender.Send(msg);
                sender.Shutdown(SocketShutdown.Both);
                sender.Close();
            }
            catch (ArgumentNullException ane)
            {
                Console.WriteLine("ArgumentNullException : {0}", ane.ToString());
            }
            catch (SocketException se)
            {
                Console.WriteLine("SocketException : {0}", se.ToString());
            }
            catch (Exception e)
            {
                Console.WriteLine("Unexpected exception : {0}", e.ToString());
            }

            Console.WriteLine("\n Press any key to continue...");
            Console.ReadKey();
        }
    }
}

```
## Результат
![](/assets/Pasted%20image%2020240304013402.png)

[Подробнее](https://learn.microsoft.com/ru-ru/dotnet/fundamentals/networking/sockets/socket-services)

# Вариант 3 System.IO.Pipes

System.IO.Pipelines — это библиотека в .NET, предоставляющая высокоуровневый API для обработки потоков данных с использованием концепции "каналов" (pipelines). Она разработана для облегчения работы с потоковыми данными таким образом, чтобы минимизировать количество аллокаций памяти и копирования данных.

Создадим консольное приложение на .net 5, отправителя сообщений с позывным Baba.
![](/assets/Pasted%20image%2020240304013434.png)

```cs
using System;
using System.IO;
using System.IO.Pipes;
using System.Threading.Tasks;

namespace PipeBaba
{
    class Program
    {
        static async Task Main(string[] args)
        {
            var pipeServer = new NamedPipeServerStream("KekePipe", PipeDirection.Out);
            while (true)
            {
                Console.WriteLine("Enter a message for Keke.");
                var message = Console.ReadLine();
                if (message == "exit") break;
                await EnterMessage(message, pipeServer);
            }
            Console.Read();
            return;
        }
        private async static Task<bool> EnterMessage(string message, NamedPipeServerStream pipeServer)
        {
            try
            {
                await pipeServer.WaitForConnectionAsync();
                var sw = new StreamWriter(pipeServer);
                sw.AutoFlush = true;
                sw.WriteLine(message);
            }
            catch (IOException e)
            {
                Console.WriteLine(e);
            }
            finally
            {
                Console.WriteLine("Message is sended.");
                pipeServer.Disconnect();
            }

            return true;
        }
    }
}

```

А так же получателя Keke.

![](/assets/Pasted%20image%2020240304013500.png)

```cs
using System;
using System.IO;
using System.IO.Pipes;
using System.Threading.Tasks;

namespace PipeKeke
{
    class Program
    {

        static void Main(string[] args)
        {
            Console.WriteLine("Start listening...");
            var listener = Task.Factory.StartNew(ListenMessagesFromBaba);
            Console.ReadLine();
        }
        public static async Task ListenMessagesFromBaba()
        {
            while (true)
            {
                await using var pipeClient = new NamedPipeClientStream(".", "KekePipe", PipeDirection.In);

                await pipeClient.ConnectAsync();

                using var sr = new StreamReader(pipeClient);

                var message = await sr.ReadLineAsync();

                if (string.IsNullOrEmpty(message))
                {
                    await Task.Delay(1000);
                    continue;
                }
                Console.WriteLine("Message:" + message);
                await Task.Delay(1000);
            }
        }
    }
}

```
### Результат
![](/assets/Pasted%20image%2020240304013516.png)

![](/assets/Pasted%20image%2020240304013526.png)

Однако оба наших проекта используют платформу .Net 5, а может ли эта библиотека быть посредником между приложениями на .NET 5 и .NET Framework?

Может!

Создадим проект на .net framework 4.8.1, назовем его JIJI.

![](/assets/Pasted%20image%2020240304013547.png)

Код отправления и получения сообщений для него будет работать абсолютно так же(главное не забыть поправить using).

Baba(.net 5.0) отправляет сообщение JIJI 

![](/assets/Pasted%20image%2020240304013602.png)

JIJI отправляет сообщение Keke(.net 5.0)

![](/assets/Pasted%20image%2020240304013614.png)

![](/assets/Pasted%20image%2020240304013627.png)

Как вы теперь понимаете, у нас нет преград в рамках отправки/получении сообщений между несколькими процессами, построенными на разных платформах.

# Дополнительная литература

https://learn.microsoft.com/ru-ru/windows/win32/ipc/interprocess-communications

https://learn.microsoft.com/ru-ru/dotnet/standard/io/pipelines

https://habr.com/ru/articles/464921/

https://devblogs.microsoft.com/dotnet/system-io-pipelines-high-performance-io-in-net/
Перевод
https://habr.com/ru/companies/microsoft/articles/423105/

https://metanit.com/sharp/articles/4.php

https://learn.microsoft.com/ru-ru/windows/uwp/communication/interprocess-communication

https://learn.microsoft.com/ru-ru/windows/win32/ipc/pipes

https://learn.microsoft.com/ru-ru/aspnet/core/grpc/interprocess?view=aspnetcore-8.0

https://en.wikipedia.org/wiki/Inter-process_communication

https://learn.microsoft.com/ru-ru/dotnet/standard/io/pipe-operations

# Итог
Мы познакомились с несколькими способами реализации ipc на c#, а так же с преимуществами pipelines.

Надеюсь пост был для вас познавательным и полезным.
До новых встреч!