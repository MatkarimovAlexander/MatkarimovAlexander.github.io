---
layout: post
title: "Telegram bot: Конечный автомат в рамках обработки сообщения."
tags:
  - bot
  - telegram
---
# Введение
Рассмотрим повнимательнее пример из предыдущего урока по разработке телеграмм бота.

```cs
    public class CalculatorUseCase : ICalculatorUseCase
    {
        public CalculationStates currentState { get; set; }
        public double firstNumber { get; set; }
        public double secondNumber { get; set; }
        public User user { get; set; }


        public CalculatorUseCase(User user)
        {
            currentState = CalculationStates.SetFirstNumber;
            this.user = user;
        }

        public async Task processMessage(Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
        {
            var messageText = update.Message.Text;

            if (currentState.Equals(CalculationStates.SetFirstNumber) && double.TryParse(messageText, out double parsedFirstNumber))
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

            if (currentState.Equals(CalculationStates.SetSecondNumber) && double.TryParse(messageText, out double parsedSecondNumber))
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
                        user.userState = UserState.MainMenuPipeLine;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    case '-':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber - secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenuPipeLine;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    case '*':
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber * secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenuPipeLine;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    case '/':
                        if (secondNumber == 0)
                        {
                            await botClient.SendTextMessageAsync(update.Message.From.Id, "Division by zero is not allowed.");
                            await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                            user.userState = UserState.MainMenuPipeLine;
                            currentState = CalculationStates.SetFirstNumber;
                            return;
                        }
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber / secondNumber}");
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                        user.userState = UserState.MainMenuPipeLine;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct operation like + - * /");
                        user.userState = UserState.MainMenuPipeLine;
                        currentState = CalculationStates.SetFirstNumber;
                        return;
                }
            }
            currentState = CalculationStates.SetFirstNumber;
        }
    }
```
Представьте как это будет выглядеть, если у нас будут другие, более обширные usecase, та же регистрация с вводом имени фамилии, адреса, почты, тот же диалог с NPC из какого нибудь текстового квеста... Код будет разрастаться и разрастаться и становится все запутаннее и запутаннее(что нам мешает переходить из одного usecase-а в другой). Внедрив конечный автомат в наши будущие разработки Telegram-бота, мы значительно упростим управление состояниями пользователя и обработку входящих сообщений. 
# Ингридиенты

Выделим каждое состояние в отдельный класс, который обязуется обработать сообщение

```cs
    public interface IBotState
    {
        Task HandleMessage(UserContext context, Telegram.Bot.Types.Update update, ITelegramBotClient botClient);
    }
```
Допустим мы обрабатываем первое, вводное сообщение
```cs
public class GreetingsState : IBotState
{
    public async Task HandleMessage(UserContext context, Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
    {
        await botClient.SendTextMessageAsync(update.Message.From.Id, "1 - go to calculate menu or 2 - weather menu");
        context.CurrentState = new ChooseMenuState();
    }
}
```
Отправив пользователю дальнейшие варианты ввода, мы сразу меняем его состояние для обработки следующего сообщения.

```cs
    public class ChooseMenuState : IBotState
    {
        public async Task HandleMessage(UserContext context, Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
        {
            var messageText = update.Message.Text;
            if (Int32.TryParse(messageText, out int parsedAnswer))
            {
                switch (parsedAnswer)
                {
                    case 1:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the first number");
                        context.CurrentState = new SetFirstNumberState(context);
                        break;

                    case 2:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, "Weather option is not realized.");
                        break;

                    default:
                        await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct number 1 (calculate menu) or 2 (weather menu)");
                        break;
                }
                return;
            }
            await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct number 1 (calculate menu) or 2 (weather menu)");
        }
    }
```
И тут мы наталкиваемся на проблему хранения промежуточных значений, да, мы ввели корректно будущих два числа, но откуда они возьмутся у экземпляра класса, который будет проводить над ними манипуляции?
Хранить и передавать их в конструкторы следующих состояний выглядит неуместно, потому будем хранить их в контексте пользователя. Однако возникает следующий вопрос: как грамотно вытаскивать промежуточные значения в определенных состояниях? Создавать список(или стек) промежуточных значений и вытаскивать их по индексу? У нас же значения могут быть разных типов... Оставим на данный момент этот вопрос, ему будет посвящена отдельная тема, а пока, в рамках контекста, мы будем хранить экземпляр, унаследованный от абстрактного StateData.
```cs
    public abstract class StateData
    {

    }
    public class DefaultStateData : StateData
    {

    }
```
Таким образом наш пользовательский контекст придет к такому виду.
```cs
public class UserContext
{
    public IBotState CurrentState { get; set;}
    public StateData StateData { get; set;}
    public UserContext()
    {
        // Начальное состояние
        this.CurrentState = new GreetingsState();
        // Устанавливаем дефолтное значение нашего хранилища промежуточных значений. 
        this.StateData = new DefaultStateData();
    }
    public async Task ProcessMessage(Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
    {
        await CurrentState.HandleMessage(this, update, botClient);
    }
}

```
Итак, мы хотим выполнить операцию на двумя введенными числами, рассмотрим внимательнее первое состояние.

```cs
public class CalculatorStateData : StateData
{
    public double FirstNumber { get; set; }
    public double SecondNumber { get; set; }
}
public class SetFirstNumberState : IBotState
    {
        public SetFirstNumberState(UserContext context)
        {
	        // Явно меняем тип хранилища данных.
            context.StateData = new CalculatorStateData();
        }

        public async Task HandleMessage(UserContext context, Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
        {
            if (double.TryParse(update.Message.Text, out double number))
            {
                var calculatorStateData = context.StateData as CalculatorStateData;
                calculatorStateData.FirstNumber = number;
                await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the second number");
                context.CurrentState = new SetSecondNumberState();
                return;
            }
            await botClient.SendTextMessageAsync(update.Message.From.Id, "Please enter a valid number.");
        }
    }
```
На данный момент, текущий недостаток нашего решения, это то что мы оставляем на разработчике ответственность создания определенного хранилища данных для определенных состояний и явное преобразование типов для дальнейшей работы с хранилищем.
Добавим остальные состояния в рамках нашего сценария.
```cs
public class SetSecondNumberState : IBotState
{
    public async Task HandleMessage(UserContext context, Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
    {
        if (double.TryParse(update.Message.Text, out double number))
        {
            var calculatorStateData = context.StateData as CalculatorStateData;
            calculatorStateData.SecondNumber = number;
            await botClient.SendTextMessageAsync(update.Message.From.Id, "Enter the correct operation like + - * /");
            context.CurrentState = new SetOperationState();
            return;
        }
        await botClient.SendTextMessageAsync(update.Message.From.Id, "Please enter a valid number.");
    }
}
public class SetOperationState : IBotState
{
    public async Task HandleMessage(UserContext context, Telegram.Bot.Types.Update update, ITelegramBotClient botClient)
    {
        var messageText = update.Message.Text;
        var calculatorStateData = context.StateData as CalculatorStateData;
        var firstNumber = calculatorStateData.FirstNumber;
        var secondNumber = calculatorStateData.SecondNumber;

        switch (messageText[0])
        {
            case '+':
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber + secondNumber}");
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                context.CurrentState = new GreetingsState();
                return;
            case '-':
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber - secondNumber}");
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                context.CurrentState = new GreetingsState();
                return;
            case '*':
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber * secondNumber}");
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                context.CurrentState = new GreetingsState();
                return;
            case '/':
                if (secondNumber == 0)
                {
                    await botClient.SendTextMessageAsync(update.Message.From.Id, "Division by zero is not allowed.");
                    await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                    context.CurrentState = new GreetingsState();
                    return;
                }
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"The answer is {firstNumber / secondNumber}");
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"1 - go to calculate menu or 2 - weather menu");
                context.CurrentState = new GreetingsState();
                return;
            default:
                await botClient.SendTextMessageAsync(update.Message.From.Id, $"Enter the correct operation like + - * /");
                context.CurrentState = new SetOperationState();
                return;
        }
    }
```
Далее нам остается настроить наш сервис для UserContext
```
            services.AddSingleton<UserContext>();
            services.AddTransient<UserMessageHandler>();
```
И для UserMessageHandler, пробрасываем userContext
```cs
    public class UserMessageHandler
    {
        UserContext userContext;
        public UserMessageHandler(UserContext userContext)
        {
            this.userContext = userContext;
        }
```

Все что нам остается после фильтрации сообщения, это вызвать единственную строку для HandleUpdateAsync!
```
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
            await userContext.ProcessMessage(update,botClient);
        }
```
# Вывод
Начальные, промежуточные и конечные состояния для удобства, мы можем хранить в файле или в папке, допустим CalculatorState, все! Нам больше не нужны перечисления, наш код не будет разбухать от количества возможных состояний, нам теперь не грозит поиск нужной строки в usecase, пелену из глаз мы убрали, нам не нужно простраивать пайплайны и проходится по ним в поисках нужного состояния... Конечный автомат прекрасно подходит для обработки сообщений пользователя.

А на сегодня все, до новых встреч!   
