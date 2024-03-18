Оставим нашего бота в покое на данный момент, поговорим не о функциональности приложения, а о сценариях обработки сообщения пользователя.

Давайте выберем простой пример и разберем его, калькулятор.
```cs
static void Main(string[] args)
{
    Console.WriteLine("Simple Calculator");

    double firstNumber = GetNumberFromUser("Please write the first number: ");
    double secondNumber = GetNumberFromUser("Please write the second number: ");
    char operation = GetOperationFromUser("Please write the operation (+, -, *, /): ");

    double result = PerformOperation(firstNumber, secondNumber, operation);
    Console.WriteLine($"Result: {firstNumber} {operation} {secondNumber} = {result}");
    Console.Read();
}
static double GetNumberFromUser(string prompt)
{
    double number;
    Console.Write(prompt);

    while (!double.TryParse(Console.ReadLine(), out number))
    {
        Console.WriteLine("Invalid input. Please enter a valid number.");
        Console.Write(prompt);
    }

    return number;
}

static char GetOperationFromUser(string prompt)
{
    Console.Write(prompt);
    string input = Console.ReadLine();

    while (string.IsNullOrEmpty(input) || "+-*/".IndexOf(input[0]) == -1)
    {
        Console.WriteLine("Invalid operation. Please enter a valid operation (+, -, *, /).");
        Console.Write(prompt);
        input = Console.ReadLine();
    }

    return input[0];
}

static double PerformOperation(double firstNumber, double secondNumber, char operation)
{
    switch (operation)
    {
        case '+':
            return firstNumber + secondNumber;
        case '-':
            return firstNumber - secondNumber;
        case '*':
            return firstNumber * secondNumber;
        case '/':
            if (secondNumber == 0)
            {
                Console.WriteLine("Division by zero is not allowed.");
                return 0;
            }
            return firstNumber / secondNumber;
        default:
            Console.WriteLine("Invalid operation.");
            return 0;
    }
}
```

Абсолютно банально, но как нам перенести эту логику в нашего телеграм бота? Как нам двигаться дальше по сценарию, от чего нам отталкиваться? Добавим на данный момент состояния.
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

            // Инициализируем нашего бота, передав в конструктор токен.
            var myBot = new TelegramBotClient("Your_Token");
            
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
        public CalculationStates currentState { get; set; }
        public double firstNumber { get; set; }
        public double secondNumber { get; set; }
        
        public UserMessageHandler()
        {
            this.currentState = CalculationStates.Greetings;
        }
        
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
            if (currentState.Equals(CalculationStates.Greetings))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the first number");
                currentState = CalculationStates.SetFirstNumber;
                return;
            }

            // Ввод первого числа.
            if (currentState.Equals(CalculationStates.SetFirstNumber) && Double.TryParse(messageText,out double parsedFirstNumber))
            {
                firstNumber = parsedFirstNumber;
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the second number");
                currentState = CalculationStates.SetSecondNumber;
                return;
            }
            if (currentState.Equals(CalculationStates.SetFirstNumber))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the correct number");
                return;
            }

            // Ввод второго числа.
            if (currentState.Equals(CalculationStates.SetSecondNumber) && Double.TryParse(messageText, out double parsedSecondNumber))
            {
                secondNumber = parsedSecondNumber;
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the operation");
                currentState = CalculationStates.SetOperation;
                return;
            }
            if (currentState.Equals(CalculationStates.SetSecondNumber))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the correct number");
                return;
            }

            // Ввод второго числа.
            if (currentState.Equals(CalculationStates.SetOperation))
            {
                switch (messageText[0])
                {
                    case '+':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber + secondNumber}");
                        return;
                    case '-':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber - secondNumber}");
                        return;
                    case '*':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber * secondNumber}");
                        return;
                    case '/':
                        if (secondNumber == 0)
                        {
                            await botClient.SendTextMessageAsync(update.Message.From.Id, "Division by zero is not allowed.");
                            return;
                        }
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber / secondNumber}");
                        return;
                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct operation like + - * /");
                        return;
                }
            }
            currentState = CalculationStates.Greetings;
        }

        public async Task HandleErrorAsync(
            ITelegramBotClient botClient,
            Exception exception,
            CancellationToken cancellationToken)
        {
            Console.WriteLine($"Exception: '{exception}'");
        }
    }
    public enum CalculationStates
    {
        Greetings,
        SetFirstNumber,
        SetSecondNumber,
        SetOperation
    }
}
```

Результат
![](/assets/Pasted%20image%2020240318022422.png)

Конечно лучше, однако наше приложение может расширяться в функционале, допустим телеграм бот может узнавать погоду, высчитывать индекс массы тела... Добавим Кейсы и состояние пользователя на определенное меню. Предыдущие состояния теперь будут принадлежать непосредственно к конкретному кейсу. Пропустим моменты наподобие внедрения зависимости, эта тема достойна отдельного поста. 
```cs
using System;
using System.Threading.Tasks;
using System.Threading;
using Telegram.Bot;
using Telegram.Bot.Polling;
using Telegram.Bot.Types;
using Telegram.Bots.Http;
using Telegram.Bots.Types;

namespace TestBot
{
    internal class Program
    {
        static async Task Main(string[] args)
        {
            using var cancellationToken = new CancellationTokenSource();

            var myBot = new TelegramBotClient("Your token");

            User user = new User();
            CalculatorUseCase CalculatorUseCase = new CalculatorUseCase(user);
            WeatherUseCase WeatherUseCase = new WeatherUseCase(user);
            MainMenuUseCase mainMenuUseCase = new MainMenuUseCase(user);
            
            UserMessageHandler handleService = new UserMessageHandler(CalculatorUseCase,WeatherUseCase,mainMenuUseCase, user);
            
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
    public class User
    {
        public User()
        {
            this.userState = UserState.MainMenu;
        }

        public UserState userState{ get; set; }
    }
    public enum UserState
    {
        MainMenu,
        CalculatorPipeLine,
        WeatherPipeLine
    }
    public class UserMessageHandler
    {
        CalculatorUseCase calculatorUseCase;
        WeatherUseCase weatherUseCase;
        MainMenuUseCase mainMenuUseCase;
        User user;
        public UserMessageHandler(CalculatorUseCase calculatorUseCase, WeatherUseCase weatherUseCase,MainMenuUseCase mainMenuUseCase, User user)
        {
            this.calculatorUseCase = calculatorUseCase;
            this.weatherUseCase = weatherUseCase;
            this.user = user;
            this.mainMenuUseCase = mainMenuUseCase;
        }

        public async Task HandleUpdateAsync(
            ITelegramBotClient botClient,
            Telegram.Bot.Types.Update update,
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

            switch (user.userState)
            {
                case UserState.MainMenu:
                    await mainMenuUseCase.processMessage(update, botClient);
                    return;
                case UserState.CalculatorPipeLine:
                    await calculatorUseCase.processMessage(update, botClient);
                    return;
                case UserState.WeatherPipeLine:
                    await weatherUseCase.processMessage(update, botClient);
                    return;
                default:
                    break;
            }
            
        }

        public async Task HandleErrorAsync(
            ITelegramBotClient botClient,
            Exception exception,
            CancellationToken cancellationToken)
        {
            Console.WriteLine($"Exception: '{exception}'");
        }
    }
    public enum CalculationStates
    {
        SetFirstNumber,
        SetSecondNumber,
        SetOperation
    }

    public class CalculatorUseCase
    {
        public CalculationStates currentState { get; set; }
        public double firstNumber { get; set; }
        public double secondNumber { get; set; }
        public User user { get; set; }


        public CalculatorUseCase(User user)
        {
            this.currentState = CalculationStates.SetFirstNumber;
            this.user = user;
        }

        public async Task processMessage(Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
        {
            var messageText = update.Message.Text;

            if (currentState.Equals(CalculationStates.SetFirstNumber) && Double.TryParse(messageText, out double parsedFirstNumber))
            {
                firstNumber = parsedFirstNumber;
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the second number");
                currentState = CalculationStates.SetSecondNumber;
                return;
            }

            if (currentState.Equals(CalculationStates.SetFirstNumber))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the correct number");
                return;
            }

            if (currentState.Equals(CalculationStates.SetSecondNumber) && Double.TryParse(messageText, out double parsedSecondNumber))
            {
                secondNumber = parsedSecondNumber;
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the operation");
                currentState = CalculationStates.SetOperation;
                return;
            }

            if (currentState.Equals(CalculationStates.SetSecondNumber))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the correct number");
                return;
            }

            if (currentState.Equals(CalculationStates.SetOperation))
            {
                switch (messageText[0])
                {
                    case '+':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber + secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenu;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    case '-':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber - secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenu;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    case '*':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber * secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenu;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    case '/':
                        if (secondNumber == 0)
                        {
                            await botClient.SendTextMessageAsync(update.Message.From.Id, "Division by zero is not allowed.");
                            await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                            user.userState = UserState.MainMenu;
                            currentState = CalculationStates.SetFirstNumber;
                            return;
                        }
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber / secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenu;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct operation like + - * /");
                        user.userState = UserState.MainMenu;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                }
            }
            currentState = CalculationStates.SetFirstNumber;
        }
    }

    public enum WeatherStates
    {
        SelectCelsiusOrFahrenheit,
        SelectCity
    }
    public class WeatherUseCase
    {
        public User user { get; set; }
        public WeatherStates currentState { get; set; }
        public bool isCelsium{ get; set; }

        public WeatherUseCase(User user)
        {
            this.currentState = WeatherStates.SelectCelsiusOrFahrenheit;
            this.user = user;
        }

        public async Task processMessage(Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
        {
            var messageText = update.Message.Text;

            if (currentState.Equals(WeatherStates.SelectCelsiusOrFahrenheit) && Int32.TryParse(messageText, out int parsedAnswer))
            {
                switch (parsedAnswer)
                {
                    case 1:
                        isCelsium = true;
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Select the city");
                        currentState = WeatherStates.SelectCity;
                        return;
                    case 2:
                        isCelsium = false;
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Select the city");
                        currentState = WeatherStates.SelectCity;
                        return;
                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct number 1 (Celsius) or 2 (Fahrenheit)");
                        return;
                }
            }
            if (currentState.Equals(WeatherStates.SelectCity))
            {
                switch (messageText.ToLower())
                {
                    case "moscow":
                        isCelsium = true;
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Cloudy, generally as always");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        currentState = WeatherStates.SelectCelsiusOrFahrenheit;
                        user.userState = UserState.MainMenu;
                        return;
                    case "philadelphia":
                        isCelsium = false;
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Where is always sunny in philadelphia");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        currentState = WeatherStates.SelectCelsiusOrFahrenheit;
                        user.userState = UserState.MainMenu;
                        return;
                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"City is not founded.");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        currentState = WeatherStates.SelectCelsiusOrFahrenheit;
                        user.userState = UserState.MainMenu;
                        return;
                }
            }
        }
    }


    public enum MainMenuState
    {
        Greetings,
        ChooseMenu
    }
    public class MainMenuUseCase
    {
        public User user { get; set; }
        public MainMenuState currentState { get; set; }

        public MainMenuUseCase(User user)
        {
            this.currentState = MainMenuState.Greetings;
            this.user = user;
        }

        public async Task processMessage(Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
        {
            var messageText = update.Message.Text;

            if (currentState.Equals(MainMenuState.Greetings))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, "1 - go to calculate menu or 2 - weather menu");
                currentState = MainMenuState.ChooseMenu;
                return;
            }

            if (currentState.Equals(MainMenuState.ChooseMenu) && Int32.TryParse(messageText, out int parsedAnswer))
            {
                switch (parsedAnswer)
                {
                    case 1:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the first number");
                        user.userState = UserState.CalculatorPipeLine;
                        return;
                    case 2:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Select 1-Celsius or 2-Fahrenheit");
                        user.userState = UserState.WeatherPipeLine;
                        return;
                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct number 1 (calculate menu) or 2 (weather menu)");
                        return;
                }
            }
            if (currentState.Equals(MainMenuState.ChooseMenu))
            {
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct number 1 (calculate menu) or 2 (weather menu)");
                return;
            }
        }
    }
}
```

Итог
![](/assets/Pasted%20image%2020240318040607.png)

В будущем мы более подробно рассмотрим этот кейс, выделим абстракции для удобного добавления новых сценариев.
Конечно есть и другие возможные реализации, например через FSM, и F#, но эти темы мы обсудим в будущем.
# Итог 
Мы познакомились с не очень элегантным способом обработки сообщений от пользователя, однако он может покрыть большую половину требований к функционалу бота поскольку прост в исполнении.

Надеюсь пост был для вас полезен, до новых встреч!
