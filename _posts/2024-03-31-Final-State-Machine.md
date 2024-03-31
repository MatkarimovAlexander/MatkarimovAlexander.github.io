---
layout: post
title: Знакомимся с конечным автоматом!
tags:
  - pattern
---
# Введение

Начнем сразу же с проблемы.

Предположим, вы сталкиваетесь с задачей управления файлом в вашем приложении. Вам необходимо открыть файл, прочитать/изменить его содержимое, а затем закрыть. Эта задача кажется довольно простой, но во время реализации и отладки вступают различные состояния файла: файл уже открыт, файл не существует, файл открыт только для чтения... В общем логика работы с файлом может стать довольно запутанной.

Давайте посмотрим на шаблонный код.
```cs
public class FileManager : IDisposable
{
    bool _isReadOnly = false;
    private FileStream _document;
    private string _filePath;
    private bool _isOpen;
    private FileInfo _fileInfo;

    public FileInfo Fileinfo
    {
        get
        {
            try
            {
                if (_document == null)
                {
                    _fileInfo = Read();
                    if (_fileInfo == null)
                    {
                        return null;
                    }
                }
                return _fileInfo;
            }
            catch (Exception ex)
            {
                return null;
            }
        }
        set
        {
            if (value == null)
            {
                return;
            }

            if (_document == null)
            {
                _fileInfo = Read();
                if (_fileInfo == null)
                {
                    throw new ArgumentException($"FileInfo is null.");
                }
            }
            WriteFileInfo(value);
        }
    }

    public FileManager(string filePath)
    {
        _filePath = filePath;
        Open();
    }

    private void Open()
    {
        if (_isReadOnly)
        {
            _document = new FileStream(_filePath, FileMode.Open, FileAccess.Read);
            _isOpen = true;
            return;
        }
        _document = new FileStream(_filePath,
            File.Exists(_filePath) ?
            FileMode.OpenOrCreate :
            FileMode.CreateNew,
            FileAccess.ReadWrite);
        _isOpen = true;

    }

    private FileInfo Read()
    {
        _fileInfo = new FileInfo(_filePath);
        return _fileInfo;
    }

    private void WriteFileInfo(FileInfo fileInfo)
    {
        // Пример записи метаданных файла
        // Здесь просто установим дату последнего доступа для примера
        fileInfo.LastAccessTime = DateTime.Now;

    }

    private void Save()
    {
        // Пример сохранения изменений в файл
        _document.Flush();
    }

    private void Close()
    {
        _document.Close();
        _isOpen = false;
    }

    public void Dispose()
    {
        if (_document == null)
        {
            return;
        }

        Save();

        if (_isOpen)
        {
            _document.Close();
        }
    }
}
```
Читается тяжело, как убедиться, что мы не пытаемся прочитать файл, который ещё не открыт, или не пытаемся записать в файл, открытый только для чтения? Как корректно обрабатывать ошибки при попытке чтения из несуществующего файла или при записи в файл без прав на запись? Как поддерживать код чистым и понятным, несмотря на все возможные переходы между состояниями файла?

# Конечный автомат

Конечный автомат (Finite State Machine, FSM) — это модель поведения, состоящая из определённого числа состояний, переходов между этими состояниями и действий, которые выполняются в каждом состоянии или при переходе из одного состояния в другое. Основное назначение конечного автомата — управление потоком выполнения программы в зависимости от внутреннего состояния и внешних событий.

# Наше новое решение

Использование конечного автомата позволяет нам чётко определить все возможные состояния, в которых может находиться файл (например, "Закрыт", "Открыт"), а также допустимые переходы между этими состояниями и действия, которые необходимо выполнить при каждом переходе.

```cs
public interface IFileState
{
    void Open(FileContext context);
    void ChangeContents(FileContext context, string content);
    void Close(FileContext context);
}

public class FileClosed : IFileState
{
    public void Open(FileContext context)
    {
        Console.WriteLine("File is opened.");
        context.State = new FileOpen(); 
    }

    public void ChangeContents(FileContext context, string content)
    {
        Console.WriteLine("Cannot change contents. File is not open.");
    }

    public void Close(FileContext context)
    {
        Console.WriteLine("File is already closed.");
    }
}

public class FileOpen : IFileState
{
    public void Open(FileContext context)
    {
        Console.WriteLine("File is already open.");
    }

    public void ChangeContents(FileContext context, string content)
    {
        Console.WriteLine("Changing file contents.");
        File.WriteAllText(context.FilePath, content);
    }

    public void Close(FileContext context)
    {
        Console.WriteLine("File is closed.");
        context.State = new FileClosed();
    }
}

public class FileContext
{
    public IFileState State { get; set; }
    public string FilePath { get; set; }

    public FileContext(string filePath)
    {
        State = new FileClosed();
        FilePath = filePath;
    }

    public void Open()
    {
        State.Open(this);
    }

    public void ChangeContents(string content)
    {
        State.ChangeContents(this, content);
    }

    public void Close()
    {
        State.Close(this);
    }
}

```

Теперь наша работа с файлом будет выглядеть примерно так:

```cs
FileContext fileContext = new FileContext("C:/example.txt");
fileContext.Open(); 
fileContext.ChangeContents("Hello, World!"); 
fileContext.Close();
```
# Вывод

Мы познакомились с концепцией конечного автомата на конкретном примере управления файлом. Применение этого подхода позволило нам сделать код не только более читабельным и понятным, но и значительно повысить его безопасность. Ведь теперь каждое действие с файлом , которое мы хотим совершить, явно контролируется через определённые состояния, что минимизирует риск возникновения ошибок, связанных с неправильным управлением состояниями файла.

Надеюсь пост был для вас познавательным, а на сегодня все, до новых встреч!