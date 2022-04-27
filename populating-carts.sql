--Creating and using database

--CREATE DATABASE stri_populating_carts
USE stri_populating_carts

--Creating Tables

CREATE TABLE tblCUSTOMER
(CustomerID INT identity(1,1) primary key,
Fname varchar(50),
Lname varchar(50),
BirthDate date)

CREATE TABLE tblORDER
(OrderID INT identity(1,1) primary key,
OrderDate date not null,
CustomerID int FOREIGN KEY REFERENCES tblCUSTOMER(CustomerID) not null)

CREATE TABLE tblPRODUCT_TYPE
(ProductTypeID INT identity(1,1) primary key,
ProductTypeName varchar(60),
ProductTypeDescr varchar(225))

CREATE TABLE tblPRODUCT
(ProductID INT identity(1,1) primary key,
ProductName varchar(100),
ProductTypeID int FOREIGN KEY REFERENCES tblPRODUCT_TYPE(ProductTypeID) not null,
Price numeric(8,2),
ProductDescr varchar(225))

CREATE TABLE tblORDER_PRODUCT
(OrderProdID INT identity(1,1) primary key,
OrderID int FOREIGN KEY REFERENCES tblORDER(OrderID) not null,
ProductID int FOREIGN KEY REFERENCES tblPRODUCT(ProductID) not null,
Quantity int)

CREATE TABLE tblCART
(CartID INT identity(1,1) primary key,
CustomerID int FOREIGN KEY REFERENCES tblCUSTOMER(CustomerID) not null,
ProductID int FOREIGN KEY REFERENCES tblPRODUCT(ProductID) not null,
Quantity int not null,
CartDate date not null)
GO

--Procedures for getting customer and product IDs

CREATE PROCEDURE stri_GetCustomerID
@F VARCHAR(50),
@L VARCHAR(50),
@DOB Date,
@C_ID INT OUTPUT
AS
SET @C_ID = (Select CustomerID From tblCUSTOMER Where Fname = @F And Lname = @L And BirthDate = @DOB)
GO

CREATE PROCEDURE stri_GetProductID
@P VARCHAR(100),
@P_ID INT OUTPUT
AS
SET @P_ID = (Select ProductID From tblPRODUCT Where ProductName = @P)
GO

--Inserting into the tables

INSERT INTO tblCUSTOMER (Fname, Lname, BirthDate)
SELECT Top 100 CustomerFname, CustomerLname, DateOfBirth
FROM PEEPS.dbo.tblCUSTOMER
WHERE YEAR(DateOfBirth) > 1985

INSERT INTO tblPRODUCT_TYPE (ProductTypeName)
VALUES ('Dairy'),('Bread'), ('Frozen')

INSERT INTO tblPRODUCT (ProductName, ProductTypeID, Price)
VALUES ('Milk',(Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Dairy'), 6.99),
('Butter', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Dairy'), 5.85),
('Frozen Veggies', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Frozen'), 11.99),
('Cream', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Dairy'), 7.99),
('Buns', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Bread'), 8.85)
GO

--Procedure to insert into tblCART

CREATE PROCEDURE stri_InsertCart
@FN VARCHAR(50),
@LN VARCHAR(50),
@Birth date,
@Prod VARCHAR(100),
@Quan INT,
@Date date

AS
DECLARE @Cust_ID INT, @Prod_ID INT

EXEC stri_GetCustomerID
@F = @FN,
@L = @LN,
@DOB = @Birth,
@C_ID = @Cust_ID OUTPUT

If @Cust_ID is null
    BEGIN
        Print '@Cust_ID is empty, check spelling';
        Throw 54378, '@Cust_ID cannot be null',1;
    END

EXEC stri_GetProductID
@P = @Prod,
@P_ID = @Prod_ID OUTPUT

If @Prod_ID is null
    BEGIN
        Print '@Prod_ID is empty, check spelling';
        Throw 54378, '@Prod_ID cannot be null',1;
    END

BEGIN TRANSACTION T1
INSERT INTO tblCART(CustomerID, ProductID, Quantity, CartDate)
VALUES (@Cust_ID, @Prod_ID, @Quan, @Date)

If @@TRANCOUNT <> 1
    BEGIN
        Print '@@Trancount <> 1; check process'
        ROLLBACK TRANSACTION T1
    END
ELSE
    COMMIT TRANSACTION T1

EXEC stri_InsertCart
@FN = 'Mikki',
@LN = 'Vallero',
@Birth = '1986-01-15',
@Prod = 'Buns',
@Quan = '3',
@Date = '04-22-2022'
GO

--Procedure to Checkout
CREATE PROCEDURE stri_Checkout
@FName VARCHAR(50),
@LName VARCHAR(50),
@BirthDay date,
@CheckoutDate date
AS 
DECLARE @Cu_ID INT

EXEC stri_GetCustomerID
@F = @FName,
@L = @LName,
@DOB = @BirthDay,
@C_ID = @Cu_ID OUTPUT

If @Cu_ID is null
BEGIN
    Print '@Cust_ID is empty, check spelling';
    Throw 54378, '@Cust_ID cannot be null',1;
END

BEGIN TRANSACTION T1
INSERT INTO tblORDER_PRODUCT(OrderID, ProductID)
SELECT ProductID
FROM tblCART
WHERE CustomerID = @Cu_ID
    BEGIN TRANSACTION T2
DELETE FROM tblCART
WHERE CustomerID = @Cu_ID
    COMMIT TRANSACTION T2
IF @@TRANCOUNT <> 1
    BEGIN
        ROLLBACK TRANSACTION T1
    END
ELSE

    COMMIT TRANSACTION T1

/*INSERT INTO tblORDER (OrderDate, CustomerID)
VALUES (@CheckoutDate, @Cu_ID)*/