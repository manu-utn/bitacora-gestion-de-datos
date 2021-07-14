SELECT 
	description, c.lname, c.fname, SUM(i.quantity*i.unit_price),
	COALESCE(t2.lname, '--') lname, COALESCE(t2.fname, '--') fname, COALESCE(t2.total_comprado, 0) total_comprado
FROM product_types pt
JOIN items		i ON i.stock_num	= pt.stock_num
JOIN orders		o ON o.order_num	= i.order_num
JOIN customer	c ON c.customer_num = o.customer_num
LEFT JOIN (
	SELECT SUM(quantity*unit_price) total_comprado, o2.customer_num, c.fname, c.lname, stock_num
	FROM orders o2
	JOIN items		i2 ON i2.order_num		= o2.order_num
	JOIN customer	c  ON c.customer_num	= o2.customer_num
	GROUP BY o2.customer_num, c.fname, c.lname, stock_num
) t2 ON t2.customer_num = c.customer_num_referedBy AND t2.stock_num = i.stock_num
/*
LEFT JOIN customer	c2 ON c2.customer_num = c.customer_num_referedBy
JOIN (
	SELECT SUM(quantity*unit_price) total_comprado, o2.customer_num
	FROM orders o2
	JOIN items  i2 ON i2.order_num = o2.order_num
	GROUP BY o2.customer_num
) t1 ON t1.customer_num = c.customer_num
*/

-------------------------------------------------------------------------

SELECT * FROM Novedades
-- Parte (2)
GO
CREATE PROCEDURE actualizaPrecios2 @fecha DATETIME AS
BEGIN 
	DECLARE @FechaAlta DATETIME,
		@Manu_code VARCHAR, @Stock_num INT, @descTipoProduct VARCHAR,
		@Unit_price DECIMAL, @Unit_code DECIMAL 

	DECLARE ITEM_CURSOR CURSOR
	FOR SELECT FechaAlta, Manu_code, Stock_num, descTipoProduct, Unit_price FROM Novedades WHERE FechaAlta=@fecha

	OPEN ITEM_CURSOR
	FETCH ITEM_CURSOR INTO @FechaAlta, @Manu_code, @Stock_num, @descTipoProduct, @Unit_price, @Unit_code
	WHILE @@FETCH_STATUS = 0
	BEGIN
	BEGIN TRANSACTION
		BEGIN TRY
			IF NOT EXISTS(SELECT 1 FROM manufact WHERE manu_code = @Manu_code)
				RAISERROR('error', 16, 1);

			IF NOT EXISTS(SELECT 1 FROM product_types WHERE stock_num = @Stock_num)
				--IF EXISTS(SELECT 1 FROM manufact WHERE manu_code = @Manu_code)
					INSERT INTO product_types (stock_num, description)  VALUES (@Stock_num, @descTipoProduct)
			IF EXISTS (SELECT 1 FROM products WHERE stock_num = @Stock_num)
				UPDATE products 
				SET unit_price = @Unit_price
				WHERE stock_num = @Stock_num AND manu_code = @Manu_code
			ELSE
				INSERT INTO products (stock_num, manu_code, unit_price, unit_code)
							VALUES (@Stock_num, @Manu_code, @Unit_price, @Unit_code)
			
			COMMIT
		END TRY
		BEGIN CATCH
			ROLLBACK
		END CATCH
	FETCH ITEM_CURSOR INTO @FechaAlta, @Manu_code, @Stock_num, @descTipoProduct, @Unit_price, @Unit_price
	END
	CLOSE ITEM_CURSOR
	DEALLOCATE ITEM_CURSOR
	
END
GO
