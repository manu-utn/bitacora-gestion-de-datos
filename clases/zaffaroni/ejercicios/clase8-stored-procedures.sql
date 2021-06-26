/*
* Pendiente: Hacer el (B) con cursores, y ver si los resultados son los mismos
*
* - Ejercicio (A)
* 1. Si tenes un cursor dentro de un SP, queda mas entendible si declaras las variables luego del SELECT del cursor
* 2. Cuando uses BETWEEN, guarda de no equivocar los rangos.. PORQUE HACE CUALQUIER COSA SI NO..!
*
* - Crear Funciones/Procedures
* 1. Los parametros que reciben,se coloca de la misma manera
* 2. Los procedures se ejecutan sin los (), esos son solo las funciones
* 3. Si retornan/modifican alguna variable, va luego de los parametros que reciban
* 4. Solo pueden retornar un valor, como cualquier funcion/procedimiento
*/

-- OJO..! Esta query solo hace multiples INSERT, pero NO CREA TABLAS...
--INSERT INTO #clientesCalifornia SELECT * FROM customer WHERE 1<0


-- Ejercicio (A)

IF OBJECT_ID('CustomerStatistics') IS NOT NULL
	DROP TABLE CustomerStatistics;

CREATE TABLE dbo.CustomerStatistics(
	customer_num INT PRIMARY KEY,
	maxdate DATETIME,
	ordersqty INT,
	uniqueProducts INT
);


IF OBJECT_ID('actualizaEstadisticas') IS NOT NULL
	DROP PROCEDURE actualizaEstadisticas;

GO
CREATE PROCEDURE actualizaEstadisticas @customer_numDES INT, @customer_numHAS INT AS
DECLARE ITEM_CURSOR CURSOR FOR
		SELECT customer_num FROM customer WHERE customer_num BETWEEN @customer_numDES AND @customer_numHAS
		DECLARE @customer_num INT, @ordersqty INT, @uniqueProducts INT, @maxdate DATETIME
OPEN ITEM_CURSOR
FETCH ITEM_CURSOR INTO @customer_num
--FETCH NEXT FROM ITEM_CURSOR INTO @customer_num
WHILE @@FETCH_STATUS = 0
BEGIN
	-- DUDA: Entonces esto no se podia..?
	SELECT @ordersqty=COUNT(*), @maxdate=MAX(order_date)
--	@uniqueProducts=(SELECT count(DISTINCT stock_num) FROM items i WHERE i.order_num=o.order_num)
		FROM orders o WHERE customer_num=@customer_num

	SELECT @uniqueProducts=count(DISTINCT stock_num)
		FROM items i, orders o
		WHERE i.order_num=o.order_num AND customer_num=@customer_num

	IF NOT EXISTS(SELECT 1 FROM CustomerStatistics WHERE customer_num=@customer_num)
		BEGIN
			PRINT 'INSERTANDO..';
			--INSERT INTO CustomerStatistics VALUES (@customer_num, @maxdate, @ordersqty, @uniqueProducts)
			INSERT INTO CustomerStatistics (customer_num, ordersqty, uniqueProducts)
			VALUES (@customer_num, @ordersqty, @uniqueProducts)
		END
	ELSE
		BEGIN
			PRINT 'ACTUALIZANDO'

			UPDATE dbo.CustomerStatistics
			SET ordersqty=@ordersqty, uniqueProducts=@uniqueProducts
			WHERE customer_num=@customer_num
		END
	FETCH ITEM_CURSOR INTO @customer_num
	--FETCH NEXT FROM ITEM_CURSOR INTO @customer_num
END
CLOSE ITEM_CURSOR
DEALLOCATE ITEM_CURSOR
GO

SELECT customer_num, count(DISTINCT stock_num)
FROM items i, orders o WHERE i.order_num=o.order_num
GROUP BY customer_num;

EXECUTE actualizaEstadisticas 101,110
SELECT * FROM CustomerStatistics
TRUNCATE TABLE CustomerStatistics;
/*
-- parte 1
-- esto era antes de saber como hacer el UPDATE..
INSERT INTO dbo.CustomerStatistics (customer_num, ordersqty, maxdate, uniqueProducts)
SELECT customer_num, MAX(customer_num),
	(SELECT count(DISTINCT stock_num) FROM items WHERE order_num=o.order_num)
FROM orders o
WHERE NOT EXISTS(SELECT 1 FROM CustomerStatistics WHERE customer_num=o.customer_num)
AND customer_num BETWEEN @customer_numHAS AND @customer_numDES
GROUP BY customer_num
*/

-- Ejercicio (B)
-- Creamos una tabla vacia, con la estructura de la tabla customer
IF OBJECT_ID('clientesCalifornia') IS NOT NULL
	DROP TABLE clientesCalifornia
IF OBJECT_ID('clientesNoCaAlta') IS NOT NULL
	DROP TABLE clientesNoCaAlta
IF OBJECT_ID('clientesNoCaBaja') IS NOT NULL
	DROP TABLE clientesNoCaBaja
IF OBJECT_ID('customer2') IS NOT NULL
	DROP TABLE customer2

SELECT * INTO clientesCalifornia FROM customer WHERE 1<0
SELECT * INTO clientesNoCaAlta FROM customer WHERE 1<0
SELECT * INTO clientesNoCaBaja FROM customer WHERE 1<0
SELECT * INTO customer2 FROM customer

IF OBJECT_ID('migraClientes') IS NOT NULL
	DROP PROCEDURE migraClientes

GO
CREATE PROCEDURE migraClientes
@customer_numDES INT, @customer_numHAS INT AS
BEGIN
BEGIN TRANSACTION
	BEGIN TRY
		/** PARTE (1) **/
		INSERT INTO clientesCalifornia
		SELECT * FROM customer
		WHERE state='CA' AND
		customer_num BETWEEN @customer_numDES AND @customer_numHAS

		INSERT INTO clientesNoCaAlta
		SELECT * FROM customer c
		WHERE EXISTS (
			SELECT SUM(unit_price) FROM orders o
			JOIN items i ON i.order_num=o.order_num
			WHERE customer_num=c.customer_num
			GROUP BY customer_num
			HAVING SUM(unit_price) > 999
		)
		AND customer_num BETWEEN @customer_numDES AND @customer_numHAS

		INSERT INTO clientesNoCaBaja
		SELECT * FROM customer c
		WHERE EXISTS (
			SELECT SUM(unit_price) FROM orders o
			JOIN items i ON i.order_num=o.order_num
			WHERE customer_num=c.customer_num
			GROUP BY customer_num
			HAVING SUM(unit_price) < 1000
		)
		AND customer_num BETWEEN @customer_numDES AND @customer_numHAS

		/** PARTE (2) **/
		UPDATE customer2 SET status='P'
		WHERE customer_num IN (
			SELECT customer_num FROM clientesCalifornia
			UNION
			SELECT customer_num FROM clientesNoCaAlta
			UNION
			SELECT customer_num FROM clientesNoCaBaja
		)
		AND customer_num BETWEEN @customer_numDES AND @customer_numHAS

	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		DECLARE @errorDescripcion VARCHAR(100)
		SET @errorDescripcion='Ups..! Ocurrió un error che.!'
		RAISERROR(@errorDescripcion, 14,1)
		ROLLBACK TRANSACTION
	END CATCH
END
GO

EXECUTE migraClientes 100,126

SELECT * FROM customer
SELECT * FROM customer2
SELECT * FROM clientesCalifornia
SELECT * FROM clientesNoCaAlta
SELECT * FROM clientesNoCaBaja

-- Ejercicio (C)
IF OBJECT_ID('listaPrecioMayor') IS NOT NULL
	DROP PROCEDURE listaPrecioMayor;
IF OBJECT_ID('listaPrecioMenor') IS NOT NULL
	DROP PROCEDURE listaPrecioMenor;
IF OBJECT_ID('products2') IS NOT NULL
	DROP TABLE products2;

SELECT * INTO listaPrecioMayor FROM products WHERE 1<0;
SELECT * INTO listaPrecioMenor FROM products WHERE 1<0;
SELECT * INTO products2 FROM products;

ALTER TABLE products2 ADD status CHAR -- agregamos la columna

IF OBJECT_ID('actualizaPrecios') IS NOT NULL
	DROP PROCEDURE actualizaPrecios;

GO
CREATE PROCEDURE actualizaPrecios
@manu_codeDES CHAR(3), @manu_codeHAS CHAR(3), @porActualizacion INT AS
DECLARE ITEM_CURSOR CURSOR FOR
	SELECT unit_price, stock_num, manu_code FROM products
		WHERE manu_code BETWEEN @manu_codeDES AND @manu_codeHAS
	DECLARE @unit_price INT, @unit_code INT, @stock_num INT, @manu_code INT
OPEN ITEM_CURSOR
FETCH ITEM_CURSOR INTO @unit_price, @unit_code, @stock_num, @manu_code
WHILE @@FETCH_STATUS =0
BEGIN
	BEGIN TRANSACTION -- diferencia entre haberlo colocado antes de while?
	BEGIN TRY
		IF((SELECT SUM(quantity) FROM items WHERE stock_num=@stock_num AND manu_code=@manu_code) >= 500)
			INSERT INTO listaPrecioMayor (stock_num, manu_code, unit_price, unit_code)
			VALUES (@stock_num, @manu_code, @unit_price*@porActualizacion*0.80, @unit_code)
		ELSE
			IF NOT EXISTS(SELECT 1 FROM listaPrecioMenor WHERE stock_num=@stock_num)
				INSERT INTO listaPrecioMenor (stock_num, manu_code, unit_price, unit_code)
				VALUES (@stock_num, @manu_code, @unit_price*@porActualizacion, @unit_code)
			ELSE
				UPDATE listaPrecioMenor
				SET unit_price = @unit_price*@porActualizacion

		UPDATE products2 SET status='A' WHERE stock_num=@stock_num AND manu_code=@manu_code

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		DECLARE @errorDescripcion VARCHAR(100)
		SET @errorDescripcion='Ups..! Ocurrió un error che.!'
		RAISERROR(@errorDescripcion, 14,1)
				
		ROLLBACK TRANSACTION
	END CATCH
	FETCH ITEM_CURSOR INTO @unit_price, @unit_code, @stock_num, @manu_code
END
CLOSE ITEM_CURSOR
DEALLOCATE ITEM_CURSOR
GO
