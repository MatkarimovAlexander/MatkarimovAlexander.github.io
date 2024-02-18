---
layout: post
title: System.Array.CopyTo() vs System.Array.Clone() а так же поверхностное копирование и глубокое.
---
# Введение
Очень частый вопрос на собеседовании - в чем разница между System.Array.CopyTo() и System.Array.Clone(), добавляя ловушку-вопрос касаемо копирования как такового, ведь оно бывает нескольких видов. 

Давайте разберемся.
# Поверхностное копирование (Shallow Copy) 
И CopyTo(), и Clone() создают поверхностное копирование.

Метод Clone() создает клон(новый массив) исходного массива. Он возвращает массив точной длины.

CopyTo() копирует элементы из исходного(уже объявленного) массива в целевой массив, начиная с указанного индекса целевого массива. Нужно обратить внимание, что при этом элементы добавляются в уже существующий массив.

Проверим запустив данный код
```cs
static void Main(string[] args)
        {
            object[] myarray = new object[] { "one", 2, "three", 4, "really big number", 2324573984927361 };

            object[] myarray2 = new object[myarray.Length];

            myarray.CopyTo(myarray2, 0);

            object[] myarray1;
            myarray1 = myarray.Clone() as object[];

            myarray[0] = 0;
            Console.WriteLine(myarray[0]); // print 0
            Console.WriteLine(myarray1[0]);//print "one"
            Console.WriteLine(myarray2[0]);//print "one"

            Console.Read();
        }
```

Но проблема этого примера в том что строки и целые числа _всегда_ создают новую копию, когда они помещаются во что-то другое. Чтобы протестировать поверхностное копирование ссылочных типов, сделаем массив кошельков, в котором есть сумма денег, и объект карточка.
```cs
public class Card
        {
            public int id;
            public string Name;

            public Card(int id, string name)
            {
                this.id = id;
                Name = name;
            }
        }
        public class Wallet
        {
            public int id;
            public int money;
            public Card card;

            public Wallet(int id, int money, Card card)
            {
                this.id = id;
                this.money = money;
                this.card = card;
            }
        }
        static void Main(string[] args)
        {
            Wallet[] wallets = new Wallet[] { new Wallet(1,10,new Card(1,"Visa")), new Wallet(2, 20, new Card(2, "MasterCard")) };

            Wallet[] wallets2 = new Wallet[wallets.Length];

            wallets.CopyTo(wallets2,0);

            Wallet[] wallets1;
            wallets1 = wallets.Clone() as Wallet[];
            var a = wallets[0];
            a.id = 3;
            a.money = 3000;
            a.card.id = -1;
            a.card.Name = "MIR";
            wallets[1] = null;

            Console.Read();
        }
```
До изменения элементов массива wallets
![](/assets/Pasted%20image%2020240219012220.png)
После
![](/assets/Pasted%20image%2020240219012301.png)
Мы убедились что наши массивы wallets2 и wallets1 имеют все таки ссылки на объекты типа Wallet.
# Глубокое копирование (Deep Copy)
Метод System.Array.Clone() использует [Object.MemberwiseClone](https://learn.microsoft.com/en-us/dotnet/api/system.object.memberwiseclone?view=net-8.0&redirectedfrom=MSDN#System_Object_MemberwiseClone), и на основе этого MemberwiseClone, можно написать рекурсивный проход, создав таким образом наше глубокое копирование.
Да и видов глубокого копирования масса, конечно, мы можем реализовать ручками `: ICloneable` для `Wallet`, но я рекомендую ознакомится с решением одного Хорошего Человека, который [реализовал расширение на основе MemberwiseClone](https://github.com/Burtsev-Alexey/net-object-deep-copy)за нас.
# Что почитать?
https://stackoverflow.com/questions/198496/difference-between-the-system-array-copyto-and-system-array-clone

https://stackoverflow.com/questions/184710/what-is-the-difference-between-a-deep-copy-and-a-shallow-copy

https://stackoverflow.com/questions/78536/deep-cloning-objects/12609692#12609692

https://metanit.com/sharp/tutorial/3.22.php

https://habr.com/ru/articles/332516/

https://habr.com/ru/articles/541786/

https://learn.microsoft.com/ru-ru/dotnet/api/system.array.copyto?view=net-8.0

https://learn.microsoft.com/ru-ru/dotnet/api/system.array.clone?view=net-8.0

https://learn.microsoft.com/ru-ru/dotnet/api/system.object.memberwiseclone?view=net-8.0

https://stackoverflow.com/questions/129389/how-do-you-do-a-deep-copy-of-an-object-in-net

# Итог
Мы познакомились с двумя видами копирования, узнали, что и Clone и CopyTo являются поверхностными копированиями, а так же возможные вариации глубокого.
Надеюсь этот пост был для вас полезным и информативным.
А на сегодня все, до новых встреч!