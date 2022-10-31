--Creating and using database

CREATE DATABASE stri_populating_carts
USE stri_populating_carts
GO

--Creating Tables

CREATE TABLE tblCUSTOMER (
    CustomerID INT identity(1,1) primary key,
    Fname varchar(30),
    Lname varchar(30),
    BirthDate date
)
GO

CREATE TABLE tblPRODUCT_TYPE (
    ProductTypeID INT identity(1,1) primary key,
    ProductTypeName varchar(50),
    ProductTypeDescr varchar(255)
)
GO

CREATE TABLE tblPRODUCT (
    ProductID INT identity(1,1) primary key,
    ProductName varchar(50),
    ProductTypeID int FOREIGN KEY REFERENCES tblPRODUCT_TYPE(ProductTypeID) not null,
    Price numeric(6,2),
    ProductDescr varchar(255)
)
GO

CREATE TABLE tblORDER (
    OrderID INT identity(1,1) primary key,
    OrderDate date not null,
    CustomerID int FOREIGN KEY REFERENCES tblCUSTOMER(CustomerID) not null
)
GO

CREATE TABLE tblORDER_PRODUCT (
    OrderProdID INT identity(1,1) primary key,
    OrderID int FOREIGN KEY REFERENCES tblORDER(OrderID) not null,
    ProductID int FOREIGN KEY REFERENCES tblPRODUCT(ProductID) not null,
    Quantity int not null
)
GO

CREATE TABLE tblCART (
    CartID INT identity(1,1) primary key,
    CustomerID int FOREIGN KEY REFERENCES tblCUSTOMER(CustomerID) not null,
    ProductID int FOREIGN KEY REFERENCES tblPRODUCT(ProductID) not null,
    Quantity int not null,
    CartDate date not null
)
GO

--Inserting into the tables

INSERT INTO tblCUSTOMER (Fname, Lname, BirthDate)
SELECT Top 100 CustomerFname, CustomerLname, DateOfBirth
FROM PEEPS.dbo.tblCUSTOMER
GO

INSERT INTO tblPRODUCT_TYPE (ProductTypeName)
VALUES ('Dairy'),('Bread'), ('Frozen')

INSERT INTO tblPRODUCT (ProductName, ProductTypeID, Price)
VALUES ('Milk',(Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Dairy'), 6.99),
('Butter', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Dairy'), 5.85),
('Frozen Veggies', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Frozen'), 11.99),
('Cream', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Dairy'), 7.99),
('Buns', (Select ProductTypeID From tblPRODUCT_TYPE Where ProductTypeName = 'Bread'), 8.85)
GO

--Stored Procedures for getting customer and product IDs

CREATE PROCEDURE GetCustomerID
@F VARCHAR(30),
@L VARCHAR(30),
@DOB Date,
@C_ID INT OUTPUT
AS
SET @C_ID = (Select CustomerID From tblCUSTOMER Where Fname = @F And Lname = @L And BirthDate = @DOB)
GO

CREATE PROCEDURE GetProductID
@P VARCHAR(50),
@P_ID INT OUTPUT
AS
SET @P_ID = (Select ProductID From tblPRODUCT Where ProductName = @P)
GO

--Stored Procedure to insert into tblCART

CREATE PROCEDURE InsertCart
@FN VARCHAR(50),
@LN VARCHAR(50),
@Birth date,
@Prod VARCHAR(100),
@Quan INT,
@Date date

AS
DECLARE @Cust_ID INT, @Prod_ID INT

EXEC GetCustomerID
@F = @FN,
@L = @LN,
@DOB = @Birth,
@C_ID = @Cust_ID OUTPUT

If @Cust_ID is null
    BEGIN
        Print '@Cust_ID is empty, check spelling';
        Throw 54378, '@Cust_ID cannot be null', 1;
    END

EXEC GetProductID
@P = @Prod,
@P_ID = @Prod_ID OUTPUT

If @Prod_ID is null
    BEGIN
        Print '@Prod_ID is empty, check spelling';
        Throw 54378, '@Prod_ID cannot be null', 1;
    END

BEGIN TRANSACTION T1
    INSERT INTO tblCART(CustomerID, ProductID, Quantity, CartDate)
    VALUES (@Cust_ID, @Prod_ID, @Quan, @Date)

    If @@ERROR <> 0
        BEGIN
            Print '@@Error <> 0; check process'
            ROLLBACK TRANSACTION T1
        END
    ELSE
        COMMIT TRANSACTION T1
GO

--Synthetic Transaction to insert values into tblCART

CREATE PROCEDURE WRAPPER_InsertCart
@Run INT
AS

DECLARE @C_Fname varchar(30), @C_Lname varchar(30), @C_DOB date, @ProdName varchar(50), @Quant INT, @CartDate date 
DECLARE @CustPK INT, @ProdPK INT 
DECLARE @C_Count INT = (SELECT COUNT(*) FROM tblCUSTOMER)
DECLARE @P_Count INT = (SELECT COUNT(*) FROM tblPRODUCT)

WHILE @Run > 0
BEGIN
    SET @CustPK = (SELECT RAND() * @C_Count + 1)
    SET @ProdPK = (SELECT RAND() * @P_Count + 1)

    SET @C_Fname = (SELECT Fname FROM tblCUSTOMER WHERE CustomerID = @CustPK)
    SET @C_Lname = (SELECT Lname FROM tblCUSTOMER WHERE CustomerID = @CustPK)
    SET @C_DOB = (SELECT BirthDate FROM tblCUSTOMER WHERE CustomerID = @CustPK)
    SET @ProdName = (SELECT ProductName FROM tblPRODUCT WHERE ProductID = @ProdPK)
    SET @Quant = (SELECT Rand() * 10 + 1)
    SET @CartDate = (SELECT GetDate() - (SELECT Rand() * 100))

    EXEC InsertCart
    @FN = @C_Fname,
    @LN = @C_Lname,
    @Birth = @C_DOB,
    @Prod = @ProdName,
    @Quan = @Quant,
    @Date = @CartDate

    SET @Run = @Run - 1
END
GO

-- Execute WRAPPER_InsertCart to get 100 rows into tblCART
EXEC WRAPPER_InsertCart 100
GO 

--Stored Procedure to insert into tblORDER and tblORDER_PRODUCT, and complete the checkout process
CREATE PROCEDURE Insert_Order_OrderProduct
@Cu_FName VARCHAR(50),
@Cu_LName VARCHAR(50),
@Cu_DOB date
AS 

DECLARE @Cu_ID INT, @Order_Date Date, @O_ID INT

EXEC GetCustomerID
@F = @Cu_FName,
@L = @Cu_LName,
@DOB = @Cu_DOB,
@C_ID = @Cu_ID OUTPUT

If @Cu_ID is null
BEGIN
    Print '@Cust_ID is empty, check spelling';
    Throw 54378, '@Cust_ID cannot be null',1;
END

SET @Order_Date = GetDate()

BEGIN TRANSACTION T1
    BEGIN TRANSACTION T2
        INSERT INTO tblORDER(OrderDate, CustomerID)
        VALUES (@Order_Date, @Cu_ID)
        SET @O_ID = (SELECT SCOPE_IDENTITY())

        INSERT INTO tblORDER_PRODUCT(OrderID, ProductID, Quantity)
        SELECT @O_ID, ProductID, SUM(Quantity)
        FROM tblCART
        WHERE CustomerID = @Cu_ID
        GROUP BY ProductID
        IF @@ERROR <> 0
            BEGIN
                PRINT 'Insertion has failed. Transaction rolling back.'
                ROLLBACK TRANSACTION T2
            END
        ELSE
            COMMIT TRANSACTION T2

    BEGIN TRANSACTION T3
        DELETE FROM tblCART WHERE CustomerID = @Cu_ID
    COMMIT TRANSACTION T3

    IF @@TRANCOUNT <> 1 OR @@ERROR <> 0
        BEGIN
            PRINT 'The transaction or error count is above expected. Transaction rolling back.'
            ROLLBACK TRANSACTION T1
        END
    ELSE
        COMMIT TRANSACTION T1
    GO

--Testing the Stored Procedure
EXEC Insert_Order_OrderProduct
@Cu_FName = 'Felicita',
@Cu_LName = 'Collins',
@Cu_DOB = '1980-10-14'

Select * From tblORDER -- The order has been processed for the CustomerID belonging to Felicita.
Select * From tblCART Where CustomerID = 55 -- The cart for Felicita has been successfully deleted.
Select * From tblORDER_PRODUCT -- The Order_Product table has been successfully updated.


