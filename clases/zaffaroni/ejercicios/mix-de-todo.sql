/*
* Practica 06
*/

--> Ejercicio (1)
SELECT m.manu_code, manu_name, lead_time, SUM(quantity*unit_price) monto_total
FROM manufact m --> tabla dominante
LEFT JOIN items i ON i.manu_code = m.manu_code
GROUP BY m.manu_code, manu_name, lead_time
ORDER BY manu_name

--> Ejercicio (2)
SELECT DISTINCT p.stock_num, description, p.manu_code, p2.manu_code
FROM products p
JOIN product_types pt ON pt.stock_num = p.stock_num
LEFT JOIN products p2 ON p2.stock_num = p.stock_num AND p2.manu_code != p.manu_code
GROUP BY p.stock_num, description, p.manu_code, p2.manu_code
ORDER BY p.stock_num

--> Ejercicio (3)
-- Parte (A) - Alternativa #1
SELECT c.customer_num, fname, lname
FROM customer c
WHERE 
	(SELECT COUNT(DISTINCT order_num) 
	FROM orders 
	WHERE customer_num = c.customer_num)
	> 1

--> Ejercicio (3)
-- Parte (A) - Alternativa #2
SELECT c.customer_num, fname, lname
FROM customer c
WHERE EXISTS(
	SELECT 1
	FROM orders WHERE customer_num = c.customer_num
	HAVING COUNT(DISTINCT order_num) > 1
)

--> Ejercicio (3)
-- Parte (A) - Alternativa #3
SELECT c.customer_num, fname, lname
FROM customer c
WHERE customer_num IN (
	SELECT customer_num
	FROM orders GROUP BY customer_num
	HAVING COUNT(DISTINCT order_num) > 1
)

--> Ejercicio (3)
-- Parte (A) - Alternativa #4
SELECT c.customer_num, fname, lname
FROM customer c
JOIN (
	SELECT customer_num
	FROM orders 
	GROUP BY customer_num HAVING COUNT(DISTINCT order_num) > 1
) t ON t.customer_num = c.customer_num

--> Ejercicio (3) - Parte (B)
SELECT c.customer_num, fname, lname
FROM customer c
JOIN orders o ON o.customer_num = c.customer_num
GROUP BY c.customer_num , fname, lname
HAVING COUNT(DISTINCT order_num) > 1

--> Ejercicio (4)
SELECT o.order_num, SUM(quantity*unit_price) monto_total
FROM orders o
JOIN items	i ON i.order_num = o.order_num
GROUP BY o.order_num
HAVING SUM(quantity*unit_price) < (
		SELECT AVG(quantity*unit_price) FROM items)

--> Ejercicio (5)
-- Alternativa # 1
SELECT m.manu_code, manu_name, p.stock_num, description, unit_price
FROM manufact m
JOIN products p			ON p.manu_code	= m.manu_code
JOIN product_types pt	ON pt.stock_num = p.stock_num
WHERE unit_price > (
	SELECT AVG(unit_price) FROM products
	WHERE manu_code = m.manu_code
)

--> Ejercicio (5)
-- Alternativa # 2
SELECT m.manu_code, manu_name, p.stock_num, description, unit_price
FROM manufact m
JOIN products p			ON p.manu_code	= m.manu_code
JOIN product_types pt	ON pt.stock_num = p.stock_num
WHERE EXISTS(
	SELECT 1 FROM products
	WHERE manu_code = m.manu_code
	HAVING p.unit_price > AVG(unit_price)
)

--> Ejercicio (6)
SELECT o.customer_num, company, order_num, order_date
FROM orders o
JOIN customer c ON c.customer_num = o.customer_num
WHERE NOT EXISTS(
	SELECT 1
	FROM orders o2 
	JOIN items i2 ON i2.order_num = o2.order_num
	JOIN product_types pt ON pt.stock_num = i2.stock_num
	WHERE description LIKE '%baseball gloves%'
	AND o2.order_num = o.order_num --> fundamental..!
)
ORDER BY company ASC, order_num DESC

--> Ejercicio (7)
SELECT customer_num, fname, lname
FROM customer 
WHERE customer_num NOT IN(
	SELECT customer_num
	FROM orders o
	JOIN items i ON i.order_num = o.order_num
	WHERE manu_code = 'HSK'
)

--> Ejercicio (8): pendiente


--> Ejercicio (9)
-- SELECT * FROM products WHERE manu_code = 'HRO' OR stock_num = 1
SELECT * FROM products
	WHERE manu_code = 'HRO'
UNION
SELECT * FROM products
	WHERE stock_num = 1

--> Ejercicio (10)
SELECT 1 'clave ordenamiento', city, company 
	FROM customer c
	WHERE city = 'Redwood City'
UNION
SELECT 2  'clave ordenamiento', city, company 
	FROM customer c
	WHERE city != 'Redwood City'
ORDER BY 1

--> Ejercicio (11)
--> tuvo algo de dificultad pensarlo..
SELECT t.stock_num tipo_producto, t.cantidad
	FROM (
		SELECT TOP 2 stock_num, sum(quantity) cantidad --> Si no usás TOP, lanza excepción
		FROM items 
		GROUP BY stock_num
		ORDER BY sum(quantity) DESC
	) t
UNION
SELECT t2.stock_num tipo_producto, t2.cantidad
	FROM (
		SELECT TOP 2 stock_num, sum(quantity) cantidad --> Si no usás TOP, lanza excepción
		FROM items 
		GROUP BY stock_num
		ORDER BY sum(quantity) ASC
	) t2
ORDER BY 2 DESC

--> Ejercicio (12)
-- No confundirse con los SP/Triggers/Funciones que necesitan BEGIN+END
GO
CREATE VIEW ClientesConMultiplesOrdenesx2 AS
	SELECT c.customer_num, fname, lname
	FROM customer c
	JOIN orders o ON o.customer_num = c.customer_num
	GROUP BY c.customer_num , fname, lname
	HAVING COUNT(DISTINCT order_num) > 1
GO

--> Ejercicio (13)
-- Al usar "WITH CHECK OPTION" las operaciones DML 
-- deben cumplir con las condiciones del WHERE
GO
CREATE VIEW Productos_HROx2 AS
	SELECT * FROM products
	WHERE manu_code ='HRO'
	WITH CHECK OPTION  --> operaciones DML deben cumplir el WHERE
GO

--> Ejercicio (14)
BEGIN TRANSACTION
	INSERT INTO customer2 (customer_num, fname, lname) VALUES (500, 'Fred', 'Flint')
	SELECT * FROM customer2 WHERE fname='Fred'
ROLLBACK TRANSACTION
SELECT * FROM customer2 WHERE fname='Fred'

--> Ejercicio (15)
-- Insertamos multiples registros
BEGIN TRANSACTION
	INSERT	manufact2	(manu_code, manu_name, lead_time) 
			VALUES		('AZZ', 'AZZIO SA', 5)

	-- No equivocarse poniendo paréntesis en el SELECT ..
	INSERT products2 (stock_num, manu_code, unit_price)
		SELECT p.stock_num, 'AZZ', unit_price
		FROM products2  p
		JOIN product_types pt ON pt.stock_num=p.stock_num
		WHERE manu_code='AZZ' AND description LIKE '%tennis%'

	COMMIT

----------------------------------------------------------------------

/*
* Practica 07 - Triggers
*/

--> Ejercicio (1)
CREATE TABLE Products_historia_precios2(
	Stock_historia_Id INT IDENTITY PRIMARY KEY,
	Stock_num INT,
	Manu_code CHAR(3),
	fechaHora DATETIME,
	usuario VARCHAR DEFAULT CURRENT_USER,
	unit_price_old DECIMAL,
	unit_price_new DECIMAL,
	estado CHAR default 'A' CHECK (estado IN ('A','I'))
);

INSERT INTO Products_historia_precios2 (Stock_num, Manu_code)
			 VALUES (100,'ASD')

--> Ejercicio (2)
--
-- OJO...! Porque puede haber multiples DELETE, por eso es necesario
-- usar un CURSOR
GO
CREATE TRIGGER prod_hist_prod_audit ON Products_historia_precios2
INSTEAD OF DELETE AS
BEGIN
	DECLARE @Stock_historia_Id INT
	DECLARE ITEM_CURSOR CURSOR
	FOR SELECT Stock_historia_Id FROM deleted
	OPEN ITEM_CURSOR
	FETCH ITEM_CURSOR INTO @Stock_historia_Id
	WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE Products_historia_precios2
			SET estado = 'I'
			WHERE Stock_historia_Id = @Stock_historia_Id

		FETCH ITEM_CURSOR INTO @Stock_historia_Id
	END
	CLOSE ITEM_CURSOR
	DEALLOCATE ITEM_CURSOR
	/*
	--> esto sólo servíria si borraran un registro
	UPDATE Products_historia_precios2
	SET estado = 'I'
	WHERE Stock_historia_Id IN ( SELECT Stock_historia_Id FROM deleted )
	*/
END
GO

--> Ejercicio (3)
--
-- En este NO es necesario un cursor, 
GO
CREATE TRIGGER products_audit_insert ON products2
INSTEAD OF INSERT AS
BEGIN
	IF (DATEPART(HOUR, GETDATE()) BETWEEN 8 AND 20)
		INSERT products2 
			SELECT * FROM inserted
	ELSE
		RAISERROR('Inserts permitidos de 8 a 20h', 16, 1)
END
GO

--> Ejercicio (4)
--
-- En este tampoco es necesario un CURSOR,
-- porque ya estamos verificando que se borre un solo registro
GO
CREATE TRIGGER orders_audit_delete ON orders2
INSTEAD OF DELETE AS
BEGIN
	DECLARE @order_num INT

	IF( (SELECT COUNT(*) FROM deleted) > 1)
		RAISERROR('No se puede borra más de una orden', 16, 1)
	ELSE
		BEGIN
			--SET @order_num = (SELECT order_num FROM deleted)
			SELECT @order_num = order_num FROM deleted;

			DELETE FROM orders2
				WHERE order_num = @order_num;

			DELETE FROM items2
				WHERE order_num = @order_num;
				--> El WHERE de abajo NO es eficiente, ya que hay
				-- que reutilizarlo en la query de arriba también
				--WHERE order_num = (SELECT order_num FROM deleted)
		END
END


/*
INSERT into orders2		--> inserta multiples registros
	SELECT * FROM orders	(pero no crea la tabla(

SELECT *				--> crea la tabla e inserta los datos
	INTO items2
	FROM items
*/
GO


--> Ejercicio (5)
