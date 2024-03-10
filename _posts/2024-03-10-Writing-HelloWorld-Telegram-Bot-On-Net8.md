---
layout: post
title: "Telegram bot: Начало."
tags:
  - telegram
  - bot
---
# Введение
Я начинаю свой цикл статей о создании Telegram ботов не зря, сам мессенджер за мои 6 лет пребывания в нем активно рос, и с каждым годом я провожу свое выделенное на соц сети время все больше в нем, чем на остальных площадках. Так же у меня накопилось много идей, которые могли бы облегчить/улучшить не только мою жизнь но и окружающих(Скачивание музыки по ссылке с youtube, вытаскивание текста из pdf, to-do...). Да и тем более, это отличная площадка для оттачивания навыков в backend! Мы можем создать нашего бота, распилить на микросервисы, закинуть в докер... Так чего же мы ждем? Давайте начнем с самых азов и постепенно будем усложнять наш проект, изучая много нового и интересного. 
# Регистрируем нашего бота, получаем api токен.
Ничего сложного, пишем https://t.me/BotFather, прописываем команду `/newbot`, называем наш корабль и плывем как по скриншоту.

![](/assets/Pasted%20image%2020240311013201.png)
# Вводные данные для нашего проекта
Впервые я написал бота в сентябре 2019 года... Помню, как приходилось использовать vpn, потому что в то время его активно пытались блокировать всеми силами. Однако я хотел сказать вам другое, а именно, что сама библиотека очень быстро развивается, многие вещи были перенесены/удалены/переименованы. Поиск информации затрудняется от того, какую версию библиотеки, и какую платформу вы используете(chatgpt,SO,gitHub может выдать вам вроде нестарый, но все равно устаревший код, или наоборот, используемые фишки в примерах будут реализованы только в более новых версиях языка C#.).
Потому мы будем использовать консольное приложение на net8.0 и самые свежие ~~овощи~~  библиотеки на текущий момент.
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
	<ImplicitUsings>disable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Telegram.Bot" Version="19.0.0" />
    <PackageReference Include="Telegram.Bots.Extensions.Polling" Version="5.9.0" />
  </ItemGroup>

</Project>

```
# Знакомимся с примитивным кодом.
## 1 Подключим библиотеки, создадим экземпляр, передав в конструктор наш токен, полученный от BotFather.

```cs
static async Task Main(string[] args)
        {
            using var cancellationToken = new CancellationTokenSource();
            var myBot = new TelegramBotClient("Your token...");
            var myBotUser = await myBot.GetMeAsync();
            Console.WriteLine($"Start listening for @{myBotUser.Username}");
            Console.ReadLine();
            cancellationToken.Cancel();
        }
```

## 2 Получение/обработка сообщений
Получать сообщения мы будем благодаря методу нашего экземпляра StartReceiving(), у него есть несколько перегрузок, выберем с обработками самих сообщений и ошибок, которые являются Action.

```cs
            myBot.StartReceiving(
                // обработка поступающих сообщений,
                // обработка поступающих ошибок,
                new ReceiverOptions(),
                cancellationToken.Token);
```

Теперь нам остается написать собственные обработчики сообщений. Создадим класс UserMessageHandler, реализующий нужные нам методы

```cs
public class UserMessageHandler
    {
        public async Task HandleUpdateAsync(
            ITelegramBotClient botClient,
            Update update,
            CancellationToken cancellationToken)
        {
            if (update.Message == null)
            {
                Console.WriteLine($"Message is null...");
                return;
            }
            var username = update.Message.Chat.Username;
            var messageText = update.Message.Text;

            if (username == null)
            {
                Console.WriteLine($"Username is null...");
                return;
            }
            if (messageText == null)
            {
                Console.WriteLine($"MessageText is null...");
                return;
            }
            if (update.Message.From == null)
            {
                Console.WriteLine($"User is null...");
                return;
            }
            Console.WriteLine($"Message: '{messageText}' | Username: {username})");
            await botClient.SendTextMessageAsync(update.Message.From.Id, "Test!");
        }

        public async Task HandleErrorAsync(
            ITelegramBotClient botClient,
            Exception exception,
            CancellationToken cancellationToken)
        {
            Console.WriteLine($"Exception: '{exception}'");
        }
    }
```
## 3 Итоговый код
```cs
using System;
using System.Threading.Tasks;
using System.Threading;
using Telegram.Bot;
using Telegram.Bot.Polling;
using Telegram.Bot.Types;

namespace TestBot
{
    internal class Program
    {
        static async Task Main(string[] args)
        {
            using var cancellationToken = new CancellationTokenSource();
            var myBot = new TelegramBotClient("Your token...");
            
            UserMessageHandler handleService = new UserMessageHandler();

            myBot.StartReceiving(
                handleService.HandleUpdateAsync,
                handleService.HandleErrorAsync,
                new ReceiverOptions(),
                cancellationToken.Token);

            var myBotUser = await myBot.GetMeAsync();

            Console.WriteLine($"Start listening for @{myBotUser.Username}");
            Console.ReadLine();

            cancellationToken.Cancel();
        }
    }
    public class UserMessageHandler
    {
        public async Task HandleUpdateAsync(
            ITelegramBotClient botClient,
            Update update,
            CancellationToken cancellationToken)
        {
            if (update.Message == null)
            {
                Console.WriteLine($"Message is null...");
                return;
            }
            var username = update.Message.Chat.Username;
            var messageText = update.Message.Text;

            if (username == null)
            {
                Console.WriteLine($"Username is null...");
                return;
            }
            if (messageText == null)
            {
                Console.WriteLine($"MessageText is null...");
                return;
            }
            if (update.Message.From == null)
            {
                Console.WriteLine($"User is null...");
                return;
            }
            Console.WriteLine($"Message: '{messageText}' | Username: {username})");
            // Отправляем тестовое сообщение пользователю.
            await botClient.SendTextMessageAsync(update.Message.From.Id, "Test!");
        }

        public async Task HandleErrorAsync(
            ITelegramBotClient botClient,
            Exception exception,
            CancellationToken cancellationToken)
        {
            Console.WriteLine($"Exception: '{exception}'");
        }
    }
}
```

Результат:

![](/assets/Pasted%20image%2020240311021740.png)
# Подведем итоги
Данный пример послужит нам одной из отправных точек для наших будущих сервисов(есть еще вариант через ihostbuilder, но это позже). В следующем посте мы затронем состояния пользователей, благодаря чему мы сможем взаимодействовать с разными пользователями в зависимости от их предыдущих ответов.

Надеюсь пост был для вас полезен, до скорых встреч!

