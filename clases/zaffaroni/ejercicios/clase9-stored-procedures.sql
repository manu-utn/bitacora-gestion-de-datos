/*
* DUDAS:
* 1. El Ejercicio (C) la resolucion no le faltaria el RIGHT JOIN en items?
* -> Chequear el RIGHT JOIN que agregaste
*
* # NOTAS
* 1. El WHERE siempre dsp de los JOIN!!
*    (lo rectifico por la costumbre de agregar FROM seguido de WHERE)
 */

/********************
 ** Ejercicio (A)
 */

-- Parte (1)

IF OBJECT_ID('CustomerStatistics') IS NOT NULL
	DROP TABLE CustomerStatistics;

CREATE TABLE CustomerStatistics(
	customer_num INT PRIMARY KEY,
	ordersQty INT,
	maxDate DATE,
	productsQty INT
);

-- PARTE (2)
IF OBJECT_ID('CustomerStatisticsUpdate') IS NOT NULL
	DROP PROCEDURE CustomerStatisticsUpdate;

GO
CREATE PROCEDURE CustomerStatisticsUpdate @fecha_DES DATE AS
DECLARE CURSOR_ITEM CURSOR FOR
	SELECT customer_num FROM customer
	DECLARE @ordersqty INT,  @ordersqty_nuevas INT
	DECLARE @maxDate DATE, @productsQty INT
	DECLARE @customer_num INT
OPEN CURSOR_ITEM
FETCH CURSOR_ITEM INTO @customer_num
WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @ordersqty=count(*), @maxDate=MAX(order_date)
		--> esto no se puede...
		--> @productsQty=(SELECT count(DISTINCT stock_num) FROM items WHERE order_num=o.order_num)
		FROM orders o WHERE customer_num=@customer_num

	SELECT @ordersqty_nuevas=count(*) FROM orders
		WHERE customer_num=@customer_num AND order_date >= @fecha_DES

	/*
	--> 1. Esto no se puede.. Porque la subquery te devuelve un conjunto de registros
  -->    y una variable puede contener un valor escalar, el de una columna unicamente
  --> 2. Se podría si.. usás una "función de agregación" (Ej. sum,count,avg,...)
  -->    ó también si limitás el número de registros a uno solo con TOP 1
	SET @productsQty=(
		SELECT DISTINCT stock_num, manu_code
		FROM orders o
		JOIN items i ON i.order_num=o.order_num
		WHERE customer_num=@customer_num
	)
	*/

	SELECT @productsQty=count(*)
	FROM (
		SELECT DISTINCT stock_num, manu_code
		FROM orders o
		JOIN items i ON i.order_num=o.order_num
		WHERE customer_num=@customer_num
	) as t

	IF NOT EXISTS(SELECT 1 FROM CustomerStatistics WHERE customer_num=@customer_num)
		INSERT INTO CustomerStatistics (customer_num, ordersQty, maxDate, productsQty)
		VALUES (@customer_num, @ordersqty+@ordersqty_nuevas, @maxDate, @productsQty)
	ELSE
		UPDATE CustomerStatistics
		SET ordersQty=@ordersqty+@ordersqty_nuevas, maxDate=@maxDate, productsQty=@productsQty
		WHERE customer_num=@customer_num
	FETCH CURSOR_ITEM INTO @customer_num
END
CLOSE CURSOR_ITEM
DEALLOCATE CURSOR_ITEM
GO

/********************
** Ejercicio (B)
*/

-- Parte (1)
IF OBJECT_ID('informeStock') IS NOT NULL
	DROP TABLE informeStock;

CREATE TABLE informeStock(
	fechaInforme DATE,
	stock_num INT,
	manu_code CHAR(3),
	cantOrdenes INT,
	UltCompra DATE,
	cantClientes INT,
	totalVentas DECIMAL,
	PRIMARY KEY (fechaInforme, stock_num, manu_code)
);

-- Parte (2)
IF OBJECT_ID('generarInformeGerencial') IS NOT NULL
	DROP PROCEDURE generarInformeGerencial;

-- Alternativa #1 SIN CURSOR+THROW (para lanzar una excepción)
GO
CREATE PROCEDURE generarInformeGerencial @fechaInforme DATE AS
BEGIN
	IF EXISTS(SELECT 1 FROM informeStock WHERE fechaInforme=@fechaInforme)
		THROW 50000, 'Este informe ya existe en la base de datos', 1
	ELSE
		INSERT INTO informeStock (fechaInforme, stock_num, manu_code, cantOrdenes, UltCompra, cantClientes, totalVentas)
		SELECT @fechaInforme, p.stock_num, p.manu_code,
           COUNT(DISTINCT o.order_num), MAX(order_date),
           COUNT(DISTINCT customer_num), SUM(i.unit_price*i.quantity)
		FROM products p
		LEFT JOIN items i ON (i.stock_num = p.stock_num AND i.manu_code = p.manu_code)
		JOIN orders o ON o.order_num=i.order_num
		GROUP BY p.stock_num, p.manu_code
END
GO

--------------------------------------------------------------------------------------------

SELECT p.stock_num, p.manu_code, COUNT(DISTINCT o.order_num),
       MAX(order_date), COUNT(DISTINCT customer_num), SUM(i.unit_price*i.quantity)
FROM products p
--> Usamos "LEFT JOIN" porque
--> 1. Pueden haber productos que no hayan sido vendidos (no estén asociados a un item que a su vez estè en una orden de compra)
--> entonces.. se mostrarán productos que hayan sido o no vendidos (la relación con item y order puede no existir y tener NULL)
LEFT JOIN items i ON (i.stock_num = p.stock_num AND i.manu_code = p.manu_code)
JOIN orders o ON o.order_num=i.order_num
GROUP BY p.stock_num, p.manu_code

SELECT p.stock_num, p.manu_code, COUNT(DISTINCT o.order_num), MAX(order_date),
       COUNT(DISTINCT customer_num), SUM(i.unit_price*i.quantity)
FROM products p
JOIN items i ON (i.stock_num = p.stock_num AND i.manu_code = p.manu_code)
JOIN orders o ON o.order_num=i.order_num
GROUP BY p.stock_num, p.manu_code

--------------------------------------------------------------------------------------------

-- Alternativa #2 con Cursor + RAISERROR
--> raiserror: lanza excepciones en forma de mensaje, el raiserror no es eficiente para capturar como excepción
IF OBJECT_ID('generarInformeGerencial') IS NOT NULL
	DROP PROCEDURE generarInformeGerencial;

GO
CREATE PROCEDURE generarInformeGerencial @fechaInforme DATE AS
DECLARE ITEM_CURSOR CURSOR FOR
	SELECT stock_num, manu_code FROM products
	DECLARE @stock_num INT, @manu_code VARCHAR(3)
	DECLARE @cantOrdenes INT, @UltCompra DATE, @cantClientes INT, @totalVentas INT
OPEN ITEM_CURSOR
FETCH ITEM_CURSOR INTO @stock_num, @manu_code
WHILE @@FETCH_STATUS = 0
BEGIN
	IF NOT EXISTS(SELECT 1 FROM informeStock WHERE fechaInforme=@fechaInforme)
		INSERT INTO informeStock (fechaInforme, stock_num, manu_code, cantOrdenes, UltCompra, cantClientes, totalVentas)
		SELECT @fechaInforme, @stock_num, @manu_code, t.cantOrdenes, t.UltCompra, t.cantClientes, t.totalVentas
		FROM (
				SELECT count(o.order_num) cantOrdenes,
				MAX(order_date) UltCompra,
				count(DISTINCT customer_num) cantClientes,
				SUM(unit_price*quantity) totalVentas
				FROM orders o
				JOIN items i ON i.order_num = o.order_num AND i.stock_num=@stock_num
					AND i.manu_code=@manu_code
			) t
	ELSE
		DECLARE @errorDescripcion VARCHAR(100)
		SET @errorDescripcion='Ups..! Este informe ya existe en la tabla..'
		RAISERROR(@errorDescripcion, 14,1)
	FETCH ITEM_CURSOR INTO @stock_num, @manu_code
END
CLOSE ITEM_CURSOR
DEALLOCATE ITEM_CURSOR
GO


/********************
** Ejercicio (C)
*/
IF OBJECT_ID('informeVentas') IS NOT NULL
	DROP TABLE informeVentas;

CREATE TABLE informeVentas(
	fechaInforme DATE,
	codEstado CHAR(2),
	customer_num INT,
	cantOrdenes INT,
	primerVenta DATE,
	UltVenta DATE,
	cantProductos INT,
	totalVentas DECIMAL
);

IF OBJECT_ID('generarInformeVentas') IS NOT NULL
	DROP PROCEDURE generarInformeVentas;

GO
CREATE PROCEDURE generarInformeVentas
@fechaInforme DATE, @codEstado CHAR(2) AS
BEGIN
	IF EXISTS(SELECT 1 FROM informeVentas WHERE fechaInforme=@fechaInforme AND codEstado=@codEstado)
		THROW 50000, 'Este informe ya existe en la base de datos', 1
	ELSE
		INSERT INTO informeVentas (fechaInforme, codEstado, customer_num, cantOrdenes, primerVenta, UltVenta, cantProductos, totalVentas)
		SELECT @fechaInforme, @codEstado, c.customer_num, count(DISTINCT o.order_num), MIN(o.order_date), MAX(o.order_date), count(DISTINCT i.stock_num), SUM(i.unit_price*i.quantity)
		FROM customer c --> obtener todos los clientes
		JOIN orders o ON o.customer_num=c.customer_num --> que hayan comprado algo (están asociados a una orden de compra)
		RIGHT JOIN items i ON i.order_num=o.order_num  --> el orden debe tener asociado un producto-item
		WHERE c.state = @codEstado
		GROUP BY c.customer_num
END
GO

DECLARE @FECHA_HOY DATE;
SET @FECHA_HOY = GETDATE();
-- si intentamos ejecutar el sp dos veces, lanzará una excepción
EXECUTE generarInformeVentas @FECHA_HOY, 'CA'

SELECT * FROM customer
SELECT * FROM informeVentas;
