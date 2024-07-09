----------------------------------------------Tworzeie bazy danych danych
USE [master]
GO

-- Usuwanie bazy danych
ALTER DATABASE [Komunikacja_miejska]
SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

DECLARE @db_name NVARCHAR(MAX) = N'Komunikacja_miejska';

IF DB_ID(@db_name) IS NOT NULL
BEGIN
    EXEC('DROP DATABASE ' + @db_name);
END
GO

-- Tworzenie bazy danych


DECLARE @db_name NVARCHAR(MAX),
        @mdf_path NVARCHAR(MAX),
        @ldf_path NVARCHAR(MAX),
        @command NVARCHAR(MAX);

SET @db_name = N'Komunikacja_miejska';
SET @mdf_path = N'''C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\' + @db_name + '.mdf''';
SET @ldf_path = N'''C:\Program Files\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQL\DATA\' + @db_name + '_log.ldf''';
SET @command = N'CREATE DATABASE ' + QUOTENAME(@db_name) + ' ON PRIMARY
                  (NAME = ' + QUOTENAME(@db_name) + ',
                   FILENAME = ' + @mdf_path + ',
                   SIZE = 8192KB,
                   MAXSIZE = 2GB,
                   FILEGROWTH = 10%)';

EXEC (@command);
GO

-- Tworzenie tabel
USE [Komunikacja_miejska]
GO

DECLARE @db_name NVARCHAR(MAX);
SET @db_name = N'Komunikacja_miejska';

DROP TABLE IF EXISTS Autobusy;
CREATE TABLE Autobusy(
    ID_Autobusu int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Rodzaj nvarchar(11) NOT NULL,
    Rozmiar nvarchar(10),
    Numer_rejestracyjny nvarchar(8),
    Gps bit,
    Marka nvarchar(50)
);

DROP TABLE IF EXISTS Przystanki;
CREATE TABLE Przystanki(
    ID_przystanku int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Nazwa_przystanku nvarchar(100)
);

DROP TABLE IF EXISTS Trasa;
CREATE TABLE Trasa(
    ID_trasy int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ID_przystanku_pocz¹tkowego int FOREIGN KEY REFERENCES Przystanki(ID_przystanku),
    ID_przystanku_koñcowego int FOREIGN KEY REFERENCES Przystanki(ID_przystanku)
);

DROP TABLE IF EXISTS Linie;
CREATE TABLE Linie(
    ID_lini int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Numer_lini int,
    ID_trasy int FOREIGN KEY REFERENCES Trasa(ID_trasy)
);

DROP TABLE IF EXISTS Kursy;
CREATE TABLE Kursy(
    ID_kursu int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Godzina_przyjazdu time,
    Typ_dnia nvarchar(7),
    ID_przystanku int FOREIGN KEY REFERENCES Przystanki(ID_przystanku)
);

DROP TABLE IF EXISTS Przypisanie_autobusu_do_trasy;
CREATE TABLE Przypisanie_autobusu_do_trasy(
    ID_trasy int FOREIGN KEY REFERENCES Trasa(ID_trasy),
    ID_autobusu int FOREIGN KEY REFERENCES Autobusy(ID_Autobusu)
);

DROP TABLE IF EXISTS Przypisanie_lini_do_trasy;
CREATE TABLE Przypisanie_lini_do_trasy(
    ID_trasy int FOREIGN KEY REFERENCES Trasa(ID_trasy),
    ID_lini int FOREIGN KEY REFERENCES Linie(ID_lini)
);

DROP TABLE IF EXISTS OpóŸnienia;
CREATE TABLE OpóŸnienia(
    ID_opóŸnienia int IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ID_autobusu int FOREIGN KEY REFERENCES Autobusy(ID_Autobusu),
    Czas_opóŸnienia time
);

IF DB_ID(@db_name) IS NOT NULL
BEGIN
    PRINT 'Baza pomyœlnie utworzona';
END



----------------------------------------------Wyzwalacze

-- Tworzenie triggera dla Autobusy
DROP TRIGGER IF EXISTS sprawdzAutobus;
GO

CREATE TRIGGER sprawdzAutobus
ON Autobusy
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE NOT (
            Rodzaj IN ('hybrydowy', 'spalinowy', 'elektryczny') AND
            Rozmiar IN ('mikrobus', 'przegubowy', 'miejski') AND
            Numer_rejestracyjny LIKE 'SB [0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]' AND
            LEN(Numer_rejestracyjny) = 8 AND
            (GPS = 1 OR GPS = 0)
        )
    )
    BEGIN
        RAISERROR ('Niepoprawne dane w jednym z pól: Rodzaj, Rozmiar, Numer rejestracyjny, GPS, Marka', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO



-- Tworzenie triggera dla Linie
DROP TRIGGER IF EXISTS sprawdzNumerLini;
GO

CREATE TRIGGER sprawdzNumerLini
ON Linie
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM Linie l
        INNER JOIN inserted i ON l.Numer_lini = i.Numer_lini AND l.ID_lini <> i.ID_lini
    )
    BEGIN
        RAISERROR ('Dodawana linia ju¿ istnieje w tabeli.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO


-- Tworzenie triggera dla Kursy
DROP TRIGGER IF EXISTS Sprawdzkurs;
GO

CREATE TRIGGER Sprawdzkurs
ON Kursy
AFTER INSERT, UPDATE
AS
BEGIN
	 IF EXISTS (
        SELECT 1
        FROM inserted
        WHERE Typ_dnia NOT IN ('Weekend', 'Dzieñ roboczy', 'Œwiêto')
    )
    BEGIN
        RAISERROR ('Niepoprawny typ dnia. Dopuszczalne wartoœci to: Weekend, Dzieñ roboczy, Œwiêto.', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- Tworzenie triggera dla Trasa
DROP TRIGGER IF EXISTS sprawdzTrase;
GO

CREATE TRIGGER sprawdzTrase
ON Trasa
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT * FROM inserted WHERE ID_przystanku_pocz¹tkowego = ID_przystanku_koñcowego
    )
    BEGIN
        RAISERROR ('ID przystanku pocz¹tkowego i koñcowego musz¹ siê ró¿niæ od siebie', 16, 1);
    END
END;
GO




----------------------------------------------Procedury

--DodajAutobus
DROP PROCEDURE IF EXISTS DodajAutobus
GO

CREATE PROCEDURE DodajAutobus
	@Rodzaj NVARCHAR(11),
	@Rozmiar NVARCHAR(10),
	@Numer_rejestracyjny NVARCHAR(8),
	@Gps BIT,
	@Marka NVARCHAR(50)
AS
BEGIN
	INSERT INTO Autobusy(Rodzaj,Rozmiar,Numer_rejestracyjny,Gps,Marka)
	VALUES (@Rodzaj,@Rozmiar,@Numer_rejestracyjny,@gps,@Marka)
END; 
GO



--DodajPrzysztanek
DROP PROCEDURE IF EXISTS DodajPrzystanek
GO

CREATE PROCEDURE DodajPrzystanek
    @Nazwa_przystanku NVARCHAR(100)
AS
BEGIN
    INSERT INTO Przystanki(Nazwa_przystanku)
    VALUES (@Nazwa_przystanku);
END;
GO



--DodaKurs
DROP PROCEDURE IF EXISTS DodajKurs
GO

CREATE PROCEDURE DodajKurs
	@Godzina_przyjazdu TIME,
	@Typ_dnia NVARCHAR(7),
	@Nazwa_przystanku NVARCHAR(100)
AS
BEGIN
    DECLARE @ID_przystanku INT;
    SET @ID_przystanku = (SELECT ID_przystanku FROM Przystanki WHERE Nazwa_przystanku = @Nazwa_przystanku);

	IF @ID_przystanku IS NOT NULL
	BEGIN
		INSERT INTO Kursy(Godzina_przyjazdu, Typ_dnia, ID_przystanku)
		VALUES (@Godzina_przyjazdu, @Typ_dnia, @ID_przystanku);
	END
	ELSE 
	BEGIN
		RAISERROR ('Nie znaleziono przystanku.', 16, 1);
    END
END;
GO



 --DodajTrasê
 DROP PROCEDURE IF EXISTS DodajTrasê
 GO

 CREATE PROCEDURE DodajTrasê
	@Przystanek_pocz¹tkowy NVARCHAR(100),
	@Przystanek_koñcowy NVARCHAR(100)
AS
BEGIN
	DECLARE @ID_przystanku_pocz¹tkowego INT, @ID_przystanku_koñcowego INT; 

	SET @ID_przystanku_pocz¹tkowego = (SELECT ID_przystanku FROM Przystanki WHERE Nazwa_przystanku = @Przystanek_pocz¹tkowy);
	SET @ID_przystanku_koñcowego = (SELECT ID_przystanku FROM Przystanki WHERE Nazwa_przystanku = @Przystanek_koñcowy);
	
	IF @ID_przystanku_pocz¹tkowego IS NOT NULL AND @ID_przystanku_koñcowego IS NOT NULL
    BEGIN
        INSERT INTO Trasa (ID_przystanku_pocz¹tkowego, ID_przystanku_koñcowego)
        VALUES (@ID_przystanku_pocz¹tkowego, @ID_przystanku_koñcowego);
    END
    ELSE
    BEGIN
        RAISERROR ('Nie znaleziono jednego lub obu przystanków.', 16, 1);
    END
END;
GO


--DodajOpóŸnienie
 DROP PROCEDURE IF EXISTS DodajOpóŸnienie
 GO

 CREATE PROCEDURE DodajOpóŸnienie
	@Czas_opóŸnienia TIME,
	@ID_autobusu INT
AS
BEGIN
	IF @ID_autobusu IS NOT NULL
	BEGIN
		INSERT INTO OpóŸnienia(Czas_opóŸnienia,ID_autobusu)
		VALUES (@Czas_opóŸnienia,@ID_autobusu)
	END
	ELSE
	BEGIN
		RAISERROR ('Nie znaleziono autobusu.', 16, 1);
    END
END;
GO


--DodajLinie
DROP PROCEDURE IF EXISTS DodajLinie;
GO

CREATE PROCEDURE DodajLinie
    @Numer_lini INT,
    @ID_trasy INT
AS
BEGIN
    IF @Numer_lini IS NULL
    BEGIN
        RAISERROR('Nie znaleziono lini', 16, 1);
    END
    ELSE IF @ID_trasy IS NULL
    BEGIN
        RAISERROR('Nie znaleziono trasy', 16, 1);
    END
    ELSE
    BEGIN
        INSERT INTO Linie(Numer_lini, ID_trasy)
        VALUES (@Numer_lini, @ID_trasy)
    END
END;
GO


--DodajAutobusDoTrasy
DROP PROCEDURE IF EXISTS DodajAutobusDoTrasy;
GO

CREATE PROCEDURE DodajAutobusDoTrasy
    @ID_autobusu INT,
    @ID_trasy INT
AS
BEGIN
    IF @ID_autobusu IS NULL
    BEGIN
        RAISERROR('Nie znaleziono autobusu', 16, 1);
    END
    ELSE IF @ID_trasy IS NULL
    BEGIN
        RAISERROR('Nie znaleziono trasy', 16, 1);
    END
    ELSE
    BEGIN
        INSERT INTO Przypisanie_autobusu_do_trasy(ID_autobusu, ID_trasy)
        VALUES (@ID_autobusu, @ID_trasy)
    END
END;
GO


--DodajLinieDoTrasy
DROP PROCEDURE IF EXISTS DodajLinieDoTrasy;
GO

CREATE PROCEDURE DodajLinieDoTrasy
    @ID_lini INT,
    @ID_Trasy INT
AS
BEGIN
    IF @ID_lini IS NULL
    BEGIN
        RAISERROR('Nie znaleziono lini', 16, 1);
    END
    ELSE IF @ID_Trasy IS NULL
    BEGIN
        RAISERROR('Nie znaleziono trasy', 16, 1);
    END
    ELSE
    BEGIN
        INSERT INTO Przypisanie_lini_do_trasy(ID_lini, ID_trasy)
        VALUES (@ID_lini, @ID_trasy)
    END
END;


----------------------------------------------Widoki

--Autobusy z trasami
DROP VIEW IF EXISTS AutobusyzTrasami
GO

CREATE VIEW AutobusyzTrasami AS
	SELECT 
	    t.ID_trasy AS [ID trasy], 
	    a.ID_Autobusu AS [ID Autobusu], 
	    a.Marka AS [Marka], 
	    a.Numer_rejestracyjny AS [Numer rejestracyjny], 
	    a.Rodzaj AS [Rodzaj], 
	    a.Rozmiar AS [Rozmiar]
	FROM Przypisanie_autobusu_do_trasy pat 
	JOIN Trasa t ON t.ID_trasy = pat.ID_trasy 
	JOIN Autobusy a ON a.ID_Autobusu = pat.ID_autobusu
GO



--Linie z trasami
DROP VIEW IF EXISTS LiniezTrasami
GO

CREATE VIEW LiniezTrasami AS
	SELECT 
		t.ID_trasy AS [ID trasy], 
		l.Numer_lini AS [Numer lini]
	FROM Przypisanie_lini_do_trasy plt
	JOIN Linie l ON l.ID_lini = plt.ID_lini
	JOIN Trasa t ON t.ID_trasy = plt.ID_trasy
GO



--Wszystkie kursy
DROP VIEW IF EXISTS WszystkieKursy;
GO

CREATE VIEW WszystkieKursy AS
    SELECT
        k.ID_kursu AS [ID kursu],
        FORMAT(k.Godzina_przyjazdu, 'HH:mm') AS [Godzina przyjazdu autobusu],  
        k.Typ_dnia AS [Typ Dnia],
        p.Nazwa_przystanku AS [Nazwa przystanku]
    FROM Kursy k
    JOIN Przystanki p ON p.ID_przystanku = k.ID_przystanku;
GO


--Wszystkie przystanki

DROP VIEW IF EXISTS WszystkiePrzystanki;
GO

CREATE VIEW WszystkiePrzystanki AS
	SELECT * FROM Przystanki
GO


----------------------------------------------Dane pseudolosowe

-- Reset tabel
DELETE FROM Przypisanie_autobusu_do_trasy;
DELETE FROM Przypisanie_lini_do_trasy;
DELETE FROM OpóŸnienia;
DELETE FROM Kursy;
DELETE FROM Linie;
DELETE FROM Trasa;
DELETE FROM Przystanki;
DELETE FROM Autobusy;
GO

DBCC CHECKIDENT ('Autobusy', RESEED, 1);
DBCC CHECKIDENT ('Przystanki', RESEED, 1);
DBCC CHECKIDENT ('Trasa', RESEED, 1);
DBCC CHECKIDENT ('Linie', RESEED, 1);
DBCC CHECKIDENT ('Kursy', RESEED, 1);
DBCC CHECKIDENT ('OpóŸnienia', RESEED, 1);
GO




-- Dodawanie wpisów do tabeli Autobusy
EXEC DodajAutobus 'spalinowy', 'miejski', 'SB 1234A', 1, 'Solaris';
EXEC DodajAutobus 'elektryczny', 'miejski', 'SB 5678B', 1, 'Iveco';
EXEC DodajAutobus 'hybrydowy', 'przegubowy', 'SB 9012C', 1, 'MAN';
EXEC DodajAutobus 'spalinowy', 'miejski', 'SB 3456D', 0, 'Volvo';
EXEC DodajAutobus 'elektryczny', 'miejski', 'SB 7890E', 1, 'Solaris';
EXEC DodajAutobus 'hybrydowy', 'przegubowy', 'SB 1357F', 0, 'Mercedes';
EXEC DodajAutobus 'spalinowy', 'miejski', 'SB 2468G', 1, 'Iveco';
EXEC DodajAutobus 'elektryczny', 'miejski', 'SB 3690H', 1, 'MAN';
EXEC DodajAutobus 'hybrydowy', 'przegubowy', 'SB 4681I', 0, 'Volvo';
EXEC DodajAutobus 'spalinowy', 'miejski', 'SB 5702J', 1, 'Solaris';



-- Dodawanie wpisów do tabeli Przystanki
EXEC DodajPrzystanek 'Centrum';
EXEC DodajPrzystanek 'Dworzec G³ówny';
EXEC DodajPrzystanek 'Park Kultury';
EXEC DodajPrzystanek 'Ulica Ogrodowa';
EXEC DodajPrzystanek 'Plac Wolnoœci';
EXEC DodajPrzystanek 'Nowe Miasto';
EXEC DodajPrzystanek 'Stare Miasto';
EXEC DodajPrzystanek 'Ulica Kwiatowa';
EXEC DodajPrzystanek 'Osiedle M³odych';
EXEC DodajPrzystanek 'Plac Niepodleg³oœci';


-- Tworzenie Tras
EXEC DodajTrasê 'Centrum', 'Dworzec G³ówny';
EXEC DodajTrasê 'Ulica Ogrodowa', 'Plac Wolnoœci';
EXEC DodajTrasê 'Nowe Miasto', 'Stare Miasto';
EXEC DodajTrasê 'Ulica Kwiatowa', 'Osiedle M³odych';
EXEC DodajTrasê 'Centrum', 'Nowe Miasto';
EXEC DodajTrasê 'Plac Wolnoœci', 'Ulica Kwiatowa';
EXEC DodajTrasê 'Stare Miasto', 'Centrum';
EXEC DodajTrasê 'Osiedle M³odych', 'Plac Niepodleg³oœci';
EXEC DodajTrasê 'Dworzec G³ówny', 'Ulica Ogrodowa';
EXEC DodajTrasê 'Plac Niepodleg³oœci', 'Centrum';

-- Dodawanie Linii Autobusowych i £¹czenie z Trasami
EXEC DodajLinie 100, 1;
EXEC DodajLinie 101, 2;
EXEC DodajLinie 102, 3;
EXEC DodajLinie 103, 4;
EXEC DodajLinie 104, 5;
EXEC DodajLinie 105, 6;
EXEC DodajLinie 106, 7;
EXEC DodajLinie 107, 8;
EXEC DodajLinie 108, 9;
EXEC DodajLinie 109, 10;

-- Wprowadzanie Kursów
EXEC DodajKurs '08:30', 'Weekend', 'Centrum';
EXEC DodajKurs '09:00', 'Weekend', 'Dworzec G³ówny';
EXEC DodajKurs '09:30', 'Weekend', 'Park Kultury';
EXEC DodajKurs '10:00', 'Weekend', 'Ulica Ogrodowa';
EXEC DodajKurs '10:30', 'Weekend', 'Plac Wolnoœci';
EXEC DodajKurs '11:00', 'Weekend', 'Nowe Miasto';
EXEC DodajKurs '11:30', 'Weekend', 'Stare Miasto';
EXEC DodajKurs '12:00', 'Weekend', 'Ulica Kwiatowa';
EXEC DodajKurs '12:30', 'Weekend', 'Osiedle M³odych';
EXEC DodajKurs '13:00', 'Weekend', 'Plac Niepodleg³oœci';

-- Dodawanie OpóŸnieñ
EXEC DodajOpóŸnienie '00:05:00', 1;
EXEC DodajOpóŸnienie '00:03:00', 2;
EXEC DodajOpóŸnienie '00:04:00', 3;
EXEC DodajOpóŸnienie '00:02:00', 4;
EXEC DodajOpóŸnienie '00:06:00', 5;
EXEC DodajOpóŸnienie '00:01:30', 6;
EXEC DodajOpóŸnienie '00:03:30', 7;
EXEC DodajOpóŸnienie '00:05:30', 8;
EXEC DodajOpóŸnienie '00:04:30', 9;
EXEC DodajOpóŸnienie '00:02:30', 10;

-- £¹czenie Autobusów i Linii z Trasami
EXEC DodajAutobusDoTrasy 1, 1;
EXEC DodajAutobusDoTrasy 2, 2;
EXEC DodajAutobusDoTrasy 3, 3;
EXEC DodajAutobusDoTrasy 4, 4;
EXEC DodajAutobusDoTrasy 5, 5;
EXEC DodajAutobusDoTrasy 6, 6;
EXEC DodajAutobusDoTrasy 7, 7;
EXEC DodajAutobusDoTrasy 8, 8;
EXEC DodajAutobusDoTrasy 9, 9;
EXEC DodajAutobusDoTrasy 10, 10;

EXEC DodajLinieDoTrasy 1, 1;
EXEC DodajLinieDoTrasy 2, 2;
EXEC DodajLinieDoTrasy 3, 3;
EXEC DodajLinieDoTrasy 4, 4;
EXEC DodajLinieDoTrasy 5, 5;
EXEC DodajLinieDoTrasy 6, 6;
EXEC DodajLinieDoTrasy 7, 7;
EXEC DodajLinieDoTrasy 8, 8;
EXEC DodajLinieDoTrasy 9, 9;
EXEC DodajLinieDoTrasy 10, 10;

